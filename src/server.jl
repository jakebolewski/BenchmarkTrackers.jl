immutable BenchmarkServer
    node_configs
    listener::GitHub.EventListener
end

const COMMENT_EVENTS = [GitHub.CommitCommentEvent, GitHub.PullRequestReviewCommentEvent]

# Sets up a BenchmarkServer that will run benchmarks and report statuses
# any time the trigger phrase is used in a comment made by a contributor.
#
# Trigger phrase syntax:
#
#   trigger(tag1, tag2, tag3 | sha)
#
# For example: "%RunBenchmarks(parallel, indexing | 5cfcb1d2c12a15e4f6a6fccc702db3bd2b1d7af1)"
#
# If the sha is left out, a comparison commit is selected by default. If the
# event is a CommitCommentEvent, then the default comparison commit is the
# HEAD's parent. If the event is a PullRequestReviewCommentEvent, the default
# comparison commit is the HEAD of the base branch.

function BenchmarkServer(node_configs, logger::BenchmarkLogger,
                         auth::GitHub.OAuth2, secret::AbstractString,
                         owner::AbstractString, repo::AbstractString;
                         trigger::AbstractString="%RunBenchmarks",
                         status_url::AbstractString="")

    if isempty(node_configs)
        error("BenchmarkServer needs at least one child node to run benchmarks on")
    end

    listener = GitHub.EventListener(auth, secret, owner, repo;
                                    events=COMMENT_EVENTS) do event, auth
        payload = GitHub.payload(event)

        # Step 1: extract comment from payload
        if !(haskey(payload, "comment"))
            return HttpCommon.Response(400, "payload must contain comment")
        end

        comment = payload["comment"]

        # Step 2: check if comment is from collaborator
        if !(GitHub.iscollaborator(auth, owner, repo, comment["user"]["login"]))
            return HttpCommon.Response(200, "commenter is not collaborator; no benchmarks ran.")
        end

        # Step 3: check for trigger phrase
        body = get(comment, "body", "")

        if !(contains(body, trigger))
            return HttpCommon.Response(200, "trigger phrase not found; no benchmarks ran.")
        end

        # Step 4: parse trigger phrase for tags/sha

        current_sha = GitHub.commit(event)

        phrase = body[last(search(body, trigger)):end]
        args = split(phrase[search(phrase, r"\(.*?\)")][2:(end-1)], '|') # [tags_string, sha]
        tags = map(strip, split(args[1], ','))

        if length(args) == 2
            former_sha = strip(args[2])
        elseif GitHub.name(event) == GitHub.CommitCommentEvent
            former_sha = parent_sha(auth, owner, repo, current_sha)
        elseif GitHub.name(event) == GitHub.PullRequestReviewCommentEvent
            former_sha = base_sha(payload)
        end

        # Step 5: run everything else in a child process

        process_expr = benchmark_process(myid(), current_sha, former_sha,
                                         logger, tags, status_url,
                                         auth, owner, repo, event)

        @spawn eval(process_expr)

        return HttpCommon.Response(200, "benchmark process is running")
    end

    return BenchmarkServer(node_configs, listener)
end

# This is the magic symbol that is utilized by @declare_ci to propogate trackers
# to benchmarking processes (see its usage in `benchmark_process` below). This
# is a hacky approach that relies on the user *not* defining a variable with this
# name; we should definitely come up with a more robust approach later.
const TRACKER_CI_SYMBOL = :_trackers_collection_0x82a300e3cc1919ab

function benchmark_process(parent_process, current_sha, former_sha,
                           logger, tags, status_url,
                           auth, owner, repo, event)
    # The below expression is intended to be eval'd by a child process
    return quote
        # Step 1: Set up a new Pkg environment in the pwd

        ENV["JULIA_PKGDIR"] = pwd()

        Pkg.init()
        Pkg.clone("https://github.com/JuliaCI/BenchmarkTrackers.jl")
        Pkg.clone("https://github.com/$owner/$repo")
        Pkg.resolve()

        # Step 2: Set process variables

        import BenchmarkTrackers, GitHub

        parent_process = $parent_process
        current_sha, former_sha = $current_sha, $former_sha
        logger, tags, status_url = $logger, $tags, $status_url
        auth, owner, repo, event = $auth, $owner, $repo, $event

        try
            # Step 3: Checkout current_sha of package

            pkgpath = Pkg.dir(first(splitext("$repo"))) # `repo` is "MyPkg.jl" or "MyPkg"
            current_pwd = pwd()
            cd(pkgpath)
            run(`git checkout $sha`) # can we do this without shelling out?
            cd(current_pwd)

            # Step 4: Retrieve BenchmarkTracker

            pending = GitHub.Status(GitHub.PENDING;
                                    description="Benchmark environment initialized. Retrieving tracker from runbenchmark.jl...",
                                    context="BenchmarkServer",
                                    target_url=status_url)

            GitHub.respond(event, sha, pending, auth)

            module BenchmarkNamespace # keeps benchmarking namespace from leaking into Main
                include(joinpath(Main.pkgpath, "benchmark", "runbenchmarks.jl"))
                tracker = $TRACKER_CI_SYMBOL
            end

            # Step 5: Run benchmarks

            pending = GitHub.Status(GitHub.PENDING;
                                    description="Running benchmarks...",
                                    context="BenchmarkServer",
                                    target_url=status_url)

            GitHub.respond(event, current_sha, pending, auth)

            current_record = BenchmarkTrackers.run(BenchmarkNamespace.tracker, tags...)

            @spawnat parent_process writelog(logger, current_sha, current_record)

            # Step 6: Perform comparisons and return statuses

            if @fetchfrom parent_process haslog(logger, former_sha)
                former_record = @fetchfrom parent_process readlog(logger, former_sha)
                for tag in tags
                    comparison = BenchmarkTrackers.compare(current_record, former_record, tags=[tag])
                    failed, succeeded = BenchmarkTrackers.judge(comparison)

                    for (metric, record) in BenchmarkTrackers.indexby(failed, BenchmarkTrackers.Metric)
                        BenchmarkTrackers.post_metric_status(event, current_sha, status_url, auth,
                                                             tag, metric, record, GitHub.FAILURE)
                    end

                    for (metric, results) in BenchmarkTrackers.indexby(succeeded, BenchmarkTrackers.Metric)
                        BenchmarkTrackers.post_metric_status(event, current_sha, status_url, auth,
                                                             tag, metric, record, GitHub.SUCCESS)
                    end
                end
            else
                success = GitHub.Status(GitHub.Success;
                                        description="Benchmarking finish; no comparison log was found for commit $former_sha",
                                        context="BenchmarkServer",
                                        target_url=status_url)

                GitHub.respond(event, current_sha, success, auth)
            end

            # Step 7: Clean up Pkg environment

            pop!(ENV, "JULIA_PKGDIR")
            rm(Pkg.dir(), recursive=true)

        catch err
            status = GitHub.Status(GitHub.ERROR;
                                   description="Encountered error during benchmarking: $err",
                                   context="BenchmarkServer",
                                   target_url=status_url)
            GitHub.respond(event, current_sha, status, auth)
        end
    end
end

function run(server::BenchmarkServer, args...; kwargs...)
    for config in server.node_configs
        addprocs(config...)
    end
    GitHub.run(server.listener, args...; kwargs...)
end

macro declare_ci(tracker)
    return esc(:($TRACKER_CI_SYMBOL = $tracker))
end

#############
# Utilities #
#############

function base_branch_sha(payload)
    if haskey(payload, "base")
        base_branch = payload["base"]
        if haskey(base_branch, "sha")
            return base_branch["sha"]
        end
    end
    return ""
end

function parent_sha(auth::GitHub.OAuth2, owner, repo, sha)
    uri = URIParser.URI(GitHub.API_ENDPOINT; path="/repos/$owner/$repo/git/commits/$sha")
    r = Requests.json(Requests.get(uri; query=Dict("access_token"=>auth.token)))

    if haskey(r, "parents")
        parents = r["parents"]
        if !(isempty(parents))
            parent = first(parents)
            if haskey(parent, "sha")
                return parent["sha"]
            end
        end
    end

    return ""
end

id_diff_pair(r::ComparisonResult) = r.id => r.diff

function post_metric_status(event, sha, status_url, auth,
                            tag, metric, record, state)
    trimmed = map(id_diff_pair, take(record, 10))
    lentrim, lentotal = length(trimmed), length(total)
    status = GitHub.Status(state;
                           description="Results (showing $lentrim/$lentotal): $trimmed",
                           context="BenchmarkServer: $tag: $metric",
                           target_url=status_url)
    GitHub.respond(event, current_sha, status, auth)
end

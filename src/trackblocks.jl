###################
# TrackBlock type #
###################

type TrackBlock
    run::Function
    trackables::Vector{Expr}
    metrics::Vector{METRIC}
    tags::Vector{UTF8String}
end

################
# @track macro #
################

macro track(tracker, block)
    # Step 1: Validate that the settings block is indeed a block
    @assert isa(block, Expr) && block.head == :block "malformed track block"

    # Step 2: Extract relevant information from settings
    settings = block.args
    setup = get_unique_macrocall_body(settings, "setup")
    teardown = get_unique_macrocall_body(settings, "teardown")
    trackables = get_trackables(settings)
    metrics = get_metrics(settings)
    samples, seconds = get_constraints(settings)
    tags = get_tags(settings)

    # Step 3: Build an expression for the track block's `run` function.
    run_def = quote
        results = Vector{BenchmarkTrackers.BenchmarkResults}()
        $(setup.args...)
    end

    name = gensym()

    for expr in trackables
        wrapped_expr = Expr(:quote, expr)
        run_def = quote
            $(run_def.args...)
            Benchmarks.@benchmarkable($name, nothing, $expr, nothing)
            result = Benchmarks.execute($name, $samples, $seconds)
            push!(results, BenchmarkTrackers.BenchmarkResults($wrapped_expr, result))
        end
    end

    run_def = quote
        $(run_def.args...)
        $(teardown.args...)
        return results
    end

    # Step 4: Finally, return an expression that instantiates the track block
    # as a `TrackBlock` and adds it to the given tracker's list.
    return quote
        local run_func = () -> $(esc(run_def))
        local track_block = BenchmarkTrackers.TrackBlock(run_func, $trackables,
                                                         METRIC[$(metrics...)],
                                                         UTF8String[$(tags...)])

        BenchmarkTrackers.track!($(esc(tracker)), track_block)
    end
end

# Utilities for extracting setting info #
#---------------------------------------#

ismacrocall(x) = isa(x, Expr) && x.head == :macrocall
ismacrocall(x, name) = ismacrocall(x) && x.args[1] == symbol("@$name")

function get_unique_macrocall(settings, name)
    indices = find(x->ismacrocall(x, name), settings)
    if isempty(indices)
        return :()
    elseif length(indices) == 1
        return settings[first(indices)]
    else
        error("only one @$name can be defined per @track block")
    end
end

function get_unique_macrocall_body(settings, name)
    result = get_unique_macrocall(settings, name)
    return result != :() ? result.args[2] : result
end

function get_tags(settings)
    result = get_unique_macrocall(settings, "tags")
    return result != :() ? result.args[2:end] : result
end

function get_metrics(settings)
    metrics = get_unique_macrocall(settings, "metrics")
    if metrics == :()
        metric_names = map(string, instances(METRIC))
        return [symbol("BenchmarkTrackers.$name") for name in metric_names]
    else
        return metrics.args[2:end]
    end
end

function get_constraints(settings)
    constraints = get_unique_macrocall(settings, "constraints").args[2:end]
    samples, seconds = 100, 10
    for x in constraints
        @assert isa(x, Expr) && x.head == :(=) "malformed @constraint syntax"

        key, val = x.args

        if key == :samples
            samples = val
        elseif key == :seconds
            seconds = val
        else
            error("unsupported constraint: $key=$val")
        end
    end
    return [samples, seconds]
end

function get_trackables(settings)
    macrocalls = filter(x->ismacrocall(x, "trackable"), settings)
    return [x.args[2] for x in macrocalls]
end

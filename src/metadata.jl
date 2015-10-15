#####################
# BenchmarkMetadata #
#####################

type BenchmarkMetadata
    run!::Function
    benchmarks::Vector{Expr}
    tags::Vector{UTF8String}
end

hastag(meta::BenchmarkMetadata, tag::AbstractString) = in(tag, meta.tags)

################
# @track macro #
################

macro track(tracker, metadata_block)
    # Step 1: Validate that settings is a block expression
    is_valid_block = isa(metadata_block, Expr) && metadata_block.head == :block
    @assert is_valid_block "@track metadata block is malformed"

    # Step 2: Extract relevant information from the metadata block
    settings = metadata_block.args
    setup = get_unique_macrocall_body(settings, "setup")
    teardown = get_unique_macrocall_body(settings, "teardown")
    benchmarks = get_benchmarks(settings)
    samples, seconds = get_constraints(settings)
    tags = get_tags(settings)

    # Step 3: Build an expression for the metadata's `run` function
    run_def = quote
        tags = UTF8String[$(tags...)]
        $(setup.args...)
    end

    temp_name = gensym()
    arg_name = :record

    for expr in benchmarks
        run_def = quote
            $(run_def.args...)
            Benchmarks.@benchmarkable($temp_name, nothing, $expr, nothing)
            result = Benchmarks.execute($temp_name, $samples, $seconds)
            id = $(string(expr))
            record[id] = BenchmarkTrackers.BenchmarkResults(result, tags)
        end
    end

    run_def = quote
        $(run_def.args...)
        $(teardown.args...)
        return record
    end

    run_def = quote
        record -> begin
            $(run_def.args...)
        end
    end

    # Step 4: Finally, return an expression that instantiates the appropriate
    # `BenchmarkMetadata` object and adds it to our `BenchmarkTracker`.
    return quote
        local run! = $(esc(run_def))
        local tags = UTF8String[$(tags...)]
        local metadata = BenchmarkTrackers.BenchmarkMetadata(run!,
                                                             $benchmarks,
                                                             tags)
        BenchmarkTrackers.track!($(esc(tracker)), metadata)
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
        error("only one `@$name` can be defined per metadata block")
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

function get_benchmarks(settings)
    macrocalls = filter(x->ismacrocall(x, "benchmark"), settings)
    return [x.args[2] for x in macrocalls]
end

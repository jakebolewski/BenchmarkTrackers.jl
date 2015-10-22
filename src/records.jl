###########
# Records #
###########

# A BenchmarkRecord is a Dict of BenchmarkIDs associated with BenchmarkResults.
typealias BenchmarkRecord Dict{BenchmarkID,BenchmarkResult}

# A ComparisonRecord is a vector of ComparisonResults that can be
typealias ComparisonRecord Vector{ComparisonResult}

function addresult!{K}(record::ComparisonRecord,
                       result::ComparisonResult,
                       key::K)

    return record
end

@generated function indexby{K}(record::ComparisonRecord, ::Type{K})
    if K == Metric
        field = :metric
    elseif K == BenchmarkID
        field = :id
    else
        error("cannot index ComparisonRecord by $K")
    end

    return quote
        dict = Dict{K,ComparisonRecord}()
        for result in record
            key = result.$field
            if haskey(dict, key)
                push!(dict[key], result)
            else
                dict[key] = vcat(result)
            end
        end
        return dict
    end
end

###############################################
# Performing comparisons on benchmark results #
###############################################

# Calculate the percent difference between a's value and b's value for the given
# metric
function percentdiff(current::BenchmarkResult,
                     former::BenchmarkResult,
                     metric::Metric)
    c, f = current[metric], former[metric]
    return 200 * abs(c - f) / (c + f)
end

# Compare two BenchmarkRecords w.r.t. the given metrics and the provided
# `difference` function, which is called with the signature:
#
#   difference(current_result::BenchmarkResult,
#              former_result::BenchmarkResult,
#              metric::Metric) -> Float64
#
# If a `difference` function is not provided, `percentdiff` is used by default.
#
# Each result with both a `current` version and `former` version is compared.
# Optionally, comparisons can be restricted to results for which the `current`
# version is tagged with at least one of the provided tags.
function compare(difference, current::BenchmarkRecord, former::BenchmarkRecord,
                 metrics=ALL_METRICS; tags=Tag[])
    tags_empty = isempty(tags)
    record = ComparisonRecord()
    for (id, current_result) in current
        valid_tags = tags_empty || anytags(current_result, tags)
        if valid_tags && haskey(former, id)
            former_result = former[id]
            for metric in metrics
                diff = difference(current_result, former_result, metric)
                push!(record, ComparisonResult(metric, id, diff))
            end
        end
    end
    return record
end

function compare(current::BenchmarkRecord, former::BenchmarkRecord,
                 metrics::Tuple=ALL_METRICS; tags=Tag[])
    return compare(percentdiff, current, former, metrics; tags=tags)
end

# This failure predicate determines that a ComparisonResult is a failure if
# its difference is a NaN or is positive within a 5-point tolerance.
function isfailure(result::ComparisonResult,
                   tolerance::Number=5.0)
    diff = result.difference
    return isnan(diff) || (diff - tolerance) > 0.0
end

# Returns one ComparisonRecord containing the "failing" results, and one
# ComparisonRecord containing the "succeeding" results. Failure is determined
# by calling the given predicate, which is expected to have the following
# signature:
#
#   predicate(result::ComparisonResult) -> Bool
#
# If a predicate is not passed in, `isfailure` is used by default.
function judge(predicate, record::ComparisonRecord)
    fails = ComparisonRecord()
    successes = ComparisonRecord()
    for result in record
        if predicate(result)
            push!(fails, result)
        else
            push!(successes, result)
        end
    end
    return fails, successes
end

judge(record::ComparisonRecord) = judge(isfailure, record)

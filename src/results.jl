###########
# Metrics #
###########

immutable Metric{field} end

const AllocationsMetric = Metric{:allocations}()
const GCMetric = Metric{:gcpercent}()
const MemoryMetric = Metric{:bytes}()
const TimeMetric = Metric{:nanoseconds}()

const ALL_METRICS = tuple(AllocationsMetric, GCMetric, MemoryMetric, TimeMetric)

export AllocationsMetric,
       GCMetric,
       MemoryMetric,
       TimeMetric

####################
# BenchmarkResults #
####################

immutable BenchmarkResults
    nanoseconds::Float64
    gcpercent::Float64
    bytes::Int
    allocations::Int
    samples::Int
    rsquared::Nullable{Float64}
    tags::Vector{UTF8String}
end

# This constructor is going to be fragile until Benchmarks.jl has a stable API
function BenchmarkResults(results::Benchmarks.Results, tags=UTF8String[])

    stats = Benchmarks.SummaryStatistics(results)
    nanoseconds = stats.elapsed_time_center
    gcpercent = stats.gc_proportion_center
    bytes = stats.bytes_allocated
    allocations = stats.allocations
    samples = stats.n
    rsquared = stats.r²

    return BenchmarkResults(nanoseconds, gcpercent, bytes, allocations,
                            samples, rsquared, Vector{UTF8String}(tags))
end

function Base.getindex{field}(results::BenchmarkResults, ::Metric{field})
    return getfield(results, field)
end

gettags(results::BenchmarkResults) = results.tags

###########
# Records #
###########

# We don't really need to implement whole new types for these
typealias BenchmarkRecord Dict{UTF8String,BenchmarkResults}
typealias MetricRecord{M<:Tuple} Dict{UTF8String,M}

###############################
# Comparing benchmark results #
###############################

# Calculate the percent difference between
# a's value and b's value for the given metric
function compare(current::BenchmarkResults,
                 former::BenchmarkResults,
                 metric::Metric)
    c, f = current[metric], former[metric]
    return 200 * abs(c - f) / (c + f)
end

# Compare two BenchmarkRecords w.r.t. the given metrics. Each individual
# benchmark with both a `current` version and `former` version is compared.
# Optionally, comparisons can be restricted to benchmarks for which the
# `current` version is tagged with at least one of the provided tags.
@generated function compare{T<:Tuple}(current::BenchmarkRecord,
                                      former::BenchmarkRecord,
                                      metrics::T=ALL_METRICS;
                                      tags=UTF8String[])
    M = Tuple{[Pair{t, Float64} for t in T.parameters]...}
    return quote
        tags_empty = isempty(tags)
        record = MetricRecord{$M}()
        for (id, c) in current
            valid_tags = tags_empty || anytags(c, tags)
            if valid_tags && haskey(former, id)
                f = former[id]
                record[id] = map(m -> m=>compare(c, f, m), metrics)
            end
        end
        return record
    end
end

# Assume that all metrics are defined such that
# a negative percent difference == success
check_success(diff, tolerance=5.0) = (diff - tolerance) <= 0.0

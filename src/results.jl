###########
# Metrics #
###########

abstract Metric{field}

const AllocationsMetric = Metric{:allocations}
const GCMetric = Metric{:gcpercent}
const MemoryMetric = Metric{:bytes}
const TimeMetric = Metric{:nanoseconds}

const ALL_METRICS = tuple(AllocationsMetric, GCMetric, MemoryMetric, TimeMetric)

for metric in ALL_METRICS
    @eval export $(symbol(metric))
end

####################
# BenchmarkResults #
####################

immutable BenchmarkResults
    nanoseconds::NTuple{3,Nullable{Float64}}
    gcpercent::NTuple{3,Nullable{Float64}}
    bytes::Int
    allocations::Int
    samples::Int
    rsquared::Nullable{Float64}
    tags::Vector{UTF8String}
end

# This constructor is going to be fragile until Benchmarks.jl has a stable API
function BenchmarkResults(results::Benchmarks.Results, tags=UTF8String[])

    stats = Benchmarks.SummaryStatistics(results)
    nanoseconds = (stats.elapsed_time_lower,
                   stats.elapsed_time_center,
                   stats.elapsed_time_upper)
    gcpercent = (stats.gc_proportion_lower,
                 stats.gc_proportion_center,
                 stats.gc_proportion_upper)
    bytes = stats.bytes_allocated
    allocations = stats.allocations
    samples = stats.n
    rsquared = stats.r²

    return BenchmarkResults(nanoseconds, gcpercent, bytes, allocations,
                            samples, rsquared, Vector{UTF8String}(tags))
end

function get_metric{field}(results::BenchmarkResults, ::Type{Metric{field}})
    return results.field
end

###################
# BenchmarkRecord #
###################

typealias BenchmarkRecord Dict{UTF8String,BenchmarkResults}

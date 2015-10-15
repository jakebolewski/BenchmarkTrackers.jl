###############
# METRIC enum #
###############
# The METRIC values available have a one-to-one correspondence with
# the results obtained from benchmarking a function using Benchmarks.jl.

@enum METRIC Seconds GCPercent Bytes Allocations

export METRIC

for metric in instances(METRIC)
    @eval export $(symbol(metric))
end

#########################
# BenchmarkResults type #
#########################

immutable BenchmarkResults
    id::UTF8String
    nanoseconds::NTuple{3,Nullable{Float64}}
    gcpercent::NTuple{3,Nullable{Float64}}
    bytes::Int
    allocations::Int
    samples::Int
    rsquared::Nullable{Float64}
    tags::Vector{UTF8String}
end

# This constructor is going to be fragile until Benchmarks.jl has a stable API
function BenchmarkResults(id::AbstractString,
                          results::Benchmarks.Results,
                          tags::Vector=UTF8String[])

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

    return BenchmarkResults(UTF8String(id), nanoseconds, gcpercent,
                            bytes, allocations, samples, rsquared,
                            Vector{UTF8String}(tags))
end

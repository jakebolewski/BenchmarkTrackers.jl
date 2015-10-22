###########
# Metrics #
###########

immutable Metric
    field::Symbol
end

Base.(:(==))(a::Metric, b::Metric) = a.field == b.field

# Bind Metric names to the corresponding fields on the `BenchmarkResult` type.
# The bindings in this list are generated as constants and exported.
const METRIC_BINDINGS = Pair{Symbol,Symbol}[
    :AllocationsMetric=>:allocations,
    :GCMetric=>:gcpercent,
    :MemoryMetric=>:bytes,
    :TimeMetric=>:nanoseconds
]

for (name, field) in METRIC_BINDINGS
    @eval begin
        const $name = Metric($(Expr(:quote, field)))
        export $name
    end
end

const ALL_METRICS = Metric[eval(first(pair)) for pair in METRIC_BINDINGS]

function Base.show(io::IO, metric::Metric)
    i = findfirst(m -> m.second == metric.field , METRIC_BINDINGS)
    if i == 0
        print(io, metric)
    else
        print(io, "BenchmarkTrackers.", METRIC_BINDINGS[i].first)
    end
end

###################
# BenchmarkResult #
###################

# A `BenchmarkResult` stores the information obtained from executing a specific
# benchmark. The actual values are extracted from the results provided by
# Benchmarks.jl.
immutable BenchmarkResult
    # Note that all fields corresponding to Metrics are Float64; this is for the
    # sake of type stability when accessing result field by a Metric.
    nanoseconds::Float64
    gcpercent::Float64
    bytes::Float64
    allocations::Float64
    samples::Int
    evals::Int
    rsquared::Nullable{Float64}
    tags::Vector{Tag}
end

# This constructor is going to be fragile until Benchmarks.jl has a stable API
function BenchmarkResult(result::Benchmarks.Results, tags=Tag[])

    stats = Benchmarks.SummaryStatistics(result)
    nanoseconds = stats.elapsed_time_center
    gcpercent = stats.gc_proportion_center
    bytes = stats.bytes_allocated
    allocations = stats.allocations
    samples = stats.n
    evals = stats.n_evaluations
    rsquared = stats.r²

    return BenchmarkResult(nanoseconds, gcpercent, bytes, allocations,
                           samples, evals, rsquared, Vector{Tag}(tags))
end

function Base.getindex(result::BenchmarkResult, metric::Metric)
    return getfield(result, metric.field)::Float64
end

gettags(result::BenchmarkResult) = result.tags

function Base.show(io::IO, result::BenchmarkResult)
    println(io, "BenchmarkResult:")
    println(io, "  tags: ", result.tags)
    println(io, "  estimated time per evaluation (ns): ", result.nanoseconds)
    println(io, "  estimated % of time spent in GC: ", result.gcpercent)
    println(io, "  bytes allocated: ", result.bytes)
    println(io, "  allocations: ", result.bytes)
    println(io, "  samples: ", result.samples)
    println(io, "  evaluations: ", result.evals)
    print(io,   "  r²: ", result.rsquared)
end

####################
# ComparisonResult #
####################

# Stores "difference" between two BenchmarkResults w.r.t. a specific metric.
immutable ComparisonResult
    metric::Metric
    id::BenchmarkID
    difference::Float64
end

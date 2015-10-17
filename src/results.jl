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
    tags::Vector{UTF8String}
end

# This constructor is going to be fragile until Benchmarks.jl has a stable API
function BenchmarkResult(result::Benchmarks.Results, tags=UTF8String[])

    stats = Benchmarks.SummaryStatistics(result)
    nanoseconds = stats.elapsed_time_center
    gcpercent = stats.gc_proportion_center
    bytes = stats.bytes_allocated
    allocations = stats.allocations
    samples = stats.n
    evals = stats.n_evaluations
    rsquared = stats.r²

    return BenchmarkResult(nanoseconds, gcpercent, bytes, allocations,
                           samples, evals, rsquared, Vector{UTF8String}(tags))
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

################
# ComparisonResult #
################

# Stores "difference" between two BenchmarkResults w.r.t. a specific metric.
immutable ComparisonResult
    metric::Metric
    difference::Float64
end

###########
# Records #
###########

# aliases #
#---------#

# A BenchmarkRecord is a Dict of IDs associated with BenchmarkResults.
typealias BenchmarkRecord Dict{UTF8String,BenchmarkResult}

# A ComparisonRecord is a Dict of IDs associated with ComparisonResults.
typealias ComparisonRecord Dict{UTF8String,Vector{ComparisonResult}}

function addresult!(record::ComparisonRecord,
                    result::ComparisonResult,
                    id::AbstractString)
    if haskey(record, id)
        push!(record[id], result)
    else
        record[id] = ComparisonResult[result]
    end
    return record
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
                 metrics=ALL_METRICS; tags=UTF8String[])
    tags_empty = isempty(tags)
    record = ComparisonRecord()
    for (id, current_result) in current
        valid_tags = tags_empty || anytags(current_result, tags)
        if valid_tags && haskey(former, id)
            former_result = former[id]
            for metric in metrics
                diff = difference(current_result, former_result, metric)
                addresult!(record, ComparisonResult(metric, diff), id)
            end
        end
    end
    return record
end

function compare(current::BenchmarkRecord, former::BenchmarkRecord,
                 metrics::Tuple=ALL_METRICS; tags=UTF8String[])
    return compare(percentdiff, current, former, metrics; tags=tags)
end

# This failure predicate determines that a ComparisonResult is a failure if
# its difference is a NaN or is positive within a 5-point tolerance.
function isfailure(id::AbstractString,
                   result::ComparisonResult,
                   tolerance::Number=5.0)
    diff = result.difference
    return isnan(diff) || (diff - tolerance) > 0.0
end

# Takes in a ComparisonRecord and returns a ComparisonRecord containing the
# input's "failing" results. Failure is determined by calling the given
# predicate, which is expected to have the following signature:
#
#   predicate(id::UTF8String, result::ComparisonResult) -> Bool
#
# If a predicate is not passed in, `isfailure` is used by default.
function failures(predicate, record::ComparisonRecord)
    fails = ComparisonRecord()
    for (id, results) in record
        for result in results
            if predicate(id, result)
                addresult!(fails, result, id)
            end
        end
    end
    return fails
end

failures(record::ComparisonRecord) = failures(isfailure, record)

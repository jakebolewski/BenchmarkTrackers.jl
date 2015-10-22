# A BenchmarkLogger serializes and deserializes BenchmarkRecords.
#
# All subtypes L <: BenchmarkLogger should implement:
#
#   writelog(logger::L, sha::AbstractString, record::BenchmarkRecord)
#
# Log a `record` associated with the commit `sha`. If a log for `sha`
# already exists, the new log should overwrite it, but contain both the old
# results and the new results (favoring the new results in case of collision).
#
#   readlog(logger::L, sha::AbstractString)
#
# Return the BenchmarkRecord associated with the commit `sha`.
#
#   haslog(logger::L, sha::AbstractString)
#
# Return `true` if the log exists, otherwise return `false`

abstract BenchmarkLogger

#############
# JLDLogger #
#############

immutable JLDLogger <: BenchmarkLogger
    path::UTF8String
    prefix::UTF8String
    maxlogs::Int
    history::Vector{UTF8String}
    function JLDLogger(path=pwd(); prefix="benchmarks", maxlogs=typemax(Int))
        return new(path, prefix, maxlogs, Vector{UTF8String}())
    end
end

function filepath(logger::JLDLogger, sha::AbstractString)
    return joinpath(logger.path, "$(logger.prefix)_$sha.jld")
end

function haslog(logger::JLDLogger, sha::AbstractString)
    return isfile(filepath(logger, sha))
end

function writelog(logger::JLDLogger, sha::AbstractString, record::BenchmarkRecord)
    path = filepath(logger, sha)

    println("logging to: $path")

    push!(logger.history, path)
    if length(logger.history) > log.maxlogs
        rm(shift!(logger.history))
    end

    if isfile(path)
        record = BenchmarkRecord(merge(JLD.load(path), record))
    end

    JLD.save(path, record)

    println("isfile?: $(isfile(path))")
end

function readlog(logger::JLDLogger, sha::AbstractString)
    return BenchmarkRecord(JLD.load(filepath(logger, sha)))
end

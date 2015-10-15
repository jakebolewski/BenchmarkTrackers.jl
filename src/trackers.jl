
export BenchmarkTracker

####################
# BenchmarkTracker #
####################

type BenchmarkTracker
    name::UTF8String
    metas::Vector{BenchmarkMetadata}
end

function BenchmarkTracker(name::AbstractString)
    return BenchmarkTracker(name, Vector{BenchmarkMetadata}())
end

track!(tracker::BenchmarkTracker, meta::BenchmarkMetadata) = push!(tracker.metas, meta)

######################
# Running benchmarks #
######################

function run(tracker::BenchmarkTracker, tags::AbstractString...)
    if isempty(tags)
        metas = tracker.metas
    else
        tag_predicate = meta -> any(tag -> hastag(meta, tag), tags)
        metas = filter(tag_predicate, tracker.metas)
    end

    record = BenchmarkRecord()

    for meta in metas
        meta.run!(record)
    end

    return record
end

########################
# Comparing benchmarks #
########################

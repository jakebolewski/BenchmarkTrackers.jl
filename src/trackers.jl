
export BenchmarkTracker

####################
# BenchmarkTracker #
####################

type BenchmarkTracker
    metas::Vector{BenchmarkMetadata}
end

BenchmarkTracker() = BenchmarkTracker(Vector{BenchmarkMetadata}())

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


export BenchmarkTracker

#########################
# BenchmarkTracker type #
#########################

type BenchmarkTracker
    name::UTF8String
    blocks::Vector{TrackBlock}
end

BenchmarkTracker(name::AbstractString) = BenchmarkTracker(UTF8String(name), Vector{TrackBlock}())

track!(tracker::BenchmarkTracker, block::TrackBlock) = push!(tracker.blocks, block)

######################
# Running benchmarks #
######################

function run(tracker::BenchmarkTracker, tags::AbstractString...)
    results = Vector{BenchmarkResults}()

    if isempty(tags)
        blocks = tracker.blocks
    else
        tag_predicate = block -> any(tag -> hastag(block, tag), tags)
        blocks = filter(tag_predicate, tracker.blocks)
    end

    for block in blocks
        append!(results, block.run())
    end

    return results
end

########################
# Comparing benchmarks #
########################

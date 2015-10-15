
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

#########################
# Benchmark comparisons #
#########################

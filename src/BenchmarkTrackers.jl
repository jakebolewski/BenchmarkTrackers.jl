module BenchmarkTrackers

import GitHub, Benchmarks

export BenchmarkTracker, @track

include("results.jl")
include("metadata.jl")
include("trackers.jl")

# Any type that defines `gettags` is Taggable
typealias Taggable Union{BenchmarkMetadata,BenchmarkResults}

hastag(b::Taggable, tag) = in(tag, gettags(b))
anytags(b::Taggable, tags) = any(t -> hastag(b, t), tags)
alltags(b::Taggable, tags) = all(t -> hastag(b, t), tags)

end # module BenchmarkTrackers

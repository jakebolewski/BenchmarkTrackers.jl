module BenchmarkTrackers

#################
# import/export #
#################

import GitHub, Benchmarks

export BenchmarkTracker, @track

###########
# include #
###########

include("results.jl")
include("metadata.jl")
include("trackers.jl")
include("logging.jl")
include("server.jl")

###############################
# misc. utitily methods/types #
###############################

# Any type that defines `gettags` is Taggable
typealias Taggable Union{BenchmarkMetadata,BenchmarkResult}

hastag(b::Taggable, tag) = in(tag, gettags(b))
anytags(b::Taggable, tags) = any(t -> hastag(b, t), tags)
alltags(b::Taggable, tags) = all(t -> hastag(b, t), tags)

end # module BenchmarkTrackers

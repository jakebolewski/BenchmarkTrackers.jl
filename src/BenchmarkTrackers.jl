module BenchmarkTrackers

#################
# import/export #
#################

import GitHub, Benchmarks, JLD, HttpCommon, URIParser, Requests

export BenchmarkTracker, BenchmarkServer, @track, @declare_ci, 

###########
# include #
###########
typealias BenchmarkID UTF8String
typealias Tag UTF8String

include("results.jl")
include("records.jl")
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

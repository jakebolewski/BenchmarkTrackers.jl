home = homedir()
workspace = joinpath(home, "benchmark_workspace")

if !(isdir(workspace))
    mkdir(workspace)
end

cd(workspace)

addprocs()

using BenchmarkTrackers, GitHub

logger = BenchmarkTrackers.JLDLogger(workspace)
auth = GitHub.OAuth2(ENV["GITHUB_AUTH_TOKEN"])
secret = ENV["MY_SECRET"]
owner = "JuliaCI"
repo = "BenchmarkTrackers.jl"
trigger = "%NanosoldierRunBenchmarks"

server = BenchmarkTrackers.BenchmarkServer(logger, auth, secret, owner, repo; trigger=trigger, workspace=workspace)

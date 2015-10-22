import BenchmarkTrackers, GitHub

home = homedir()
workspace = joinpath(home, "benchmark_workspace")

if !(isdir(workspace))
    mkdir(workspace)
end

cd(workspace)

logger = BenchmarkTrackers.JLDLogger(workspace)
node_configs = [tuple(["nanosoldier5"])]
auth = GitHub.OAuth2(ENV["GITHUB_AUTH_TOKEN"])
secret = ENV["MY_SECRET"]
owner = "jrevels"
repo = "webhooks-test"
mytrigger = "%NanosoldierRunBenchmarks"

server = BenchmarkServer(node_configs, logger, auth, secret, owner, repo; trigger=mytrigger)

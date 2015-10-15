###############
# METRIC enum #
###############
# The METRIC values available have a one-to-one correspondence with
# the results obtained from benchmarking a function using Benchmarks.jl.

@enum METRIC Seconds GCPercent Bytes Allocations

export METRIC

for metric in instances(METRIC)
    @eval export $(symbol(metric))
end

#########################
# BenchmarkResults type #
#########################

immutable BenchmarkResults
    func_call::Expr
    results::Benchmarks.Results
end

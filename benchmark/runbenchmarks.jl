using BenchmarkTrackers

###########################
# Benchmarkable Functions #
###########################
# First, we provide some functions we wish to benchmark. The actual functions
# below are really dumb, but suffice for the sake of example.

function f(x, y)
    return x + y
end

function g(a, b)
    return cos(a) - sin(b)
end

function h(i)
    x = 0.0
    for j in 1:i
        x += f(j, i) + g(i, j)
    end
    return x
end

#######################
# @track declarations #
#######################

# Next, the user defines a `BenchmarkTracker` to hold all the metadata necessary
# for running benchmarks and performing result comparisons.
mytracker = BenchmarkTracker("mytracker")

# After defining a tracker, we can feed it benchmark metadata via the `@track`
# macro. The syntax of the `@track` macro is:
#
#   @track tracker begin
#       ⋮ # metadata declarations
#    end
#
# Here's using `@track` to define some metadata on `mytracker`:
@track mytracker begin
    # The `@setup` expression runs once before benchmarking begins
    @setup begin
        testx, testy = 1, 2
        testa, testb = 3, 4
    end

    # Expressions marked with `@benchmark` correspond to the function calls we
    # wish to benchmark. The limitations on these expressions are the same as
    # the limitations on expressions passed to Benchmark.@benchmark.
    @benchmark f(testx, testy)
    @benchmark g(testa, testb)

    # The `@teardown` expression runs once after benchmarking ends
    @teardown begin
        println("finished benchmarking `f` and `g`")
    end

    # Benchmark execution for each of the above `@trackable` expressions above
    # will be performed within the budgeted constraints below. For now, only
    # `seconds` and `samples` are supported as constraints.
    @constraints seconds=5 samples=50

    # The below tags will be presented alongside benchmark statuses in GitHub's
    # UI. In addition, one can easily use tags to select which benchmarks they
    # wish to run (we'll provide an example of this later). Note that tag-based
    # benchmark selection opens up the possibility of allowing GitHub's PR
    # labels to dictate which benchmarks actually get run for a given PR.
    @tags "binary" "example"
end

# A single BenchmarkTracker can handle multiple `@track` definitions. For
# example, here we provide some metadata for benchmarking `h` on `mytracker`:
@track mytracker begin

    @setup begin
        test = 25
    end

    @benchmark h(test)

    @teardown begin
        println("finished benchmarking `h`")
    end

    @constraints seconds=4

    @tags "unary"
end

##########################
# Running the benchmarks #
##########################

# We can run all the benchmarks with a given tag by doing:
results1 = BenchmarkTrackers.run(mytracker, "example")

# We can also run a whole selection of tags at once:
results2 = BenchmarkTrackers.run(mytracker, "binary", "unary")

# Or, we can simply run all the benchmarks available by ommitting tags entirely:
results3 = BenchmarkTrackers.run(mytracker)

# We can compare benchmark results using `compare`. In the call below, each
# individual benchmark with both a `results1` version and `results2` version
# is compared. This means that we'll get comparison results for `f` and `g`,
# but not `h` (because `h` isn't present in `results1`).
#
# `compare_results` is a dictionary where the keys are benchmark identifiers,
# and the values are of the form ([metric]=>[percent difference]...).
compare_results = compare(results1, results2, (TimeMetric, GCMetric))

#####################################
# Running Benchmarks as part of CI  #
#####################################
# In the future, the `@declare_ci` macro will be the "hook" utilized by a
# BenchmarkServer to retrieve the given tracker from this file during CI. The
# given metrics tell the server which comparisons to perform and report on using
# the given tracker. One will be able to declare multiple trackers to the same
# server simultaneously.

# @declare_ci mytracker TimeMetric GCMetric
# @declare_ci othertracker AllocationsMetric

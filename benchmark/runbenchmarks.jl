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
# Here's an example of defining a `@track` block on `mytracker`:
@track mytracker begin
    # The `@setup` expression runs once before benchmarking begins
    @setup begin
        testx, testy = 1, 2
        testa, testb = 3, 4
    end

    # The `@trackable` expressions are what actually get benchmarked.
    # The limitations on these expressions are the same as the limitations
    # on expressions passed to Benchmark.@benchmark.
    @trackable f(testx, testy)
    @trackable g(testa, testb)

    # The `@teardown` expression runs once after benchmarking ends
    @teardown begin
        println("finished benchmarking `f` and `g`")
    end

    # All possible metrics will be collected when running benchmarks, but only
    # the ones listed after `@metrics` will be used in benchmark comparisons.
    # For a full list of available metrics, one can run `instances(METRIC)`
    @metrics Seconds GCPercent

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

# A single BenchmarkTracker can handle multiple `@track` blocks. For example,
# here's a `@track` block that defines how to benchmark `h` on `mytracker`:
@track mytracker begin

    @setup begin
        test = 25
    end

    @trackable h(test)

    @teardown begin
        println("finished benchmarking `h`")
    end

    @metrics Seconds

    @constraints seconds=4

    @tags "unary" "example"
end

##########################
# Running the benchmarks #
##########################

# Now, we can simply run all the benchmarks by doing:
results = BenchmarkTrackers.run(mytracker)

# We can run all the benchmarks with a given tag by doing:
example_results = BenchmarkTrackers.run(mytracker, "example")

# We can also run a whole selection of tags at once:
tagged_results = BenchmarkTrackers.run(mytracker, "binary", "unary")

#####################################
# Running Benchmarks as part of CI  #
#####################################
# In the future, the `@declare_ci` macro will be the trigger utilized by a
# BenchmarkServer to retrieve the given tracker from this file during CI. One
# will be able to declare multiple trackers to the same server simultaneously. 

# @declare_ci mytracker
# @declare_ci othertracker

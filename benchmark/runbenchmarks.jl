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
mytracker = BenchmarkTracker()

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
        print("Running setup for `f` and `g` benchmarks...")
        testx, testy = 1, 2
        testa, testb = 3, 4
        println("done.")
    end

    # Expressions marked with `@benchmark` correspond to the function calls we
    # wish to benchmark. The limitations on these expressions are the same as
    # the limitations on expressions passed to Benchmark.@benchmark. The second
    # argument to `@benchmark` is a unique ID for the expression.
    @benchmark f(testx, testy) "f"
    @benchmark g(testa, testb) "g"

    # The `@teardown` expression runs once after benchmarking ends
    @teardown begin
        println("Running teardown for `f` and `g` benchmarks...done.")
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
    @tags "binary" "essentials"
end

# A single BenchmarkTracker can handle multiple `@track` definitions. For
# example, here we provide some metadata for benchmarking `h` on `mytracker`:
@track mytracker begin

    @setup begin
        test = 25
    end

    @benchmark h(test) "h1"

    @constraints seconds=4

    @tags "unary"
end

@track mytracker begin

    @setup begin
        test = 400
    end

    @benchmark h(test) "h2"

    @constraints seconds=3

    @tags "potato"
end

##########################################
# Using BenchmarkTrackers as part of CI  #
##########################################
# The `@declare_ci` macro tells the BenchmarkServer to run `mytracker`'s
# benchmarks during CI

@declare_ci mytracker

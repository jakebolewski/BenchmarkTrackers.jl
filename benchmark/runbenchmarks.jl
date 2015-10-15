using BenchmarkTrackers

###########################
# Benchmarkable Functions #
###########################
# These are functions the user wants to benchmark; they do NOT perform
# benchmarking themselves. The actual benchmarking will be done using
# Benchmarks.jl, which will be a dependency of BenchmarkTrackers.jl.
# The functions below are really dumb, but suffice for the sake of example.
#
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

mytracker = BenchmarkTracker("mytracker")

@track mytracker begin
    # Runs once before benchmarking begins
    @setup begin
        testx, testy = 1, 2
        testa, testb = 3, 4
    end

    # The below function calls will be benchmarked.
    @trackable f(testx, testy)
    @trackable g(testa, testb)

    # Runs once after benchmarking ends
    @teardown begin
        println("finished benchmarking f and g")
    end

    # All possible metrics will be collected when running benchmarks, but only
    # the ones listed after @metrics will be utilized in benchmark comparisons.
    # For a full list of available metrics, one can run `instances(METRIC)`
    @metrics Seconds GCPercent

    # Execution of the benchmarking process for each of the above @trackable
    # functions will work within the budgeted constraints below. For now, only
    # `seconds` and `samples` are supported as constraints.
    @constraints seconds=20 samples=5

    # These tags will be presented alongside benchmark statuses in GitHub's UI.
    # In the future, one will be able to easily select which benchmarks to run
    # via filtering by tag. This opens up the doors for allowing GitHub's PR
    # labels to influence what benchmarks actually get run.
    @tags "binary" "example"
end

# A tracker supports handling multiple track blocks. For example, here's a
# block that tells this tracker how to benchmark "h".
@track mytracker begin

    @setup begin
        test = 25
    end

    @trackable h(test)

    @metrics Seconds

    @constraints seconds=4

    @tags "important" "unary" "profit"
end

# This declares the tracker object that we'd like to use
# for running/comparing benchmarks as part of CI. Multiple
# trackers can be declared for a given package.
# @declare_ci tracker

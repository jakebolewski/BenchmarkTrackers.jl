# BenchmarkTrackers.jl

[![Build Status](https://travis-ci.org/JuliaCI/BenchmarkTrackers.jl.svg?branch=master)](https://travis-ci.org/JuliaCI/BenchmarkTrackers.jl)

The intention of BenchmarkTrackers.jl is to **make performance testing of Julia packages easy** by supplying a framework for **writing benchmarks** and **tracking benchmark results as part of CI**.

Actual benchmark execution is performed using [Benchmarks.jl](https://github.com/jrevels/Benchmarks.jl).

## Quick Install

BenchmarkTrackers.jl depends on the unregistered package Benchmarks.jl, to install first clone the package Benchmarks:
```
julia> Pkg.clone("https://github.com/johnmyleswhite/Benchmarks.jl")
julia> Pkg.clone("https://github.com/JuliaCI/BenchmarkTrackers.jl")
```

## Writing Benchmarks

Benchmarks are written in a package's repository in `benchmark/runbenchmarks.jl`. Check out the [`runbenchmarks.jl`](https://github.com/JuliaCI/BenchmarkTrackers.jl/blob/master/benchmark/runbenchmarks.jl) that demonstrates how benchmarks are written using BenchmarkTrackers.jl.

## CI Benchmark Tracking

Coming Soon!

## Manual Benchmark Tracking

The goal of BenchmarkTrackers.jl is to allow all benchmark execution, result comparison, and status reporting to occur naturally as part of CI. However, you might want to do some tracking yourself, outside of the normal CI flow. In that case, this section demonstrates a workflow for using BenchmarkTrackers.jl "manually."

Note that the machinery described in this section is the same machinery that BenchmarkTrackers.jl itself utilizes during CI.

##### Step 1: Load the example benchmarks

First, you should read and execute the [`runbenchmarks.jl`](https://github.com/JuliaCI/BenchmarkTrackers.jl/blob/master/benchmark/runbenchmarks.jl) file found in this repository. To execute this file, you can run:

```julia
include(joinpath(Pkg.dir("BenchmarkTrackers"), "benchmark/runbenchmarks.jl"))
```

Executing this file will create a `BenchmarkTracker` called `mytracker` and add some benchmark metadata to it via the `@track` macro.

##### Step 2: Run the example benchmarks

Running `mytracker`'s benchmarks is as simple as calling the `run` function:

```julia
# Runs all of mytracker's benchmarks
allresults = BenchmarkTrackers.run(mytracker)
```

This will run *all* of `mytracker`'s benchmarks. If you only wish to run benchmarks with a specific tag, you can simply pass the tag in:

```julia
# Runs only benchmarks with the "essential" tag
essentials = BenchmarkTrackers.run(mytracker, "essentials")
```

`BenchmarkTrackers.run` supports handling multiple tags at once:

```julia
# Runs only benchmarks with the "binary" and/or "unary" tags. For this example,
# the below call happens to be equivalent to running all of mytracker's
# benchmarks at once, since the "binary" + "unary" tags cover all the benchmarks
# we defined.
arities = BenchmarkTrackers.run(mytracker, "binary", "unary")
```

As you can see, the `run` function returns a `Dict{UTF8String,BenchmarkResult}`. BenchmarkTrackers.jl aliases this type to `BenchmarkRecord`. A `BenchmarkRecord` maps benchmark "IDs" to `BenchmarkResult`s. By default, a benchmark's ID is the string representation of the benchmark's function call expression (e.g. the benchmark ID corresponding to `@benchmark f(testx, testy)` is `string(:(f(testx, testy)))` → `"f(testx,testy)"`).

##### Step 3: Compare benchmark results

We can compare benchmark results using the `compare` function. The `compare` function takes in a `BenchmarkRecord`, another `BenchmarkRecord` to compare against, and a tuple of `Metric`s that stipulate what should be compared:

```julia
comparison = BenchmarkTrackers.compare(essentials, arities, (TimeMetric, GCMetric))
```

In the call above, each individual `BenchmarkResult` with both an entry in the `essentials` record and `arities` record is compared. This means that we'll get comparison results for `f(testx, testy)` and `g(testa, testb)`, but not `h(test)` (because `h(test)` isn't present in `essentials`).

The default comparison calculation is `BenchmarkTrackers.percentdiff`, but user-defined comparison functions are also supported. To use your own custom comparison function, simply pass it in as the first argument to `compare`:

```julia
# mycompare is a user-defined function
comparison = BenchmarkTrackers.compare(mycompare, essentials, arities, (TimeMetric, GCMetric))
```

Here, the `mycompare` function should have the following signature:

```julia
mycompare(current::BenchmarkResult, former::BenchmarkResult, metric::Metric) -> Float64
```

...where the returned `Float64` is some measure of difference between `current` and `former` with respect to `metric`.

##### Step 4: Evaluate the comparison results

The result of comparing two `BenchmarkRecord`s is a `Vector{ComparisonResult}`, which BenchmarkTrackers.jl aliases to `ComparisonRecord`. Each `ComparisonResult` stores a benchmark ID, the `Metric` that was compared, and the value obtained from the comparison.

A common operation on a `ComparisonRecord` is to check which results should be considered "failures". This can be accomplished with the `failures` function, which takes in a `ComparisonRecord` and returns a `ComparisonRecord` containing all of the input's "failing" results:

```julia
fails = BenchmarkTrackers.failures(comparison)
```

By default, a "failing" `ComparisonResult` is one in which the `ComparisonResult`'s value is a `NaN`, or is positive (within a tolerance). This default definition of failure is consistent with the default comparison method, which is percent difference. However, you might want to use a different definition for failure. In this situation, you can provide your own custom failure predicate:

```julia
# `mypredicate` is a user-defined function
fails = BenchmarkTrackers.failures(mypredicate, comparison)
```

Here, the `mypredicate` function should have the following signature:

```julia
predicate(result::ComparisonResult) -> Bool
```

...where the returned `Bool` indicates whether or not the `result` should be considered a failure.

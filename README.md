# BenchmarkTrackers.jl

[![Build Status](https://travis-ci.org/jrevels/BenchmarkTrackers.jl.svg?branch=master)](https://travis-ci.org/jrevels/BenchmarkTrackers.jl)

The intention of BenchmarkTrackers.jl is to **make performance testing of Julia packages easy** by supplying a framework for **writing benchmarks** and **tracking benchmark results as part of CI**.

Actual benchmark execution is performed using [Benchmarks.jl](https://github.com/jrevels/Benchmarks.jl).

## Writing benchmarks

Benchmarks are written in a package's repository in `benchmark/runbenchmarks.jl`. Check out the [example `runbenchmarks.jl`](https://github.com/JuliaCI/BenchmarkTrackers.jl/blob/master/benchmark/runbenchmarks.jl) that demonstrates how to use BenchmarkTrackers.jl to write benchmarks.

## CI benchmark tracking

Coming Soon!

## Manual benchmark tracking

The goal of BenchmarkTrackers.jl is to allow all benchmark execution, result comparison, and status reporting to occur naturally as part of CI. However, you might want to do some manual tracking yourself; this section will tell you how to do so.

Note that the machinery described in this section is the same machinery that BenchmarkTrackers.jl itself utilizes during CI.

### Loading the example benchmarks

This section's examples assume that you've read and executed the [example `runbenchmarks.jl`](https://github.com/JuliaCI/BenchmarkTrackers.jl/blob/master/benchmark/runbenchmarks.jl) found in this repository by running:

```julia
julia> include(joinpath(Pkg.dir("BenchmarkTrackers"), "benchmark/runbenchmarks.jl"))
```

Running this file will create a `BenchmarkTracker` called `mytracker` and add some benchmark metadata to it via the `@track` macro.

### Running the example benchmarks

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

As you can see, `allresults`, `essentials`, and `arities` are all `Dict`s. More specifically, they are all `BenchmarkRecord`s, which is the type alias that BenchmarkTrackers.jl defines for `Dict{UTF8String,BenchmarkResult}`. A `BenchmarkRecord` maps benchmark IDs to `BenchmarkResult`s. By default, a benchmark's ID is the string representation of the benchmark's function call expression (e.g. the benchmark ID corresponding to `@benchmark f(testx, testy)` is `string(:(f(testx, testy)))` -> `"f(testx,testy)"`).

### Comparing benchmark results

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

### Evaluating comparison results

As you'll notice in the previous section, the result of comparing two `BenchmarkRecord`s is a `Dict{UTF8String,Vector{ComparisonResult}}`, which BenchmarkTrackers.jl aliases to `ComparisonRecord`. A `ComparisonRecord` maps benchmark IDs to `ComparisonResult`s. Each `ComparisonResult` store the `Metric` that was compared and the value obtained from the comparison.

A common operation on a `ComparisonRecord` is to check which results should be considered "failures". This can easily done with the `failures` function, which takes in a `ComparisonRecord` and returns a `ComparisonRecord` containing all of the input's "failing" results:

```julia
fails = BenchmarkTrackers.failures(comparison)
```

By default, a "failing" `ComparisonResult` is one in which the `ComparisonResult`'s value is a `NaN`, or is positive (within a 5 point tolerance). This default definition of failure is consistent with the default comparison method, which is percent difference. However, you might want to use a different definition for failure. In this situation, you can provide your own custom failure predicate:

```julia
# `mypredicate` is a user-defined function
fails = BenchmarkTrackers.failures(mypredicate, comparison)
```

Here, the `mypredicate` function should have the following signature:

```julia
predicate(id::UTF8String, result::ComparisonResult) -> Bool
```

...where the returned `Bool` indicates whether or not the `result` should be considered a failure.

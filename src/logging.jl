# A `BenchmarkLogger` can serialize and deserialize BenchmarkRecords.
abstract BenchmarkLogger

immutable CSVLogger <: BenchmarkLogger
    logprefix::UTF8String
    logpath::UTF8String
    nlogs::Int
end

writelog(logger::CSVLogger, record::BenchmarkRecord) = #
readlog(logger::CSVLogger, sha::UTF8String) = #

immutable BenchmarkServer{L<:BenchmarkLogger}
    listener::GitHub.EventListener
    machines::Vector{UTF8String}
    logger::L
end

BenchmarkServer(logger::L, github_args...; create_webhook::Bool=false, nodes::Vector=UTF8String[]) = #

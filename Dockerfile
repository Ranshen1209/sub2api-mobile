FROM swift:6.0-jammy AS build
WORKDIR /build
COPY Package.swift ./
COPY Package.resolved ./
COPY Sources ./Sources
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/.build/release/SakrylleServer /app/SakrylleServer
EXPOSE 8787
CMD ["/app/SakrylleServer", "serve", "--hostname", "0.0.0.0", "--port", "8787"]

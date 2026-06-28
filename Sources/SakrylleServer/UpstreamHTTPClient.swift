import Vapor

protocol UpstreamHTTPClient: Sendable {
    func send(_ request: ClientRequest, on req: Request) async throws -> ClientResponse
}

struct VaporUpstreamHTTPClient: UpstreamHTTPClient {
    func send(_ request: ClientRequest, on req: Request) async throws -> ClientResponse {
        try await req.client.send(request)
    }
}

struct UpstreamHTTPClientKey: StorageKey {
    typealias Value = any UpstreamHTTPClient
}

extension Application {
    var sakrylleUpstreamClient: any UpstreamHTTPClient {
        get { storage[UpstreamHTTPClientKey.self] ?? VaporUpstreamHTTPClient() }
        set { storage[UpstreamHTTPClientKey.self] = newValue }
    }
}

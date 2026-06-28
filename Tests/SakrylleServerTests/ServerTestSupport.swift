import NIOCore
import SakrylleShared
@testable import SakrylleServer
import Vapor

actor MockUpstreamClient: UpstreamHTTPClient {
    typealias Handler = @Sendable (ClientRequest) throws -> ClientResponse

    private var requests: [ClientRequest] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func send(_ request: ClientRequest, on req: Request) async throws -> ClientResponse {
        requests.append(request)
        return try handler(request)
    }

    func recordedRequests() -> [ClientRequest] {
        requests
    }
}

func makeTestApp(config: AppConfig, client: any UpstreamHTTPClient = MockUpstreamClient { _ in clientJSON("{}") }) async throws -> Application {
    let app = try await Application.make(.testing)
    app.storage[AppConfigKey.self] = config
    app.storage[UpstreamHTTPClientKey.self] = client
    try routes(app)
    return app
}

func clientJSON(_ json: String, status: HTTPStatus = .ok, contentType: String = "application/json") -> ClientResponse {
    var buffer = ByteBufferAllocator().buffer(capacity: json.utf8.count)
    buffer.writeString(json)
    var headers = HTTPHeaders()
    headers.replaceOrAdd(name: .contentType, value: contentType)
    return ClientResponse(status: status, headers: headers, body: buffer)
}

func defaultConfig(upstream: String = "https://upstream.example/api", key: String = "admin-test-key") -> AppConfig {
    AppConfig(port: 8787, upstreamBaseURL: upstream, adminAPIKey: key, allowOrigin: "*")
}

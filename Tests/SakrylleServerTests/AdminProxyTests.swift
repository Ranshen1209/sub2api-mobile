import NIOCore
import SakrylleShared
import XCTVapor
@testable import SakrylleServer

final class AdminProxyTests: XCTestCase {
    func testProxyInjectsHeadersDeduplicatesURLAndRedactsAccountCredentials() async throws {
        let mock = MockUpstreamClient { request in
            XCTAssertEqual(request.url.string, "https://upstream.example/api/v1/admin/accounts?page=1")
            XCTAssertEqual(request.method, .POST)
            XCTAssertEqual(request.headers.first(name: "x-api-key"), "admin-test-key")
            XCTAssertEqual(request.headers.first(name: "Idempotency-Key"), "idem-1")
            XCTAssertEqual(request.body?.readableData, Data(#"{"ping":true}"#.utf8))
            return clientJSON(#"{"code":0,"data":{"items":[{"credentials":{"api_key":"secret"},"nested":{"credentials":{"token":"t"}}}]}}"#)
        }
        let app = try await makeTestApp(config: defaultConfig(), client: mock)
        addTeardownBlock { try await app.asyncShutdown() }

        var body = ByteBufferAllocator().buffer(capacity: 16)
        body.writeString(#"{"ping":true}"#)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentType, value: "application/json")
        headers.replaceOrAdd(name: "Idempotency-Key", value: "idem-1")

        try await app.test(.POST, "/api/v1/admin/accounts?page=1", headers: headers, body: body) { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: res.body.readableData)
            XCTAssertEqual(decoded, .object([
                "code": .number(0),
                "data": .object([
                    "items": .array([
                        .object([
                            "credentials": .object(["redacted": .bool(true)]),
                            "nested": .object(["credentials": .object(["redacted": .bool(true)])])
                        ])
                    ])
                ])
            ]))
        }

        let requests = await mock.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    func testProxyReturnsConfigErrors() async throws {
        let app = try await makeTestApp(config: defaultConfig(upstream: "", key: "admin-test-key"))
        addTeardownBlock { try await app.asyncShutdown() }

        try await app.test(.GET, "/api/v1/admin/users") { res async throws in
            XCTAssertEqual(res.status, .internalServerError)
            let decoded = try JSONDecoder().decode(ServerErrorResponse.self, from: res.body.readableData)
            XCTAssertEqual(decoded.message, "SUB2API_BASE_URL_NOT_CONFIGURED")
        }
    }
}

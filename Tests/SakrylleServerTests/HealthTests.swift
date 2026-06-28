import XCTVapor
@testable import SakrylleServer

final class HealthTests: XCTestCase {
    func testHealthReportsConfiguredState() async throws {
        let app = try await makeTestApp(config: defaultConfig())
        addTeardownBlock { try await app.asyncShutdown() }

        try await app.test(.GET, "/healthz") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let body = try res.content.decode(HealthResponse.self)
            XCTAssertTrue(body.ok)
            XCTAssertTrue(body.upstreamConfigured)
            XCTAssertTrue(body.apiKeyConfigured)
        }
    }

    func testHealthReportsMissingConfig() async throws {
        let app = try await makeTestApp(config: defaultConfig(upstream: "", key: ""))
        addTeardownBlock { try await app.asyncShutdown() }

        try await app.test(.GET, "/healthz") { res async throws in
            let body = try res.content.decode(HealthResponse.self)
            XCTAssertTrue(body.ok)
            XCTAssertFalse(body.upstreamConfigured)
            XCTAssertFalse(body.apiKeyConfigured)
        }
    }
}

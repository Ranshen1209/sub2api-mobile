import XCTest
@testable import SakrylleShared

final class URLBuilderTests: XCTestCase {
    func testDeduplicatesAPIV1Prefix() throws {
        let url = try URLBuilder.buildRequestURL(baseURL: "https://x.com/api/v1", path: "/api/v1/admin/users")
        XCTAssertEqual(url.absoluteString, "https://x.com/api/v1/admin/users")
    }

    func testDeduplicatesAPIPrefix() throws {
        let url = try URLBuilder.buildRequestURL(baseURL: "https://x.com/api", path: "/api/v1/admin/users")
        XCTAssertEqual(url.absoluteString, "https://x.com/api/v1/admin/users")
    }

    func testNoDeduplicationNeeded() throws {
        let url = try URLBuilder.buildRequestURL(baseURL: "https://x.com", path: "/api/v1/admin/users")
        XCTAssertEqual(url.absoluteString, "https://x.com/api/v1/admin/users")
    }
}

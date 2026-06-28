import XCTest
@testable import SakrylleAdmin

final class SakrylleAdminTests: XCTestCase {
    func testNativeSessionAllowsBaseURLWithoutKey() {
        XCTAssertTrue(hasAuthenticatedAdminSession(baseURL: "https://api.example.com", adminAPIKey: ""))
        XCTAssertFalse(hasAuthenticatedAdminSession(baseURL: "", adminAPIKey: "admin"))
        XCTAssertFalse(hasAuthenticatedAdminSession(baseURL: "https://api.example.com", adminAPIKey: "", platformIsWeb: true))
    }

    func testConfigNormalization() {
        let normalized = normalizeConfig(baseUrl: " https://api.example.com/ ", adminApiKey: " key ")
        XCTAssertEqual(normalized.baseUrl, "https://api.example.com")
        XCTAssertEqual(normalized.adminApiKey, "key")
    }

    func testParseIntList() {
        XCTAssertEqual(parseIntList("1, 2,3"), [1, 2, 3])
    }
}

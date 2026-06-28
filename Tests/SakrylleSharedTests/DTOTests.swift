import XCTest
@testable import SakrylleShared

final class DTOTests: XCTestCase {
    func testEnvelopeDecodesSnakeCaseFields() throws {
        let data = """
        {"code":0,"message":"success","data":{"items":[],"total":0,"page":1,"page_size":20,"pages":1}}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(APIEnvelope<PaginatedData<AdminUserDTO>>.self, from: data)
        XCTAssertEqual(decoded.code, 0)
        XCTAssertEqual(decoded.data?.pageSize, 20)
    }

    func testDynamicDictionaryKeepsRawKeys() throws {
        let data = #"{"site_name":"Sakrylle","camelKey":true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AdminSettingsDTO.self, from: data)
        XCTAssertEqual(decoded.siteName, "Sakrylle")
        XCTAssertEqual(decoded.raw["camelKey"], .bool(true))
    }

    func testJSONScalarRejectsObjects() {
        let data = #"{"nested":true}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(JSONScalar.self, from: data))
    }
}

import SakrylleShared
import XCTVapor
@testable import SakrylleServer

final class KeysAggregationTests: XCTestCase {
    func testKeysAggregationClampsFiltersSortsAndAttachesUser() async throws {
        let mock = MockUpstreamClient { request in
            let url = request.url.string
            if url.contains("/api/v1/admin/users?page=1&page_size=100") {
                return clientJSON("""
                {"code":0,"message":"success","data":{"items":[{"id":7,"email":"alice@example.com","username":"alice"}],"total":1,"page":1,"page_size":100,"pages":1}}
                """)
            }
            if url.contains("/api/v1/admin/users/7/api-keys?page=1&page_size=100") {
                return clientJSON("""
                {"code":0,"message":"success","data":{"items":[
                    {"id":9,"user_id":7,"key":"sk-alice","name":"Alice Key","status":"active","quota":100,"quota_used":4,"updated_at":"2026-06-28T00:00:00Z"},
                    {"id":10,"user_id":7,"key":"sk-disabled","name":"Other","status":"disabled","quota":100,"quota_used":0,"updated_at":"2026-06-27T00:00:00Z"}
                ],"total":2,"page":1,"page_size":100,"pages":1}}
                """)
            }
            return clientJSON(#"{"code":404,"message":"missing","data":null}"#, status: .notFound)
        }

        let app = try await makeTestApp(config: defaultConfig(), client: mock)
        addTeardownBlock { try await app.asyncShutdown() }

        try await app.test(.GET, "/api/v1/keys?page=-1&page_size=999&search=alice&status=active") { res async throws in
            XCTAssertEqual(res.status, .ok)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(APIEnvelope<PaginatedData<AdminAPIKeyDTO>>.self, from: res.body.readableData)
            XCTAssertEqual(decoded.data?.page, 1)
            XCTAssertEqual(decoded.data?.pageSize, 100)
            XCTAssertEqual(decoded.data?.total, 1)
            XCTAssertEqual(decoded.data?.items.first?.id, 9)
            XCTAssertEqual(decoded.data?.items.first?.user?.email, "alice@example.com")
        }
    }
}

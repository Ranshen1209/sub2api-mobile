import Foundation
import SakrylleShared
import SwiftUI

struct AdminRequestOptions: Sendable {
    var idempotencyKey: String?
}

final class AdminAPIClient: @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let baseURLProvider: @Sendable () -> String
    private let apiKeyProvider: @Sendable () -> String

    init(
        session: URLSession = .shared,
        baseURLProvider: @escaping @Sendable () -> String,
        apiKeyProvider: @escaping @Sendable () -> String
    ) {
        self.session = session
        self.baseURLProvider = baseURLProvider
        self.apiKeyProvider = apiKeyProvider
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func send<T: Codable & Sendable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        query: [URLQueryItem] = [],
        options: AdminRequestOptions = .init()
    ) async throws -> T {
        let baseURL = baseURLProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = apiKeyProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !baseURL.isEmpty else { throw APIClientError.baseURLRequired }
        guard !apiKey.isEmpty else { throw APIClientError.adminAPIKeyRequired }

        var url = try URLBuilder.buildRequestURL(baseURL: baseURL, path: path)
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query
            if let nextURL = components?.url { url = nextURL }
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        if let key = options.idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        if let body {
            request.httpBody = try encodeAny(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidServerResponse }
        let envelope: APIEnvelope<T>
        do {
            envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
        } catch {
            if T.self == JSONValue.self,
               (200..<300).contains(http.statusCode),
               let value = try? decoder.decode(JSONValue.self, from: data),
               let payload = value as? T {
                return payload
            }
            throw APIClientError.invalidServerResponse
        }
        guard (200..<300).contains(http.statusCode), envelope.code == 0 else {
            throw APIClientError.requestFailed(envelope.reason ?? envelope.message)
        }
        guard let payload = envelope.data else {
            if T.self == JSONValue.self, let payload = JSONValue.null as? T {
                return payload
            }
            throw APIClientError.missingData
        }
        return payload
    }

    private func encodeAny(_ value: any Encodable) throws -> Data {
        struct AnyEncodable: Encodable {
            let value: any Encodable
            func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
        }
        return try encoder.encode(AnyEncodable(value: value))
    }
}

extension AdminAPIClient {
    func getDashboardStats() async throws -> DashboardStatsDTO {
        try await send("/api/v1/admin/dashboard/stats")
    }

    func getAdminSettings() async throws -> AdminSettingsDTO {
        try await send("/api/v1/admin/settings")
    }

    func getDashboardTrend(startDate: String, endDate: String, granularity: String?, accountID: Int? = nil, groupID: Int? = nil, userID: Int? = nil) async throws -> DashboardTrendDTO {
        try await send("/api/v1/admin/dashboard/trend", query: compactQuery([
            "start_date": startDate,
            "end_date": endDate,
            "granularity": granularity,
            "account_id": accountID,
            "group_id": groupID,
            "user_id": userID
        ]))
    }

    func getDashboardModels(startDate: String, endDate: String) async throws -> DashboardModelStatsDTO {
        try await send("/api/v1/admin/dashboard/models", query: compactQuery(["start_date": startDate, "end_date": endDate]))
    }

    func getDashboardSnapshot(params: [String: any CustomStringConvertible]) async throws -> DashboardSnapshotDTO {
        try await send("/api/v1/admin/dashboard/snapshot-v2", query: params.map { URLQueryItem(name: $0.key, value: "\($0.value)") })
    }

    func getUsageStats(params: [String: any CustomStringConvertible]) async throws -> UsageStatsDTO {
        var query = params.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        if !params.keys.contains("timezone") {
            query.append(URLQueryItem(name: "timezone", value: TimeZone.current.identifier))
        }
        return try await send("/api/v1/admin/usage/stats", query: query)
    }

    func listUsers(search: String = "", page: Int = 1, pageSize: Int = 20, sortOrder: String? = nil) async throws -> PaginatedData<AdminUserDTO> {
        try await send("/api/v1/admin/users", query: compactQuery([
            "page": page,
            "page_size": pageSize,
            "search": search.trimmingCharacters(in: .whitespacesAndNewlines),
            "sort_by": "last_used_at",
            "sort_order": sortOrder
        ]))
    }

    func getUser(_ id: Int) async throws -> AdminUserDTO {
        try await send("/api/v1/admin/users/\(id)")
    }

    func createUser(_ body: CreateUserRequestDTO) async throws -> AdminUserDTO {
        try await send("/api/v1/admin/users", method: "POST", body: body)
    }

    func listUserAPIKeys(userID: Int) async throws -> PaginatedData<AdminAPIKeyDTO> {
        try await send("/api/v1/admin/users/\(userID)/api-keys", query: compactQuery(["page": 1, "page_size": 100]))
    }

    func updateUserBalance(userID: Int, request: UpdateBalanceRequestDTO) async throws -> AdminUserDTO {
        let key = "user-balance-\(userID)-\(Int(Date().timeIntervalSince1970 * 1000))"
        return try await send("/api/v1/admin/users/\(userID)/balance", method: "POST", body: request, options: .init(idempotencyKey: key))
    }

    func updateUserStatus(userID: Int, status: String) async throws -> AdminUserDTO {
        try await send("/api/v1/admin/users/\(userID)", method: "PUT", body: UpdateUserStatusRequestDTO(status: status))
    }

    func listGroups(search: String = "") async throws -> PaginatedData<AdminGroupDTO> {
        try await send("/api/v1/admin/groups", query: compactQuery(["page": 1, "page_size": 20, "search": search.trimmingCharacters(in: .whitespacesAndNewlines)]))
    }

    func listAccounts(search: String = "") async throws -> PaginatedData<AdminAccountDTO> {
        try await send("/api/v1/admin/accounts", query: compactQuery(["page": 1, "page_size": 20, "search": search.trimmingCharacters(in: .whitespacesAndNewlines)]))
    }

    func createAccount(_ body: CreateAccountRequestDTO) async throws -> AdminAccountDTO {
        try await send("/api/v1/admin/accounts", method: "POST", body: body)
    }

    func getAccountTodayStats(accountID: Int) async throws -> AccountTodayStatsDTO {
        try await send("/api/v1/admin/accounts/\(accountID)/today-stats")
    }

    func testAccount(accountID: Int) async throws -> JSONValue {
        try await send("/api/v1/admin/accounts/\(accountID)/test", method: "POST")
    }

    func refreshAccount(accountID: Int) async throws -> JSONValue {
        try await send("/api/v1/admin/accounts/\(accountID)/refresh", method: "POST")
    }

    func setAccountSchedulable(accountID: Int, schedulable: Bool) async throws -> AdminAccountDTO {
        try await send("/api/v1/admin/accounts/\(accountID)/schedulable", method: "POST", body: SetAccountSchedulableRequestDTO(schedulable: schedulable))
    }

    private func compactQuery(_ values: [String: Any?]) -> [URLQueryItem] {
        values.compactMap { key, value in
            guard let value else { return nil }
            let text = "\(value)"
            return text.isEmpty ? nil : URLQueryItem(name: key, value: text)
        }
    }
}

private struct AdminAPIClientKey: EnvironmentKey {
    static let defaultValue = AdminAPIClient(baseURLProvider: { "" }, apiKeyProvider: { "" })
}

extension EnvironmentValues {
    var adminAPIClient: AdminAPIClient {
        get { self[AdminAPIClientKey.self] }
        set { self[AdminAPIClientKey.self] = newValue }
    }
}

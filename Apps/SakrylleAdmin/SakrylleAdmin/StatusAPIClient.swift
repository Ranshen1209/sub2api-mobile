import Foundation
import SakrylleShared
import SwiftUI

final class StatusAPIClient: @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL = URL(string: "https://status.sakrylle.com")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func getServiceStatus(period: StatusPeriod = .twentyFourHours) async throws -> [StatusGroupDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/status"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "period", value: period.rawValue),
            URLQueryItem(name: "board", value: "hot")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIClientError.requestFailed("STATUS_FETCH_FAILED")
        }
        let decoded = try decoder.decode(StatusResponseDTO.self, from: data)
        return decoded.groups
    }
}

private struct StatusAPIClientKey: EnvironmentKey {
    static let defaultValue = StatusAPIClient()
}

extension EnvironmentValues {
    var statusAPIClient: StatusAPIClient {
        get { self[StatusAPIClientKey.self] }
        set { self[StatusAPIClientKey.self] = newValue }
    }
}

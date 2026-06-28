import Foundation
import SakrylleShared
import Vapor

struct Sub2APIClient {
    let req: Request

    func fetchAdminJSON<T: Codable & Sendable>(path: String) async throws -> T {
        let config = req.application.sakrylleConfig
        guard !config.upstreamBaseURL.isEmpty else {
            throw Abort(.internalServerError, reason: "SUB2API_BASE_URL_NOT_CONFIGURED")
        }
        guard !config.adminAPIKey.isEmpty else {
            throw Abort(.internalServerError, reason: "SUB2API_ADMIN_API_KEY_NOT_CONFIGURED")
        }

        let url = try URLBuilder.buildRequestURL(baseURL: config.upstreamBaseURL, path: path)
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: "x-api-key", value: config.adminAPIKey)
        headers.replaceOrAdd(name: .accept, value: "application/json")
        let request = ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
        let response = try await req.application.sakrylleUpstreamClient.send(request, on: req)
        guard (200..<300).contains(response.status.code), let body = response.body else {
            throw Abort(.badGateway, reason: "UPSTREAM_REQUEST_FAILED")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let envelope = try decoder.decode(APIEnvelope<T>.self, from: body.readableData)
        guard envelope.code == 0 else {
            throw Abort(.badGateway, reason: envelope.reason ?? envelope.message)
        }
        guard let data = envelope.data else {
            throw Abort(.badGateway, reason: "MISSING_RESPONSE_DATA")
        }
        return data
    }
}

import Foundation
import SakrylleShared
import Vapor

struct AdminProxyController {
    func proxy(req: Request) async throws -> Response {
        let config = req.application.sakrylleConfig
        guard !config.upstreamBaseURL.isEmpty else {
            return try jsonError(.internalServerError, message: "SUB2API_BASE_URL_NOT_CONFIGURED")
        }
        guard !config.adminAPIKey.isEmpty else {
            return try jsonError(.internalServerError, message: "SUB2API_ADMIN_API_KEY_NOT_CONFIGURED")
        }

        do {
            let upstreamURL = try URLBuilder.buildRequestURL(baseURL: config.upstreamBaseURL, path: req.url.string)
            var headers = HTTPHeaders()
            headers.replaceOrAdd(name: "x-api-key", value: config.adminAPIKey)
            if let contentType = req.headers.first(name: .contentType) {
                headers.replaceOrAdd(name: .contentType, value: contentType)
            }
            if let idempotencyKey = req.headers.first(name: "Idempotency-Key"), !idempotencyKey.isEmpty {
                headers.replaceOrAdd(name: "Idempotency-Key", value: idempotencyKey)
            }

            var body: ByteBuffer?
            if req.method != .GET && req.method != .HEAD {
                if let incoming = req.body.data, incoming.readableBytes > 0 {
                    body = incoming
                } else {
                    var fallback = req.byteBufferAllocator.buffer(capacity: 2)
                    fallback.writeString("{}")
                    body = fallback
                    if headers.first(name: .contentType) == nil {
                        headers.replaceOrAdd(name: .contentType, value: "application/json")
                    }
                }
            }

            let upstreamRequest = ClientRequest(method: req.method, url: URI(string: upstreamURL.absoluteString), headers: headers, body: body)
            let upstreamResponse = try await req.application.sakrylleUpstreamClient.send(upstreamRequest, on: req)
            return try makeProxyResponse(upstreamResponse, incomingPath: req.url.path)
        } catch {
            if error is APIClientError {
                return try jsonError(.internalServerError, message: "INVALID_UPSTREAM_URL", error: "\(error)")
            }
            return try jsonError(.badGateway, message: "UPSTREAM_REQUEST_FAILED", error: "\(error)")
        }
    }

    private func makeProxyResponse(_ upstreamResponse: ClientResponse, incomingPath: String) throws -> Response {
        var headers = HTTPHeaders()
        if let contentType = upstreamResponse.headers.first(name: .contentType) {
            headers.replaceOrAdd(name: .contentType, value: contentType)
        }
        guard let body = upstreamResponse.body else {
            return Response(status: upstreamResponse.status, headers: headers)
        }

        let contentType = upstreamResponse.headers.first(name: .contentType) ?? ""
        if contentType.lowercased().contains("application/json") {
            let decoded = try JSONDecoder().decode(JSONValue.self, from: body.readableData)
            let value = incomingPath.hasPrefix("/api/v1/admin/accounts") ? CredentialRedactor.redact(decoded) : decoded
            return try jsonResponse(value, status: upstreamResponse.status, headers: headers)
        }

        return Response(status: upstreamResponse.status, headers: headers, body: .init(buffer: body))
    }
}

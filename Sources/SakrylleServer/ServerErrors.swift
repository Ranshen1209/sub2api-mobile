import Foundation
import SakrylleShared
import Vapor

struct ServerErrorResponse: Codable, Sendable {
    let code: Int
    let message: String
    let error: String?

    init(code: Int, message: String, error: String? = nil) {
        self.code = code
        self.message = message
        self.error = error
    }
}

func jsonResponse<T: Encodable>(_ value: T, status: HTTPStatus = .ok, headers: HTTPHeaders = [:]) throws -> Response {
    var responseHeaders = headers
    responseHeaders.replaceOrAdd(name: .contentType, value: "application/json")
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let data = try encoder.encode(value)
    return Response(status: status, headers: responseHeaders, body: .init(data: data))
}

func jsonError(_ status: HTTPStatus, message: String, error: String? = nil) throws -> Response {
    try jsonResponse(ServerErrorResponse(code: Int(status.code), message: message, error: error), status: status)
}

extension ByteBuffer {
    var readableData: Data {
        Data(getBytes(at: readerIndex, length: readableBytes) ?? [])
    }
}

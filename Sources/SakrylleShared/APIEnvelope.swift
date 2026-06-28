import Foundation

public enum APIClientError: LocalizedError, Equatable, Sendable {
    case baseURLRequired
    case adminAPIKeyRequired
    case invalidURL
    case invalidServerResponse
    case requestFailed(String)
    case missingData

    public var errorDescription: String? {
        switch self {
        case .baseURLRequired: return "BASE_URL_REQUIRED"
        case .adminAPIKeyRequired: return "ADMIN_API_KEY_REQUIRED"
        case .invalidURL: return "INVALID_URL"
        case .invalidServerResponse: return "INVALID_SERVER_RESPONSE"
        case .requestFailed(let message): return message
        case .missingData: return "MISSING_RESPONSE_DATA"
        }
    }
}

public struct APIEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let code: Int
    public let message: String
    public let reason: String?
    public let metadata: [String: String]?
    public let data: T?

    public init(code: Int, message: String, reason: String? = nil, metadata: [String: String]? = nil, data: T? = nil) {
        self.code = code
        self.message = message
        self.reason = reason
        self.metadata = metadata
        self.data = data
    }
}

public struct EmptyResponse: Codable, Sendable, Equatable {
    public init() {}
}

public struct PaginatedData<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let total: Int
    public let page: Int
    public let pageSize: Int
    public let pages: Int

    public init(items: [T], total: Int, page: Int, pageSize: Int, pages: Int) {
        self.items = items
        self.total = total
        self.page = page
        self.pageSize = pageSize
        self.pages = pages
    }

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize = "page_size"
        case pages
    }
}

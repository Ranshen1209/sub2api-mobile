import Foundation

public enum StatusPeriod: String, Codable, Sendable, Equatable, CaseIterable {
    case ninetyMinutes = "90m"
    case twentyFourHours = "24h"
    case sevenDays = "7d"
    case thirtyDays = "30d"
}

public struct StatusCountsDTO: Codable, Sendable, Equatable {
    public let available: Int
    public let degraded: Int
    public let unavailable: Int
    public let missing: Int
    public let slowLatency: Int
    public let rateLimit: Int
    public let serverError: Int
    public let clientError: Int
    public let authError: Int
    public let invalidRequest: Int
    public let networkError: Int
    public let responseTimeout: Int
    public let contentMismatch: Int
}

public struct StatusTimePointDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: Int { timestamp }
    public let time: String
    public let timestamp: Int
    public let status: Int
    public let latency: Int
    public let availability: Double
    public let statusCounts: StatusCountsDTO
}

public struct CurrentStatusDTO: Codable, Sendable, Equatable {
    public let status: Int
    public let latency: Int
    public let timestamp: Int
}

public struct StatusLayerDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(model)-\(requestModel)-\(layerOrder)" }
    public let model: String
    public let requestModel: String
    public let layerOrder: Int
    public let currentStatus: CurrentStatusDTO?
    public let timeline: [StatusTimePointDTO]
}

public struct StatusGroupDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(provider)-\(service)-\(channel)" }
    public let provider: String
    public let providerName: String?
    public let providerSlug: String
    public let providerUrl: String
    public let service: String
    public let serviceName: String?
    public let category: String
    public let sponsor: String
    public let sponsorUrl: String
    public let sponsorLevel: String?
    public let channel: String
    public let channelName: String?
    public let board: String
    public let probeUrl: String?
    public let templateName: String?
    public let intervalMs: Int
    public let slowLatencyMs: Int
    public let currentStatus: Int
    public let layers: [StatusLayerDTO]
}

public struct StatusResponseDTO: Codable, Sendable, Equatable {
    public let data: [JSONValue]
    public let groups: [StatusGroupDTO]
    public let meta: [String: JSONValue]
}

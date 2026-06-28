import Foundation

public struct DashboardStatsDTO: Codable, Sendable, Equatable {
    public let totalUsers: Int
    public let todayNewUsers: Int
    public let activeUsers: Int
    public let totalApiKeys: Int
    public let activeApiKeys: Int
    public let totalAccounts: Int
    public let normalAccounts: Int
    public let errorAccounts: Int
    public let totalRequests: Int
    public let totalCost: Double
    public let totalTokens: Int
    public let todayRequests: Int
    public let todayCost: Double
    public let todayTokens: Int
    public let todayInputTokens: Int?
    public let todayOutputTokens: Int?
    public let todayCacheReadTokens: Int?
    public let rpm: Int
    public let tpm: Int
}

public struct TrendPointDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String { date }
    public let date: String
    public let requests: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int
    public let cost: Double
    public let actualCost: Double
}

public struct DashboardTrendDTO: Codable, Sendable, Equatable {
    public let startDate: String
    public let endDate: String
    public let granularity: String
    public let trend: [TrendPointDTO]
}

public struct ModelStatDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: String { model }
    public let model: String
    public let requests: Int
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let totalTokens: Int
    public let cost: Double
    public let actualCost: Double
}

public struct DashboardModelStatsDTO: Codable, Sendable, Equatable {
    public let startDate: String
    public let endDate: String
    public let models: [ModelStatDTO]
}

public struct UsageStatsDTO: Codable, Sendable, Equatable {
    public let totalRequests: Int?
    public let totalTokens: Int?
    public let totalInputTokens: Int?
    public let totalOutputTokens: Int?
    public let totalCost: Double?
    public let totalActualCost: Double?
    public let totalAccountCost: Double?
    public let averageDurationMs: Double?
}

public struct DashboardSnapshotDTO: Codable, Sendable, Equatable {
    public let trend: [TrendPointDTO]?
    public let models: [ModelStatDTO]?
    public let groups: [DashboardGroupStatDTO]?
}

public struct DashboardGroupStatDTO: Codable, Sendable, Equatable, Identifiable {
    public var id: Int { groupId ?? -1 }
    public let groupId: Int?
    public let groupName: String?
    public let requests: Int?
    public let totalTokens: Int?
    public let totalCost: Double?
    public let totalActualCost: Double?
}

public struct AdminSettingsDTO: Codable, Sendable, Equatable {
    public let siteName: String?
    public let raw: [String: JSONValue]

    public init(from decoder: Decoder) throws {
        let raw = try [String: JSONValue](from: decoder)
        self.raw = raw
        if case .string(let value)? = raw["site_name"] {
            self.siteName = value
        } else {
            self.siteName = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        try raw.encode(to: encoder)
    }
}

public struct AdminUserDTO: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let email: String
    public let username: String?
    public let balance: Double?
    public let concurrency: Int?
    public let status: String?
    public let role: String?
    public let currentConcurrency: Int?
    public let notes: String?
    public let lastUsedAt: String?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct UserUsageSummaryDTO: Codable, Sendable, Equatable {
    public let raw: [String: JSONValue]
    public init(from decoder: Decoder) throws { raw = try [String: JSONValue](from: decoder) }
    public func encode(to encoder: Encoder) throws { try raw.encode(to: encoder) }
}

public struct AdminAPIKeyDTO: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let userId: Int
    public let key: String
    public let name: String
    public let groupId: Int?
    public let status: String
    public let quota: Double
    public let quotaUsed: Double
    public let lastUsedAt: String?
    public let expiresAt: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let usage5h: Double?
    public let usage1d: Double?
    public let usage7d: Double?
    public let group: AdminGroupDTO?
    public let user: AdminAPIKeyUserDTO?
}

public struct AdminAPIKeyUserDTO: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let email: String?
    public let username: String?
}

public enum BalanceOperation: String, Codable, Sendable, Equatable, CaseIterable {
    case set
    case add
    case subtract
}

public struct AdminGroupDTO: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let description: String?
    public let platform: String
    public let rateMultiplier: Double?
    public let isExclusive: Bool?
    public let status: String?
    public let subscriptionType: String?
    public let dailyLimitUsd: Double?
    public let weeklyLimitUsd: Double?
    public let monthlyLimitUsd: Double?
    public let accountCount: Int?
    public let sortOrder: Int?
    public let createdAt: String?
    public let updatedAt: String?
}

public struct AccountTodayStatsDTO: Codable, Sendable, Equatable {
    public let requests: Int
    public let tokens: Int
    public let cost: Double
    public let standardCost: Double?
    public let userCost: Double?
}

public struct AdminAccountDTO: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let platform: String
    public let type: String
    public let status: String?
    public let schedulable: Bool?
    public let priority: Int?
    public let concurrency: Int?
    public let currentConcurrency: Int?
    public let rateMultiplier: Double?
    public let errorMessage: String?
    public let updatedAt: String?
    public let lastUsedAt: String?
    public let groupIds: [Int]?
    public let groups: [AdminGroupDTO]?
    public let extra: [String: JSONValue]?
}

public enum AccountType: String, Codable, Sendable, Equatable, CaseIterable {
    case apikey
    case oauth
    case setupToken = "setup-token"
    case upstream
}

public struct CreateAccountRequestDTO: Codable, Sendable, Equatable {
    public let name: String
    public let platform: String
    public let type: AccountType
    public let credentials: [String: JSONScalar]
    public let extra: [String: JSONScalar]?
    public let notes: String?
    public let proxyId: Int?
    public let concurrency: Int?
    public let priority: Int?
    public let rateMultiplier: Double?
    public let groupIds: [Int]?

    public init(name: String, platform: String, type: AccountType, credentials: [String: JSONScalar], extra: [String: JSONScalar]? = nil, notes: String? = nil, proxyId: Int? = nil, concurrency: Int? = nil, priority: Int? = nil, rateMultiplier: Double? = nil, groupIds: [Int]? = nil) {
        self.name = name
        self.platform = platform
        self.type = type
        self.credentials = credentials
        self.extra = extra
        self.notes = notes
        self.proxyId = proxyId
        self.concurrency = concurrency
        self.priority = priority
        self.rateMultiplier = rateMultiplier
        self.groupIds = groupIds
    }
}

public struct CreateUserRequestDTO: Codable, Sendable, Equatable {
    public let email: String
    public let password: String
    public let username: String?
    public let notes: String?
    public let role: String?
    public let status: String?
    public let balance: Double?
    public let concurrency: Int?
    public let extra: [String: JSONScalar]

    public init(email: String, password: String, username: String? = nil, notes: String? = nil, role: String? = nil, status: String? = nil, balance: Double? = nil, concurrency: Int? = nil, extra: [String: JSONScalar] = [:]) {
        self.email = email
        self.password = password
        self.username = username
        self.notes = notes
        self.role = role
        self.status = status
        self.balance = balance
        self.concurrency = concurrency
        self.extra = extra
    }
}

public struct UpdateBalanceRequestDTO: Codable, Sendable, Equatable {
    public let balance: Double
    public let operation: BalanceOperation
    public let notes: String?

    public init(balance: Double, operation: BalanceOperation, notes: String? = nil) {
        self.balance = balance
        self.operation = operation
        self.notes = notes
    }
}

public struct UpdateUserStatusRequestDTO: Codable, Sendable, Equatable {
    public let status: String

    public init(status: String) {
        self.status = status
    }
}

public struct SetAccountSchedulableRequestDTO: Codable, Sendable, Equatable {
    public let schedulable: Bool

    public init(schedulable: Bool) {
        self.schedulable = schedulable
    }
}

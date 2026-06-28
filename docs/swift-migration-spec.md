# Sakrylle Admin Swift 迁移设计文档

> 目标：提供一份自包含的 Sakrylle Admin Swift 迁移实施规格。新的 Codex 会话只凭本文即可创建 SwiftUI App、共享 DTO/API 层和 Vapor 代理。
>
> 边界：本文完整覆盖移动管理端、API DTO、Admin API client、Status API client、本地配置存储、Vapor 代理、测试和构建部署。真实 sub2api 业务后端的数据库 schema、migration、计费、调度和任务队列未完整纳入本文；若用户要求替代真实业务后端，必须先获取并分析 `Ranshen1209/sub2api`。

## 1. 项目现状总览

迁移前系统是一个移动端管理 App，功能范围是管理员巡检用户、分组、上游账号、API Key、仪表盘趋势、服务状态和多服务器配置。Swift 目标由三部分组成：

| 目标 | Swift 实现 | 说明 |
|---|---|---|
| 移动管理端 | SwiftUI iOS/iPadOS App | 承接所有用户可见页面和交互 |
| 共享模型 | Swift Package `SakrylleShared` | DTO、Envelope、动态 JSON、格式化、URL 构造 |
| 代理服务 | Vapor executable `SakrylleServer` | 健康检查、Admin API 反向代理、API Key 聚合 |

关键运行约定：

| 类别 | 规格 |
|---|---|
| 管理认证 | Admin API 使用 `x-api-key` header，不使用 Bearer token |
| Admin 响应 | JSON envelope：`code`, `message`, `reason?`, `metadata?`, `data?` |
| URL 处理 | Base URL 可能以 `/api` 或 `/api/v1` 结尾，请求 path 也可能带同前缀，客户端必须去重 |
| 本地配置 | 多服务器 profile，存储 key 固定为 `sub2api_base_url`, `sub2api_admin_api_key`, `sub2api_accounts`, `sub2api_active_account_id` |
| 金额显示 | 不做汇率换算，所有金额显示 `￥` 前缀 |
| Dashboard | 用户详情趋势必须使用 `snapshot-v2` endpoint |
| 状态服务 | 服务状态来自 `https://status.sakrylle.com/api/status?period=...&board=hot` |
| 代理 | Vapor 代理只转发 Admin API，真实业务后端数据库不在本文范围内 |

## 2. 功能清单

| 功能 | 必须实现的行为 | API/模型 |
|---|---|---|
| 启动分流 | 配置水合完成前显示 loading；有有效服务器配置进入概览，否则进入登录 | `AdminAccountProfile` |
| 登录 | 输入服务器地址和 Admin Key，验证 settings 和 dashboard stats，成功保存 profile 并进入概览 | `AdminSettingsDTO`, `DashboardStatsDTO` |
| 服务器管理 | 添加、切换、删除多服务器 profile，刷新检测连接 | `AdminAccountProfile` |
| 概览 | 24H/7D/30D 范围，展示 Token、成本、账号健康、趋势、热点模型 | stats, trend, models, accounts |
| 用户列表 | 搜索、时间正倒序、展示 7 天用量，点击进入详情 | users, usage stats |
| 用户详情 | 基础信息、启用/禁用、用量趋势、API Key 搜索/复制、余额操作 | user, api keys, usage, snapshot-v2 |
| 创建用户 | 邮箱、密码、用户名、备注、角色、状态、余额、并发、extra JSON | `CreateUserRequestDTO` |
| 账号清单 | 搜索、状态筛选、请求量排序、今日统计、测试账号、暂停/恢复调度 | accounts, today stats |
| 创建账号 | guided 和 raw 两种表单，生成 `CreateAccountRequestDTO` | account create |
| 分组列表 | 搜索分组，展示平台、倍率、订阅类型、账号数、独占/共享 | groups |
| 服务状态 | 按 provider 分组展示可用性、延迟、timeline | status API |
| Vapor 代理 | `/healthz`, `/api/v1/keys`, `/api/v1/admin/**` | proxy DTOs |

## 3. 前端迁移设计

推荐使用 SwiftUI。主结构是 `SakrylleAdminApp -> RootView -> TabView`，Tab 包含概览、用户、状态、服务器。账号和分组可作为普通导航页面进入。状态管理使用 `ObservableObject` ViewModel，网络层使用 async/await，凭证使用 Keychain，非敏感配置使用 UserDefaults。

页面到 Swift 模块映射：

| 页面 | Swift View | ViewModel |
|---|---|---|
| 登录 | `LoginView` | `LoginViewModel` |
| 概览 | `MonitorView` | `MonitorViewModel` |
| 用户列表 | `UsersView` | `UsersViewModel` |
| 用户详情 | `UserDetailView` | `UserDetailViewModel` |
| 创建用户 | `CreateUserView` | `CreateUserViewModel` |
| 账号清单 | `AccountsView` | `AccountsViewModel` |
| 创建账号 | `CreateAccountView` | `CreateAccountViewModel` |
| 分组 | `GroupsView` | `GroupsViewModel` |
| 服务状态 | `ServiceStatusView` | `ServiceStatusViewModel` |
| 服务器 | `SettingsView` | `SettingsViewModel` |

## 4. 后端迁移设计

推荐使用 Vapor 实现代理服务。它不是完整业务后端，只负责本地或内部代理能力：

| 路由 | 行为 |
|---|---|
| `GET /healthz` | 返回代理是否配置了 upstream 和 admin key |
| `GET /api/v1/keys` | 聚合所有用户 API Key，支持分页、搜索、状态过滤 |
| `ANY /api/v1/admin/**` | 注入环境变量中的 `x-api-key` 后转发到 upstream |

代理必须支持 CORS、2MB JSON body、`Idempotency-Key` 透传、账号 credentials 递归脱敏、网络错误 502、配置错误 500。

## 5. API 合约

Admin API 统一 envelope：

```json
{ "code": 0, "message": "success", "reason": null, "metadata": null, "data": {} }
```

完整 endpoint、request、response 和 Swift DTO 在第 13 节给出。实现时以第 13 节为准。

## 6. 数据模型与持久化

移动端只持久化服务器配置，不持久化业务数据。业务数据来自 Admin API 和 Status API。真实数据库 schema 未纳入本文，不能凭本文直接实现完整替代业务后端。

本地 profile 字段：`id`, `label`, `baseUrl`, `adminApiKey`, `updatedAt`, `enabled`。

## 7. 第三方服务与环境变量

| 名称 | 用途 |
|---|---|
| `SUB2API_BASE_URL` | Vapor 代理 upstream base URL |
| `SUB2API_ADMIN_API_KEY` | Vapor 代理注入 upstream 的 `x-api-key` |
| `ALLOW_ORIGIN` | CORS origin，默认 `*` |
| `PORT` | 代理端口，默认 `8787` |
| `https://status.sakrylle.com` | 服务状态 API 默认 base URL |

## 8. 测试策略

必须补齐三类测试：

| 测试 | 覆盖 |
|---|---|
| Swift Package Tests | DTO、Envelope、URL 去重、格式化 |
| iOS Unit/UI Tests | 登录、服务器切换、页面加载、表单校验、写操作 |
| Vapor Tests | healthz、代理 header、错误映射、credentials 脱敏、keys 聚合 |

测试矩阵详见第 13.17 节。

## 9. 构建、运行与部署

目标命令：

```bash
swift package resolve
swift build
swift test
SUB2API_BASE_URL="https://example.com" SUB2API_ADMIN_API_KEY="admin-xxxx" swift run SakrylleServer serve --hostname 127.0.0.1 --port 8787
xcodebuild -project Apps/SakrylleAdmin/SakrylleAdmin.xcodeproj -scheme SakrylleAdmin -destination "platform=iOS Simulator,name=iPhone 16" test
```

Docker 和 GitHub Actions 模板见第 13.18 节。

## 10. 迁移实施计划

1. 创建 Swift package 和 `SakrylleShared`。
2. 实现 DTO、JSON 动态类型、URLBuilder、格式化。
3. 实现 `AdminAPIClient` 与 `StatusAPIClient`。
4. 实现 AppState、Keychain、UserDefaults profile 存储。
5. 实现 SwiftUI shell、登录、服务器页。
6. 实现概览、用户、用户详情、账号、创建页、分组、状态页。
7. 实现 Vapor 代理。
8. 补测试、Docker、CI、iOS 构建。

## 11. 新 Codex 会话执行指南

新会话应从第 13 节开始编码。第 1-12 节只提供摘要和取舍，第 13 节是直接实施规格。任何未被第 13 节完整定义的真实业务后端数据库、计费和调度规则，都必须先确认 `Ranshen1209/sub2api`。

## 12. 待确认事项

| 待确认项 | 影响 |
|---|---|
| 是否继续支持 Android/Web | SwiftUI 只覆盖 iOS/iPadOS |
| 是否完整替代真实 sub2api 业务后端 | 决定是否需要数据库和任务队列迁移 |
| 真实数据库 schema、索引、外键 | Fluent migration 不能凭本文直接实现 |
| API 错误码完整枚举 | 影响错误类型和测试断言 |
| 账号 credentials 加密方式 | 影响后端安全和迁移脚本 |
| UsageRecord 表和金额精度 | 影响统计聚合与 Decimal/Double 选择 |
| App Store/TestFlight 签名资料 | 影响发布流水线 |

## 13. 自包含实施规格

本节面向只拿到本文档的新 Codex 会话。新会话应优先执行本节；前 12 节提供背景和取舍，本节把实现所需的关键代码结构、数据字段、算法、页面行为和服务端代理逻辑内嵌成可直接编码的规格。

### 13.1 迁移边界的强约束

1. 本文可直接指导完整迁移的范围是：SwiftUI iOS/iPadOS 管理 App、共享 DTO/API contract、Status API client、Vapor 本地/内部代理。
2. 本文不能单独指导完整重写真实 sub2api 业务后端数据库和所有后台任务，因为原 Go 后端、数据库 schema、migration、计费/调度逻辑未被完整纳入本文。若用户要求“替代 sub2api 后端”，新会话必须先获取 sister repo `Ranshen1209/sub2api`；在此之前只能实现“API-compatible proxy backend”和“按 DTO 推导的候选 Fluent schema”。
3. 所有 Admin API 兼容目标是原移动端实际消费的 contract，不是完整 sub2api 后端 contract。
4. SwiftUI App 第一目标为 iOS/iPadOS。Android/Web 继续支持属于额外产品需求，不能由 SwiftUI 单独满足。

### 13.2 从空目录创建的最终项目树

```text
SakrylleSwift/
  Package.swift
  Sources/
    SakrylleShared/
      JSONValue.swift
      APIEnvelope.swift
      AdminDTOs.swift
      StatusDTOs.swift
      Formatters.swift
      URLBuilder.swift
    SakrylleServer/
      main.swift
      configure.swift
      routes.swift
      AppConfig.swift
      HealthController.swift
      AdminProxyController.swift
      KeysAggregationController.swift
      Sub2APIClient.swift
      CredentialRedactor.swift
      ServerErrors.swift
  Tests/
    SakrylleSharedTests/
      URLBuilderTests.swift
      DTOTests.swift
      FormatterTests.swift
    SakrylleServerTests/
      HealthTests.swift
      CredentialRedactorTests.swift
      KeysAggregationTests.swift
      AdminProxyTests.swift
  Apps/
    SakrylleAdmin/
      SakrylleAdmin.xcodeproj
      SakrylleAdmin/
        SakrylleAdminApp.swift
        AppState.swift
        RootView.swift
        AdminAPIClient.swift
        StatusAPIClient.swift
        AdminAccountStore.swift
        KeychainStore.swift
        ColorPalette.swift
        Components/
          ScreenScaffold.swift
          MetricTile.swift
          ListCard.swift
          Charts.swift
        Features/
          LoginView.swift
          MonitorView.swift
          UsersView.swift
          UserDetailView.swift
          CreateUserView.swift
          AccountsView.swift
          CreateAccountView.swift
          GroupsView.swift
          ServiceStatusView.swift
          SettingsView.swift
        Assets.xcassets
      SakrylleAdminTests/
      SakrylleAdminUITests/
  Dockerfile
  docker-compose.yml
  .github/
    workflows/
      swift-ci.yml
```

如果新会话选择把 iOS App 放在 package 外部，也必须让 App target 依赖 `SakrylleShared`，保证 DTO 单一来源。

### 13.3 `Package.swift` 完整规格

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SakrylleSwift",
    platforms: [
        .macOS(.v14),
        .iOS(.17)
    ],
    products: [
        .library(name: "SakrylleShared", targets: ["SakrylleShared"]),
        .executable(name: "SakrylleServer", targets: ["SakrylleServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.100.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(name: "SakrylleShared"),
        .executableTarget(
            name: "SakrylleServer",
            dependencies: [
                "SakrylleShared",
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(name: "SakrylleSharedTests", dependencies: ["SakrylleShared"]),
        .testTarget(name: "SakrylleServerTests", dependencies: ["SakrylleServer"])
    ]
)
```

### 13.4 共享 JSON 类型

创建 `Sources/SakrylleShared/JSONValue.swift`。必须支持动态对象、数组和 scalar；创建表单中 `credentials/extra` 只允许 scalar/null 时使用 `JSONScalar`。

```swift
public enum JSONScalar: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        throw DecodingError.typeMismatch(JSONScalar.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON scalar"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

public enum JSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([String: JSONValue])
    case array([JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        }
    }
}
```

### 13.5 共享 Admin DTO 完整字段

创建 `Sources/SakrylleShared/APIEnvelope.swift`：

```swift
public struct APIEnvelope<T: Codable & Sendable>: Codable, Sendable {
    public let code: Int
    public let message: String
    public let reason: String?
    public let metadata: [String: String]?
    public let data: T?
}

public struct EmptyResponse: Codable, Sendable, Equatable {}

public struct PaginatedData<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let total: Int
    public let page: Int
    public let pageSize: Int
    public let pages: Int

    enum CodingKeys: String, CodingKey {
        case items
        case total
        case page
        case pageSize = "page_size"
        case pages
    }
}
```

创建 `Sources/SakrylleShared/AdminDTOs.swift`：

```swift
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
}

public struct UpdateBalanceRequestDTO: Codable, Sendable, Equatable {
    public let balance: Double
    public let operation: BalanceOperation
    public let notes: String?
}

public struct UpdateUserStatusRequestDTO: Codable, Sendable, Equatable {
    public let status: String
}

public struct SetAccountSchedulableRequestDTO: Codable, Sendable, Equatable {
    public let schedulable: Bool
}
```

Required JSON strategy:

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase
```

Important exception: dynamic dictionaries (`raw`, `credentials`, `extra`) must keep their string keys exactly as supplied by server/user.

### 13.6 Status DTO 完整字段

创建 `Sources/SakrylleShared/StatusDTOs.swift`：

```swift
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
```

### 13.7 URL、日期、格式化算法

创建 `Sources/SakrylleShared/URLBuilder.swift`：

```swift
public enum URLBuilder {
    public static func buildRequestURL(baseURL: String, path: String) throws -> URL {
        var normalizedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalizedBase.hasSuffix("/") { normalizedBase.removeLast() }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        for prefix in ["/api/v1", "/api"] {
            if normalizedBase.hasSuffix(prefix), normalizedPath.hasPrefix("\(prefix)/") {
                let baseWithoutPrefix = String(normalizedBase.dropLast(prefix.count))
                guard let url = URL(string: baseWithoutPrefix + normalizedPath) else {
                    throw APIClientError.invalidURL
                }
                return url
            }
        }

        guard let url = URL(string: normalizedBase + normalizedPath) else {
            throw APIClientError.invalidURL
        }
        return url
    }
}
```

Date range algorithm:

```swift
public enum RangeKey: String, CaseIterable, Sendable {
    case h24 = "24h"
    case d7 = "7d"
    case d30 = "30d"
}

public struct DateRangeQuery: Sendable, Equatable {
    public let startDate: String
    public let endDate: String
    public let granularity: String
}

public func makeDateRange(_ key: RangeKey, now: Date = Date(), calendar: Calendar = .current) -> DateRangeQuery {
    var start = now
    let end = now

    switch key {
    case .h24:
        start = calendar.date(byAdding: .hour, value: -23, to: now) ?? now
    case .d7:
        start = calendar.date(byAdding: .day, value: -6, to: now) ?? now
    case .d30:
        start = calendar.date(byAdding: .day, value: -29, to: now) ?? now
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"

    return DateRangeQuery(
        startDate: formatter.string(from: start),
        endDate: formatter.string(from: end),
        granularity: key == .h24 ? "hour" : "day"
    )
}
```

Formatting:

```swift
public func formatCompactNumber(_ value: Double, digits: Int = 1) -> String {
    let absValue = abs(value)
    let units: [(Double, String)] = [(1_000_000_000_000, "T"), (1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")]
    for (threshold, suffix) in units where absValue >= threshold {
        var text = String(format: "%.\(digits)f", value / threshold)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text + suffix
    }
    return String(Int(value.rounded()))
}

public func formatTokenValue(_ value: Double) -> String {
    formatCompactNumber(value, digits: 1)
}

public func formatMoney(_ value: Double?) -> String {
    guard let value else { return "--" }
    return "￥" + String(format: "%.2f", value)
}
```

### 13.8 Swift API Client 完整行为

Create `Apps/SakrylleAdmin/SakrylleAdmin/AdminAPIClient.swift`:

```swift
import Foundation
import SakrylleShared

enum APIClientError: LocalizedError, Equatable {
    case baseURLRequired
    case adminAPIKeyRequired
    case invalidURL
    case invalidServerResponse
    case requestFailed(String)
    case missingData

    var errorDescription: String? {
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

struct AdminRequestOptions: Sendable {
    var idempotencyKey: String?
}

final class AdminAPIClient: Sendable {
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
            throw APIClientError.invalidServerResponse
        }
        guard (200..<300).contains(http.statusCode), envelope.code == 0 else {
            throw APIClientError.requestFailed(envelope.reason ?? envelope.message)
        }
        guard let payload = envelope.data else { throw APIClientError.missingData }
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
```

Add typed methods:

```swift
extension AdminAPIClient {
    func getDashboardStats() async throws -> DashboardStatsDTO {
        try await send("/api/v1/admin/dashboard/stats")
    }

    func getAdminSettings() async throws -> AdminSettingsDTO {
        try await send("/api/v1/admin/settings")
    }

    func getDashboardTrend(startDate: String, endDate: String, granularity: String?, accountID: Int? = nil, groupID: Int? = nil, userID: Int? = nil) async throws -> DashboardTrendDTO {
        try await send("/api/v1/admin/dashboard/trend", query: compactQuery([
            "start_date": startDate, "end_date": endDate, "granularity": granularity,
            "account_id": accountID, "group_id": groupID, "user_id": userID
        ]))
    }

    func getDashboardModels(startDate: String, endDate: String) async throws -> DashboardModelStatsDTO {
        try await send("/api/v1/admin/dashboard/models", query: compactQuery(["start_date": startDate, "end_date": endDate]))
    }

    func getDashboardSnapshot(params: [String: any CustomStringConvertible]) async throws -> DashboardSnapshotDTO {
        try await send("/api/v1/admin/dashboard/snapshot-v2", query: params.map { URLQueryItem(name: $0.key, value: "\($0.value)") })
    }

    func getUsageStats(params: [String: any CustomStringConvertible]) async throws -> UsageStatsDTO {
        try await send("/api/v1/admin/usage/stats", query: params.map { URLQueryItem(name: $0.key, value: "\($0.value)") })
    }

    func listUsers(search: String = "") async throws -> PaginatedData<AdminUserDTO> {
        try await send("/api/v1/admin/users", query: compactQuery(["page": 1, "page_size": 20, "search": search.trimmingCharacters(in: .whitespacesAndNewlines)]))
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
```

### 13.9 Status API Client 行为

```swift
final class StatusAPIClient: Sendable {
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
```

### 13.10 本地 Profile 与 Keychain 存储

Local model:

```swift
struct AdminAccountProfile: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var label: String
    var baseUrl: String
    var adminApiKey: String
    var updatedAt: String
    var enabled: Bool?
}
```

Storage keys must be exactly:

```swift
enum AdminStorageKeys {
    static let baseURL = "sub2api_base_url"
    static let adminAPIKey = "sub2api_admin_api_key"
    static let accounts = "sub2api_accounts"
    static let activeAccountID = "sub2api_active_account_id"
}
```

Algorithms:

```swift
func normalizeConfig(baseUrl: String, adminApiKey: String) -> (baseUrl: String, adminApiKey: String) {
    var base = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    while base.hasSuffix("/") { base.removeLast() }
    return (base, adminApiKey.trimmingCharacters(in: .whitespacesAndNewlines))
}

func accountLabel(for baseUrl: String) -> String {
    URL(string: baseUrl)?.host ?? baseUrl
}

func createAccountID() -> String {
    "acct_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(6).lowercased())"
}

func sortAccounts(_ accounts: [AdminAccountProfile]) -> [AdminAccountProfile] {
    accounts.sorted { $0.updatedAt > $1.updatedAt }
}

func nextActiveAccount(from accounts: [AdminAccountProfile], preferredID: String?) -> AdminAccountProfile? {
    let enabled = accounts.filter { $0.enabled != false }
    if let preferredID, let preferred = enabled.first(where: { $0.id == preferredID }) {
        return preferred
    }
    return enabled.first
}
```

Hydrate behavior:

1. Read all four keys.
2. Decode `accounts`; if missing or invalid, use empty array.
3. If accounts empty and legacy `baseURL` exists, create one profile using legacy base/key.
4. Sort profiles by `updatedAt` descending.
5. Select active profile by `activeAccountID` if enabled, else first enabled.
6. Publish `baseURL/adminAPIKey/activeAccountID/profiles`.
7. Re-persist normalized profiles and active id.

Save behavior:

1. Normalize base/key.
2. If a profile with same base/key exists, update label and `updatedAt`.
3. Else create a new profile.
4. Put it at front after sorting, set active id to it.
5. Persist base URL, admin key, accounts JSON, active id.

Switch behavior:

1. Ignore missing or disabled profile.
2. Update `updatedAt`.
3. Persist selected profile base/key and active id.

Remove behavior:

1. Remove profile.
2. Select next active profile by current active id if still present, else first enabled.
3. Persist or clear base/key/active id.

### 13.11 Color palette

Create `ColorPalette.swift`. Values must match existing design:

| Token | Light | Dark |
|---|---|---|
| primary | `#9181bd` | `#a896c8` |
| primaryDark | `#7a6aac` | `#8a78b6` |
| primarySoft | `#c8bee0` | `#3f3553` |
| page | `#f5f1fa` | `#14101c` |
| card | `#faf7fd` | `#1d1828` |
| mutedCard | `#efe9f7` | `#2a2336` |
| text | `#16181a` | `#f0ecf8` |
| textStrong | `#3a3548` | `#e6e0f3` |
| subtext | `#6f6982` | `#b1aac4` |
| mutedText | `#7a7388` | `#8c869b` |
| faintText | `#8c8499` | `#6e687f` |
| placeholder | `#9b94ad` | `#6e687f` |
| accentBg | `#e9defb` | `#322746` |
| accentText | `#5c3da3` | `#c8b4f0` |
| border | `#ddd2ed` | `#2e2840` |
| borderSoft | `#e6dfee` | `#251f33` |
| barTrack | `#e3dbef` | `#2e2840` |
| danger | `#c25d35` | `#d97a52` |
| dangerBg | `#fbf1eb` | `#3a2418` |
| warning | `#c79a45` | `#d4a85a` |
| darkButton | `#1b1d1f` | `#0c0a14` |

All views should consume palette tokens, not ad-hoc colors, except pure white text on filled primary/dark buttons.

### 13.12 UI 页面规格：Root/Login/Settings

#### Root

`SakrylleAdminApp`:

- Creates `@StateObject var appState = AppState()`.
- Injects `AdminAPIClient(baseURLProvider: { appState.baseURL }, apiKeyProvider: { appState.adminAPIKey })`.
- On launch calls `await appState.hydrate()`.
- While `hydrated == false`, show full-screen `ProgressView` on `page` background.
- If hydrated and `hasAuthenticatedAdminSession == false`, show `LoginView`.
- Else show `MainTabView`.

Session rule:

```swift
func hasAuthenticatedAdminSession(baseURL: String, adminAPIKey: String, platformIsWeb: Bool = false) -> Bool {
    guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    if platformIsWeb { return !adminAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    return true
}
```

For pure iOS, if a profile exists with empty key, the current RN code would still consider it authenticated on native. However API calls will fail with `ADMIN_API_KEY_REQUIRED`; Swift UI should guide user to Settings if key missing.

#### LoginView

Fields:

- `baseURL`: text, placeholder `https://api.sakrylle.com`
- `adminAPIKey`: secure text, placeholder `admin-xxxxxxxx`
- `showAdminKey`: toggle
- `connectionState`: idle/checking/error
- `connectionMessage`: string

Submit:

1. Validate baseURL non-empty and key non-empty.
2. Set state checking and message `正在验证服务器连接...`.
3. Save config.
4. Clear in-memory API cache.
5. Fetch settings.
6. Prefetch dashboard stats.
7. Navigate/replace to Monitor.
8. On error, map error:
   - `BASE_URL_REQUIRED` -> `请先填写服务器地址。`
   - `ADMIN_API_KEY_REQUIRED` -> `请先填写 Admin Key。`
   - `INVALID_SERVER_RESPONSE` -> `该地址返回的数据不正确，请确认它是可用的管理接口。`
   - default -> raw message.

#### SettingsView

Layout:

- Title `服务器`
- Subtitle `选择正在管理的服务器，或添加新的服务器。`
- Top-right plus button toggles add form.
- Add form fields same as Login.
- Server cards show label, baseURL, updatedAt local time, active badge `使用中`.
- Buttons: active card `已选中`, inactive `切换到此服务器`, delete `删除`.
- Empty state: `还没有服务器` and hint text.

Actions:

- Add: `saveAdminConfig`, reset form, hide form, verify settings/stats, route to Monitor.
- Select: `switchAdminAccount`, verify settings/stats, route to Monitor.
- Delete: `removeAdminAccount`, clear cache.
- Pull refresh: if baseURL exists, fetch settings/stats, else no-op.

### 13.13 UI 页面规格：Monitor

State:

```swift
@Published var rangeKey: RangeKey = .d7
@Published var stats: DashboardStatsDTO?
@Published var settings: AdminSettingsDTO?
@Published var accountsPage: PaginatedData<AdminAccountDTO>?
@Published var trend: [TrendPointDTO] = []
@Published var models: [ModelStatDTO] = []
@Published var isLoading = false
@Published var isRefreshing = false
@Published var errorMessage: String?
```

Load:

- Concurrently call stats, settings, accounts, trend, models.
- stats/settings/accounts are main loading gates.
- trend/models can keep previous data while refreshing.

Derived values:

```swift
func accountHasError(_ account: AdminAccountDTO) -> Bool {
    account.status == "error" || !(account.errorMessage ?? "").isEmpty
}

func accountIsRateLimited(_ account: AdminAccountDTO, now: Date = Date()) -> Bool {
    if case .string(let text)? = account.extra?["rate_limit_reset_at"],
       let date = ISO8601DateFormatter().date(from: text),
       date > now { return true }
    guard case .object(let modelLimits)? = account.extra?["model_rate_limits"] else { return false }
    return modelLimits.values.contains { value in
        guard case .object(let info) = value,
              case .string(let text)? = info["rate_limit_reset_at"],
              let date = ISO8601DateFormatter().date(from: text) else { return false }
        return date > now
    }
}
```

Dashboard sections:

1. Header: title `概览`, subtitle `<site_name or 管理控制台> 的运行状态。`, range segmented buttons `24H/7D/30D`, date range text.
2. If no session: card `未连接服务器`, button to Settings.
3. Loading: card `正在加载概览`.
4. Error: card `加载失败`, buttons `重试`, `检查服务器`.
5. Success:
   - Two stat cards: `<range> Token`, `<range> 成本`.
   - Account overview card: total/healthy/error/limited and button `账号清单`.
   - Line charts: Token 吞吐, 请求趋势, 成本趋势 if points > 1.
   - Bar chart: Token 结构 with input/output/cache read.
   - Donut chart: 账号健康.
   - Bar chart: 热点模型 top 5 by returned order, using `totalTokens`.
   - Trend summary latest six points reversed, each showing requests/tokens/cost.

Account counts:

- `totalAccounts = stats.totalAccounts ?? accountsPage.total ?? accounts.count`
- `errorAccounts = max(stats.errorAccounts, currentPageErrorAccounts)`
- `healthyAccounts = stats.normalAccounts ?? max(total - error, 0)`
- `busyAccounts = current page accounts with currentConcurrency > 0 and not error/limited`
- Limited and busy are only current page estimates.

### 13.14 UI 页面规格：Users and UserDetail

#### UsersView

State:

- `searchText`
- `debouncedSearchText` with 250 ms
- `sortOrder`: desc/asc
- `users`
- `usageByUserID: [Int: UsageStatsDTO]`

Load:

1. Call `listUsers(search)`.
2. Sort by `lastUsedAt || updatedAt || createdAt || id`.
3. For visible 20 users, call `getUsageStats(start/end 7d, user_id: id)` concurrently.

Card:

- Title: email.
- Subtitle: `最近使用 yyyy/MM/dd HH:mm:ss` or `时间未知`.
- Badge text: `admin · status · usernameLabel` for admin, else `status · usernameLabel`.
- `usernameLabel`: username if non-empty, else notes if non-empty, else email local part, else `未命名`.
- Metrics: 消费, 总 Token, 总请求.
- Cost priority: `total_account_cost ?? total_actual_cost ?? total_cost ?? 0`.

Actions:

- Plus button navigates to CreateUser.
- Tap user prefetches user and API keys, then pushes UserDetail.

#### UserDetailView

Inputs:

- `userID: Int`

Load concurrently:

- `getUser(userID)`
- `listUserAPIKeys(userID)`
- `getUsageStats(user_id:userID,start/end/range)`
- `getDashboardSnapshot(user_id:userID, include_stats:false, include_trend:true, include_model_stats:false, include_group_stats:false, include_users_trend:false)`

Sections:

1. 基础信息
   - email, username, balance (`￥` 2 decimals), last used.
   - Status badge.
   - Button `禁用用户` or `启用用户`.
   - Disable button if role lowercased is `admin`; show `管理员用户不支持禁用。`
   - Confirm alert before status update.
2. 总用量
   - Range buttons.
   - Metrics: 请求, Token, 成本.
   - Text: `输入 X · 输出 Y`.
   - Compact LineTrendChart for total tokens if >1 point.
3. API Keys
   - Search by name/key/group name.
   - Key card: name, copy button, group name or `未分组`, status badge, raw key text, quota used, last used.
   - Copy writes key to pasteboard; show copied state for 1.5 seconds.
4. 余额操作
   - Segmented operations: `充值` add, `扣减` subtract, `设为` set.
   - Amount default `10`, decimal pad.
   - Notes optional.
   - Validate non-empty, numeric, >= 0.
   - Submit `UpdateBalanceRequestDTO(balance: amount, operation, notes)` with idempotency key.

### 13.15 UI 页面规格：CreateUser/CreateAccount/Accounts/Groups/Status

#### CreateUserView

Fields:

| Field | Required | Default | Rule |
|---|---|---|---|
| email | yes | empty | trim non-empty |
| password | yes | empty | trim non-empty, secure |
| username | no | empty | trim or nil |
| notes | no | empty | trim or nil |
| role | yes | `user` | `user/admin` |
| status | yes | `active` | `active/disabled` |
| balance | no | empty | number if valid else nil |
| concurrency | no | empty | integer if valid else nil |
| extra JSON | no | empty | object; values scalar/null only |

On success: invalidate users cache and replace to Users tab.

#### CreateAccountView guided mode

Fields:

- name required.
- platform options: `anthropic/openai/gemini/sora/antigravity`, default anthropic.
- accountType: `apikey/oauth`, default apikey.
- notes optional.
- If apikey: baseURL required, apiKey required; credentials include `base_url`, `api_key` plus extra credentials JSON.
- If oauth: accessToken required; refreshToken/clientID optional; credentials include `access_token`, optional `refresh_token`, optional `client_id`, plus extra credentials JSON.
- advanced: concurrency, priority, rate_multiplier, proxy_id, group_ids.
- extra credentials JSON object values scalar/null only.

#### CreateAccountView raw mode

Fields:

- name required.
- platform options same as above.
- type options: `apikey/oauth/setup-token/upstream`.
- credentials JSON required and must be object scalar/null.
- extra JSON optional object scalar/null.
- notes, proxy_id, concurrency, priority, rate_multiplier, group_ids optional.

On success: invalidate accounts cache and replace to Accounts tab.

#### AccountsView

State:

- searchText debounce 300ms.
- filter: all/active/paused/error.
- usageSort: usage-desc/usage-asc.
- testingAccountID, togglingAccountID.
- testFeedbackByAccountID.
- todayByAccountID.

Visual status:

```swift
enum AccountStatusFilter { case all, active, paused, error }
func visualStatus(_ account: AdminAccountDTO) -> (filter: AccountStatusFilter, label: String, tone: BadgeTone) {
    let normalized = (account.status ?? "").lowercased()
    let paused = ["inactive", "disabled", "paused", "stop", "stopped"].contains(normalized)
    if account.status == "error" || !(account.errorMessage ?? "").isEmpty {
        return (.error, "异常", .danger)
    }
    if paused || account.schedulable == false {
        return (.paused, "暂停", .muted)
    }
    return (.active, "正常", .success)
}
```

Header:

- Search placeholder `搜索账号名称 / 平台`.
- Filter chips: `全部 N`, `正常 N`, `暂停 N`, `异常 N`.
- Sort chips: `请求高→低`, `请求低→高`.

Card:

- Title account.name.
- Meta `<platform> · <type>`.
- Badge visual status.
- Row: status and last used.
- Metric tiles: 请求次数, 消费金额 `￥`, token消耗.
- Text: `优先级 X · 倍率 Yx`.
- Groups text first 3 group names joined by ` · `.
- Error message if exists.
- Buttons: 测试, 暂停/恢复.

#### GroupsView

- Search placeholder `搜索分组名称`, debounce 300ms.
- Call `listGroups(search)`.
- Card title group.name.
- Meta: `<platform> · 倍率 <rateMultiplier ?? 1> · <subscriptionType || standard>`.
- Badge: `status || active`.
- Detail: `账号数 <accountCount ?? 0> · 独占分组/共享分组`.

#### ServiceStatusView

Functions:

```swift
func statusLabel(_ status: Int?) -> String {
    switch status { case 1: "正常"; case 2: "波动"; case 0: "异常"; default: "未知" }
}
func computeOverallStatus(_ channels: [StatusGroupDTO]) -> Int {
    if channels.contains(where: { $0.currentStatus == 0 }) { return 0 }
    if channels.contains(where: { $0.currentStatus == 2 }) { return 2 }
    return 1
}
func computeAvailability(_ timeline: [StatusTimePointDTO]) -> String {
    let valid = timeline.filter { $0.availability >= 0 }
    guard !valid.isEmpty else { return "--" }
    let avg = valid.map(\.availability).reduce(0, +) / Double(valid.count)
    return String(format: "%.1f%%", avg)
}
```

Group by provider:

- Key: `provider`.
- providerName: `providerName ?? provider`.
- counts up/degraded/down by `currentStatus`.
- Channels displayed under provider.

### 13.16 Vapor Server 完整行为

#### AppConfig

```swift
import Vapor

struct AppConfig: Sendable {
    let port: Int
    let upstreamBaseURL: String
    let adminAPIKey: String
    let allowOrigin: String

    static func load(_ env: Environment) -> AppConfig {
        var upstream = Environment.get("SUB2API_BASE_URL")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        while upstream.hasSuffix("/") { upstream.removeLast() }
        return AppConfig(
            port: Int(Environment.get("PORT") ?? "8787") ?? 8787,
            upstreamBaseURL: upstream,
            adminAPIKey: Environment.get("SUB2API_ADMIN_API_KEY")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            allowOrigin: Environment.get("ALLOW_ORIGIN")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "*"
        )
    }
}
```

#### configure.swift

```swift
import Vapor
import SakrylleShared

public func configure(_ app: Application) throws {
    let config = AppConfig.load(app.environment)
    app.storage[AppConfigKey.self] = config
    app.http.server.configuration.port = config.port

    let cors = CORSMiddleware.Configuration(
        allowedOrigin: config.allowOrigin == "*" ? .all : .custom(config.allowOrigin),
        allowedMethods: [.GET, .POST, .PUT, .PATCH, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, "Idempotency-Key", "x-api-key"],
        allowCredentials: true
    )
    app.middleware.use(CORSMiddleware(configuration: cors))
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.routes.defaultMaxBodySize = "2mb"
    try routes(app)
}

struct AppConfigKey: StorageKey {
    typealias Value = AppConfig
}
extension Application {
    var sakrylleConfig: AppConfig { storage[AppConfigKey.self]! }
}
```

#### routes.swift

```swift
import Vapor

func routes(_ app: Application) throws {
    app.get("healthz", use: HealthController().health)
    app.get("api", "v1", "keys", use: KeysAggregationController().index)
    app.on(.GET, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.POST, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.PUT, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.PATCH, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
    app.on(.DELETE, "api", "v1", "admin", "**", use: AdminProxyController().proxy)
}
```

#### Health

```swift
struct HealthResponse: Content {
    let ok: Bool
    let upstreamConfigured: Bool
    let apiKeyConfigured: Bool
}

struct HealthController {
    func health(req: Request) async throws -> HealthResponse {
        let config = req.application.sakrylleConfig
        return HealthResponse(ok: true, upstreamConfigured: !config.upstreamBaseURL.isEmpty, apiKeyConfigured: !config.adminAPIKey.isEmpty)
    }
}
```

#### Sub2APIClient

Behavior:

- `fetchAdminJSON(path:)` throws if env missing.
- GET request to `upstreamBaseURL + path`.
- Header `x-api-key` with env admin key.
- Decode `APIEnvelope<T>`.
- Require HTTP 2xx and `code == 0`.
- Return `data` or throw.

#### CredentialRedactor

Rules:

- If value is array: redact each element.
- If object: for every key, if key exactly `"credentials"`, replace value with object `{ "redacted": true }`; else recurse.
- Scalar unchanged.

Pseudo:

```swift
enum CredentialRedactor {
    static func redact(_ value: JSONValue) -> JSONValue {
        switch value {
        case .array(let items):
            return .array(items.map(redact))
        case .object(let object):
            var next: [String: JSONValue] = [:]
            for (key, entry) in object {
                if key == "credentials" {
                    next[key] = .object(["redacted": .bool(true)])
                } else {
                    next[key] = redact(entry)
                }
            }
            return .object(next)
        default:
            return value
        }
    }
}
```

#### AdminProxyController

Algorithm:

1. If upstream missing: HTTP 500 `{ code: 500, message: "SUB2API_BASE_URL_NOT_CONFIGURED" }`.
2. If admin key missing: HTTP 500 `{ code: 500, message: "SUB2API_ADMIN_API_KEY_NOT_CONFIGURED" }`.
3. Build upstream URL as `upstreamBaseURL + req.url.string`. For route `/api/v1/admin/accounts?page=1`, upstream URL must include same path and query.
4. Create `ClientRequest`.
5. Method equals incoming method.
6. Headers:
   - Set `x-api-key` env key.
   - If incoming `Content-Type` exists, copy it.
   - If incoming `Idempotency-Key` exists and non-empty, copy it with exact casing.
7. If method not GET/HEAD, body is incoming raw body. If absent, send `{}` JSON to match Express behavior.
8. Send upstream request.
9. If response content-type includes `application/json`, parse JSONValue.
10. If incoming path after `/api/v1/admin` starts with `/accounts`, redact credentials.
11. Return upstream status and content-type.
12. If non-JSON, return text/raw body.
13. On network error return HTTP 502 `{ code: 502, message: "UPSTREAM_REQUEST_FAILED", error: "<message>" }`.

#### KeysAggregationController

Implementation detail:

```swift
struct KeysQuery: Content {
    var page: Int?
    var page_size: Int?
    var search: String?
    var status: String?
}
```

Algorithm:

1. `page = max(query.page ?? 1, 1)`.
2. `pageSize = min(max(query.page_size ?? 10, 1), 100)`.
3. `search = trimLower(query.search ?? "")`.
4. `status = trim(query.status ?? "")`.
5. Fetch all users:
   - `currentPage = 1`, `totalPages = 1`.
   - Loop:
     - GET `/api/v1/admin/users?page=\(currentPage)&page_size=100`.
     - Append `items`.
     - `totalPages = response.pages`.
     - `currentPage += 1`.
6. For each user, concurrently fetch `/api/v1/admin/users/\(user.id)/api-keys?page=1&page_size=100`.
7. For every key, attach `user: { id, email, username }`.
8. If search non-empty, filter haystack `[name, key, user.email, user.username, group.name]` joined by spaces lowercased contains search.
9. If status non-empty, filter `item.status == status`.
10. Sort descending by parsed date of `updatedAt ?? lastUsedAt ?? "1970-01-01"`.
11. `total = items.count`, `start = (page - 1) * pageSize`, slice.
12. Return envelope `code:0,message:"success",data:{items,total,page,page_size,pages:max(ceil(total/pageSize),1)}`.

### 13.17 Test matrix expected by new implementation

Minimum tests that must pass:

| Test | Input | Expected |
|---|---|---|
| URL dedup api/v1 | base `https://x.com/api/v1`, path `/api/v1/admin/users` | `https://x.com/api/v1/admin/users` |
| URL dedup api | base `https://x.com/api`, path `/api/v1/admin/users` | `https://x.com/api/v1/admin/users` |
| No dedup | base `https://x.com`, path `/api/v1/admin/users` | `https://x.com/api/v1/admin/users` |
| Envelope ok | HTTP 200 `{code:0,data:{...}}` | returns data |
| Envelope business error | HTTP 200 `{code:123,message:"M",reason:"R"}` | throws `R` |
| HTTP error envelope | HTTP 500 `{code:500,message:"M"}` | throws `M` |
| Non JSON | `not json` | throws `INVALID_SERVER_RESPONSE` |
| Balance idempotency | update balance user 7 | header starts `user-balance-7-` |
| Redactor nested | `{a:{credentials:{x:1}}}` | `{a:{credentials:{redacted:true}}}` |
| Keys page clamp | page `-1`, page_size `999` | page 1, page_size 100 |
| Account visual error | status active + error_message | error/异常 |
| Account visual paused | schedulable false | paused/暂停 |
| Account visual active | status active, schedulable true | active/正常 |
| Date range 7d | now 2026-06-28 | start 2026-06-22, end 2026-06-28 |

### 13.18 Required build files

#### Dockerfile for Vapor proxy

```dockerfile
FROM swift:6.0-jammy AS build
WORKDIR /build
COPY Package.swift ./
COPY Sources ./Sources
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/.build/release/SakrylleServer /app/SakrylleServer
EXPOSE 8787
CMD ["/app/SakrylleServer", "serve", "--hostname", "0.0.0.0", "--port", "8787"]
```

#### docker-compose.yml for proxy-only local run

```yaml
services:
  sakrylle-server:
    build: .
    ports:
      - "8787:8787"
    environment:
      PORT: "8787"
      SUB2API_BASE_URL: "${SUB2API_BASE_URL}"
      SUB2API_ADMIN_API_KEY: "${SUB2API_ADMIN_API_KEY}"
      ALLOW_ORIGIN: "${ALLOW_ORIGIN:-*}"
```

#### GitHub Actions

```yaml
name: Swift CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  package:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.0"
      - run: swift test
      - run: swift build -c release

  ios:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - run: xcodebuild -project Apps/SakrylleAdmin/SakrylleAdmin.xcodeproj -scheme SakrylleAdmin -destination 'platform=iOS Simulator,name=iPhone 16' test
```

### 13.19 Definition of Done

A Swift migration implementation is complete only when:

1. `swift test` passes.
2. iOS `xcodebuild ... test` passes.
3. Vapor proxy supports `/healthz`, `/api/v1/keys`, `/api/v1/admin/*`.
4. SwiftUI App implements all visible flows: Login, Monitor, Users, UserDetail, CreateUser, Accounts, CreateAccount guided/raw, Groups, Status, Settings.
5. All API headers/body/query schemas match section 5 and section 13.
6. `x-api-key` auth, envelope parsing, baseUrl dedup, `Idempotency-Key`, money `￥`, snapshot-v2, local storage keys all match current behavior.
7. Every item in section 12 is either confirmed, explicitly scoped out, or tracked as a blocker. 

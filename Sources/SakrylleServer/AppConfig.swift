import Foundation
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

struct AppConfigKey: StorageKey {
    typealias Value = AppConfig
}

extension Application {
    var sakrylleConfig: AppConfig {
        storage[AppConfigKey.self]!
    }
}

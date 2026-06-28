import Foundation
import Security

struct AdminAccountProfile: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var label: String
    var baseUrl: String
    var adminApiKey: String
    var updatedAt: String
    var enabled: Bool?
}

enum AdminStorageKeys {
    static let baseURL = "sub2api_base_url"
    static let adminAPIKey = "sub2api_admin_api_key"
    static let accounts = "sub2api_accounts"
    static let activeAccountID = "sub2api_active_account_id"
}

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

func hasAuthenticatedAdminSession(baseURL: String, adminAPIKey: String, platformIsWeb: Bool = false) -> Bool {
    guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    if platformIsWeb { return !adminAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    return true
}

@MainActor
final class AppState: ObservableObject {
    @Published var hydrated = false
    @Published var baseURL = ""
    @Published var adminAPIKey = ""
    @Published var activeAccountID: String?
    @Published var profiles: [AdminAccountProfile] = []
    @Published var selectedTab = 0

    private let store = AdminAccountStore()

    func hydrate() async {
        let snapshot = store.hydrate()
        baseURL = snapshot.baseURL
        adminAPIKey = snapshot.adminAPIKey
        activeAccountID = snapshot.activeAccountID
        profiles = snapshot.profiles
        hydrated = true
    }

    func saveAdminConfig(baseUrl: String, adminApiKey: String) {
        let snapshot = store.save(baseUrl: baseUrl, adminApiKey: adminApiKey)
        apply(snapshot)
    }

    func switchAdminAccount(_ id: String) {
        guard let snapshot = store.switchAccount(id) else { return }
        apply(snapshot)
    }

    func removeAdminAccount(_ id: String) {
        apply(store.remove(id))
    }

    func clearCache() {}

    private func apply(_ snapshot: AdminAccountSnapshot) {
        baseURL = snapshot.baseURL
        adminAPIKey = snapshot.adminAPIKey
        activeAccountID = snapshot.activeAccountID
        profiles = snapshot.profiles
    }
}

struct AdminAccountSnapshot {
    let baseURL: String
    let adminAPIKey: String
    let activeAccountID: String?
    let profiles: [AdminAccountProfile]
}

final class AdminAccountStore {
    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = .init()) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func hydrate() -> AdminAccountSnapshot {
        let legacyBase = defaults.string(forKey: AdminStorageKeys.baseURL) ?? ""
        let legacyKey = keychain.read(AdminStorageKeys.adminAPIKey) ?? defaults.string(forKey: AdminStorageKeys.adminAPIKey) ?? ""
        let activeID = defaults.string(forKey: AdminStorageKeys.activeAccountID)
        let accounts = decodeAccounts()
        var profiles = accounts

        if profiles.isEmpty, !legacyBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalized = normalizeConfig(baseUrl: legacyBase, adminApiKey: legacyKey)
            profiles = [AdminAccountProfile(
                id: createAccountID(),
                label: accountLabel(for: normalized.baseUrl),
                baseUrl: normalized.baseUrl,
                adminApiKey: normalized.adminApiKey,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                enabled: true
            )]
        }

        profiles = sortAccounts(profiles)
        let active = nextActiveAccount(from: profiles, preferredID: activeID)
        persist(profiles: profiles, active: active)
        return snapshot(profiles: profiles, active: active)
    }

    func save(baseUrl: String, adminApiKey: String) -> AdminAccountSnapshot {
        let normalized = normalizeConfig(baseUrl: baseUrl, adminApiKey: adminApiKey)
        var profiles = decodeAccounts()
        let now = ISO8601DateFormatter().string(from: Date())
        if let index = profiles.firstIndex(where: { $0.baseUrl == normalized.baseUrl && $0.adminApiKey == normalized.adminApiKey }) {
            profiles[index].label = accountLabel(for: normalized.baseUrl)
            profiles[index].updatedAt = now
            profiles[index].enabled = true
        } else {
            profiles.append(AdminAccountProfile(
                id: createAccountID(),
                label: accountLabel(for: normalized.baseUrl),
                baseUrl: normalized.baseUrl,
                adminApiKey: normalized.adminApiKey,
                updatedAt: now,
                enabled: true
            ))
        }
        profiles = sortAccounts(profiles)
        let active = profiles.first
        persist(profiles: profiles, active: active)
        return snapshot(profiles: profiles, active: active)
    }

    func switchAccount(_ id: String) -> AdminAccountSnapshot? {
        var profiles = decodeAccounts()
        guard let index = profiles.firstIndex(where: { $0.id == id && $0.enabled != false }) else { return nil }
        profiles[index].updatedAt = ISO8601DateFormatter().string(from: Date())
        profiles = sortAccounts(profiles)
        let active = profiles.first(where: { $0.id == id })
        persist(profiles: profiles, active: active)
        return snapshot(profiles: profiles, active: active)
    }

    func remove(_ id: String) -> AdminAccountSnapshot {
        var profiles = decodeAccounts().filter { $0.id != id }
        profiles = sortAccounts(profiles)
        let active = nextActiveAccount(from: profiles, preferredID: defaults.string(forKey: AdminStorageKeys.activeAccountID))
        persist(profiles: profiles, active: active)
        return snapshot(profiles: profiles, active: active)
    }

    private func decodeAccounts() -> [AdminAccountProfile] {
        guard let data = defaults.data(forKey: AdminStorageKeys.accounts),
              let accounts = try? decoder.decode([AdminAccountProfile].self, from: data) else {
            return []
        }
        return accounts
    }

    private func persist(profiles: [AdminAccountProfile], active: AdminAccountProfile?) {
        defaults.set(try? encoder.encode(profiles), forKey: AdminStorageKeys.accounts)
        if let active {
            defaults.set(active.id, forKey: AdminStorageKeys.activeAccountID)
            defaults.set(active.baseUrl, forKey: AdminStorageKeys.baseURL)
            keychain.write(active.adminApiKey, key: AdminStorageKeys.adminAPIKey)
            defaults.removeObject(forKey: AdminStorageKeys.adminAPIKey)
        } else {
            defaults.removeObject(forKey: AdminStorageKeys.activeAccountID)
            defaults.removeObject(forKey: AdminStorageKeys.baseURL)
            defaults.removeObject(forKey: AdminStorageKeys.adminAPIKey)
            keychain.delete(AdminStorageKeys.adminAPIKey)
        }
    }

    private func snapshot(profiles: [AdminAccountProfile], active: AdminAccountProfile?) -> AdminAccountSnapshot {
        AdminAccountSnapshot(
            baseURL: active?.baseUrl ?? "",
            adminAPIKey: active?.adminApiKey ?? "",
            activeAccountID: active?.id,
            profiles: profiles
        )
    }
}

final class KeychainStore {
    private let service = "com.sakrylle.admin"

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String, key: String) {
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

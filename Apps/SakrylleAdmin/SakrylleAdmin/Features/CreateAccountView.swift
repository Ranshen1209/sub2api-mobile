import SakrylleShared
import SwiftUI

struct CreateAccountView: View {
    @Environment(\.adminAPIClient) private var client
    @Environment(\.dismiss) private var dismiss
    @State private var rawMode = false
    @State private var name = ""
    @State private var platform = "anthropic"
    @State private var accountType: AccountType = .apikey
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var accessToken = ""
    @State private var refreshToken = ""
    @State private var clientID = ""
    @State private var credentialsJSON = ""
    @State private var extraJSON = ""
    @State private var notes = ""
    @State private var proxyID = ""
    @State private var concurrency = ""
    @State private var priority = ""
    @State private var rateMultiplier = ""
    @State private var groupIDs = ""
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("创建账号") {
            ListCard {
                Toggle("Raw 模式", isOn: $rawMode)
                TextField("名称", text: $name).textFieldStyle(.roundedBorder)
                Picker("平台", selection: $platform) {
                    ForEach(["anthropic", "openai", "gemini", "sora", "antigravity"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("类型", selection: $accountType) {
                    Text("apikey").tag(AccountType.apikey)
                    Text("oauth").tag(AccountType.oauth)
                    if rawMode {
                        Text("setup-token").tag(AccountType.setupToken)
                        Text("upstream").tag(AccountType.upstream)
                    }
                }
                .pickerStyle(.segmented)

                if rawMode {
                    TextField(#"credentials JSON {"api_key":"..."}"#, text: $credentialsJSON, axis: .vertical).textFieldStyle(.roundedBorder)
                } else if accountType == .apikey {
                    TextField("base_url", text: $baseURL).textFieldStyle(.roundedBorder)
                    SecureField("api_key", text: $apiKey).textFieldStyle(.roundedBorder)
                    TextField("额外 credentials JSON", text: $credentialsJSON, axis: .vertical).textFieldStyle(.roundedBorder)
                } else {
                    SecureField("access_token", text: $accessToken).textFieldStyle(.roundedBorder)
                    TextField("refresh_token", text: $refreshToken).textFieldStyle(.roundedBorder)
                    TextField("client_id", text: $clientID).textFieldStyle(.roundedBorder)
                    TextField("额外 credentials JSON", text: $credentialsJSON, axis: .vertical).textFieldStyle(.roundedBorder)
                }

                TextField("extra JSON", text: $extraJSON, axis: .vertical).textFieldStyle(.roundedBorder)
                TextField("备注", text: $notes).textFieldStyle(.roundedBorder)
                TextField("proxy_id", text: $proxyID).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                TextField("concurrency", text: $concurrency).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                TextField("priority", text: $priority).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                TextField("rate_multiplier", text: $rateMultiplier).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                TextField("group_ids 逗号分隔", text: $groupIDs).textFieldStyle(.roundedBorder)
                if let errorText { Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger) }
                Button("创建账号") { Task { await submit() } }.buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func submit() async {
        guard let nameValue = trimNil(name) else {
            errorText = "名称不能为空。"
            return
        }
        do {
            var credentials = try parseScalarObject(credentialsJSON)
            if !rawMode {
                if accountType == .apikey {
                    guard let base = trimNil(baseURL), let key = trimNil(apiKey) else { throw APIClientError.requestFailed("baseURL 和 apiKey 必填。") }
                    credentials["base_url"] = .string(base)
                    credentials["api_key"] = .string(key)
                } else {
                    guard let token = trimNil(accessToken) else { throw APIClientError.requestFailed("accessToken 必填。") }
                    credentials["access_token"] = .string(token)
                    if let value = trimNil(refreshToken) { credentials["refresh_token"] = .string(value) }
                    if let value = trimNil(clientID) { credentials["client_id"] = .string(value) }
                }
            }
            guard !credentials.isEmpty else { throw APIClientError.requestFailed("credentials JSON 必填。") }
            let extra = try parseScalarObject(extraJSON)
            let body = CreateAccountRequestDTO(
                name: nameValue,
                platform: platform,
                type: accountType,
                credentials: credentials,
                extra: extra.isEmpty ? nil : extra,
                notes: trimNil(notes),
                proxyId: Int(proxyID),
                concurrency: Int(concurrency),
                priority: Int(priority),
                rateMultiplier: Double(rateMultiplier),
                groupIds: parseIntList(groupIDs)
            )
            _ = try await client.createAccount(body)
            dismiss()
        } catch { errorText = errorMessage(error) }
    }
}

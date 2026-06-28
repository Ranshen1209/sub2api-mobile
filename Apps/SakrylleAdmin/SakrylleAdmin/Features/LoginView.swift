import SakrylleShared
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.adminAPIClient) private var client
    @State private var baseURL = ""
    @State private var adminAPIKey = ""
    @State private var showAdminKey = false
    @State private var checking = false
    @State private var connectionMessage = ""

    var body: some View {
        ScreenScaffold("Sakrylle Admin", subtitle: "连接管理接口以开始巡检。") {
            ListCard {
                TextField("https://api.sakrylle.com", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Group {
                        if showAdminKey {
                            TextField("admin-xxxxxxxx", text: $adminAPIKey)
                        } else {
                            SecureField("admin-xxxxxxxx", text: $adminAPIKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    Toggle("", isOn: $showAdminKey)
                        .labelsHidden()
                }
                if !connectionMessage.isEmpty {
                    Text(connectionMessage)
                        .font(.footnote)
                        .foregroundStyle(checking ? ColorPalette.subtext : ColorPalette.danger)
                }
                Button(checking ? "正在验证..." : "连接服务器") {
                    Task { await submit() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(checking)
            }
        }
    }

    private func submit() async {
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionMessage = "请先填写服务器地址。"
            return
        }
        guard !adminAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionMessage = "请先填写 Admin Key。"
            return
        }
        checking = true
        connectionMessage = "正在验证服务器连接..."
        appState.saveAdminConfig(baseUrl: baseURL, adminApiKey: adminAPIKey)
        appState.clearCache()
        do {
            _ = try await client.getAdminSettings()
            _ = try await client.getDashboardStats()
            connectionMessage = ""
        } catch {
            connectionMessage = mapLoginError(error)
        }
        checking = false
    }

    private func mapLoginError(_ error: Error) -> String {
        guard let apiError = error as? APIClientError else { return error.localizedDescription }
        switch apiError.errorDescription {
        case "BASE_URL_REQUIRED": return "请先填写服务器地址。"
        case "ADMIN_API_KEY_REQUIRED": return "请先填写 Admin Key。"
        case "INVALID_SERVER_RESPONSE": return "该地址返回的数据不正确，请确认它是可用的管理接口。"
        default: return apiError.errorDescription ?? error.localizedDescription
        }
    }
}

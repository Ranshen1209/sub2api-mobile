import SakrylleShared
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.adminAPIClient) private var client
    @State private var baseURL = defaultAdminBaseURL
    @State private var adminAPIKey = ""
    @State private var showAdminKey = false
    @State private var checking = false
    @State private var connectionMessage = ""

    var body: some View {
        VStack(spacing: 22) {
            header
                .padding(.top, 72)

            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("服务器连接")
                        .font(.headline)
                        .foregroundStyle(ColorPalette.text)
                    Text("请输入管理接口地址和 Admin Key。")
                        .font(.footnote)
                        .foregroundStyle(ColorPalette.subtext)
                }
                .frame(maxWidth: .infinity)

                    VStack(spacing: 10) {
                        LoginInputRow(systemImage: "link", accessibilityLabel: "接口地址") {
                            TextField(defaultAdminBaseURL, text: $baseURL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                    }

                    LoginInputRow(systemImage: "key", accessibilityLabel: "Admin Key") {
                        HStack(spacing: 8) {
                            Group {
                                if showAdminKey {
                                    TextField("admin-xxxxxxxx", text: $adminAPIKey)
                                } else {
                                    SecureField("admin-xxxxxxxx", text: $adminAPIKey)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                            Button {
                                showAdminKey.toggle()
                            } label: {
                                Image(systemName: showAdminKey ? "eye.slash" : "eye")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(ColorPalette.mutedText)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(showAdminKey ? "隐藏 Admin Key" : "显示 Admin Key")
                        }
                    }
                }

                if !connectionMessage.isEmpty {
                    ConnectionStatusMessage(text: connectionMessage, checking: checking)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if checking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "bolt.horizontal.circle.fill")
                        }
                        Text(checking ? "正在验证..." : "连接服务器")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(checking)
            }
            .padding(18)
            .liquidGlassCard(cornerRadius: 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: 360, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fullScreenPageBackground()
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("SakrylleHomeIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .padding(8)
                .liquidGlassCard(cornerRadius: 18)

            VStack(spacing: 4) {
                Text("Sakrylle Admin")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(ColorPalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("连接管理接口，开始巡检。")
                    .font(.footnote)
                    .foregroundStyle(ColorPalette.subtext)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func submit() async {
        let resolvedBaseURL = normalizedAdminBaseURLForRequest(baseURL)
        guard !resolvedBaseURL.isEmpty else {
            connectionMessage = "请先填写服务器地址。"
            return
        }
        guard !adminAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            connectionMessage = "请先填写 Admin Key。"
            return
        }
        checking = true
        connectionMessage = "正在验证服务器连接..."
        appState.saveAdminConfig(baseUrl: resolvedBaseURL, adminApiKey: adminAPIKey)
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

struct LoginInputRow<Field: View>: View {
    let systemImage: String
    let accessibilityLabel: String
    @ViewBuilder var field: Field

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorPalette.accentText)
                .frame(width: 20)

            field
                .font(.callout)
                .foregroundStyle(ColorPalette.text)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .background(ColorPalette.mutedCard.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ColorPalette.borderSoft, lineWidth: 1)
        )
    }
}

private struct ConnectionStatusMessage: View {
    let text: String
    let checking: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: checking ? "clock" : "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .padding(.top, 2)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(checking ? ColorPalette.subtext : ColorPalette.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            checking ? ColorPalette.mutedCard.opacity(0.65) : ColorPalette.dangerBg,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

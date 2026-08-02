import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.adminAPIClient) private var client
    @State private var showingForm = false
    @State private var baseURL = ""
    @State private var adminAPIKey = ""
    @State private var message = ""
    @State private var loading = false

    var body: some View {
        ScreenScaffold("服务器", subtitle: "选择正在管理的服务器，或添加新的服务器。", iconName: "SakrylleHomeIcon") {
            HStack {
                NavigationLink { AccountsView() } label: {
                    SettingsShortcutLabel(title: "账号清单", systemImage: "server.rack")
                }
                NavigationLink { GroupsView() } label: {
                    SettingsShortcutLabel(title: "分组", systemImage: "square.stack.3d.up")
                }
                Spacer()
                Button { toggleForm() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderedProminent)
            }

            if showingForm {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("添加服务器")
                            .font(.headline)
                            .foregroundStyle(ColorPalette.text)
                        Text("填写管理接口地址和 Admin Key。")
                            .font(.footnote)
                            .foregroundStyle(ColorPalette.subtext)
                    }

                    VStack(spacing: 10) {
                        LoginInputRow(systemImage: "server.rack", accessibilityLabel: "服务器地址") {
                            TextField("服务器地址", text: $baseURL)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                        }
                        LoginInputRow(systemImage: "key", accessibilityLabel: "Admin Key") {
                            SecureField("admin-xxxxxxxx", text: $adminAPIKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }

                    Button(loading ? "正在验证..." : "添加服务器") {
                        Task { await add() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(loading)
                }
                .padding(18)
                .liquidGlassCard(cornerRadius: 22)
            }

            if !message.isEmpty {
                Text(message).font(.footnote).foregroundStyle(ColorPalette.danger)
            }

            if appState.profiles.isEmpty {
                ListCard {
                    Text("还没有服务器").font(.headline)
                    Text("添加服务器后即可开始管理。").foregroundStyle(ColorPalette.subtext)
                }
            } else {
                ForEach(appState.profiles) { profile in
                    ListCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.label).font(.headline)
                                Text(profile.baseUrl).font(.caption).foregroundStyle(ColorPalette.subtext)
                                Text(displayDate(profile.updatedAt)).font(.caption2).foregroundStyle(ColorPalette.faintText)
                            }
                            Spacer()
                            if profile.id == appState.activeAccountID {
                                Badge(text: "使用中", tone: .success)
                            }
                        }
                        HStack {
                            Button(profile.id == appState.activeAccountID ? "已选中" : "切换到此服务器") {
                                Task { await select(profile) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(profile.id == appState.activeAccountID)
                            Button("删除", role: .destructive) {
                                appState.removeAdminAccount(profile.id)
                                appState.clearCache()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .refreshable { await refresh() }
    }

    private func add() async {
        loading = true
        message = ""
        let resolvedBaseURL = normalizedAdminBaseURLForRequest(baseURL)
        guard !resolvedBaseURL.isEmpty else {
            message = "请先填写服务器地址。"
            loading = false
            return
        }
        appState.saveAdminConfig(baseUrl: resolvedBaseURL, adminApiKey: adminAPIKey)
        baseURL = ""
        adminAPIKey = ""
        showingForm = false
        await refresh()
        loading = false
    }

    private func toggleForm() {
        showingForm.toggle()
    }

    private func select(_ profile: AdminAccountProfile) async {
        appState.switchAdminAccount(profile.id)
        await refresh()
    }

    private func refresh() async {
        guard !appState.baseURL.isEmpty else { return }
        do {
            _ = try await client.getAdminSettings()
            _ = try await client.getDashboardStats()
            message = ""
        } catch {
            message = errorMessage(error)
        }
    }
}

private struct SettingsShortcutLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(ColorPalette.accentText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(ColorPalette.accentBg.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(ColorPalette.primary.opacity(0.22), lineWidth: 1))
    }
}

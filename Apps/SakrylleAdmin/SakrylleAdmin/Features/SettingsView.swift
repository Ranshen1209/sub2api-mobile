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
        ScreenScaffold("服务器", subtitle: "选择正在管理的服务器，或添加新的服务器。") {
            HStack {
                NavigationLink("账号清单") { AccountsView() }
                NavigationLink("分组") { GroupsView() }
                Spacer()
                Button { showingForm.toggle() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderedProminent)
            }

            if showingForm {
                ListCard {
                    TextField("https://api.sakrylle.com", text: $baseURL)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)
                    SecureField("admin-xxxxxxxx", text: $adminAPIKey)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)
                    Button(loading ? "正在验证..." : "添加服务器") {
                        Task { await add() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(loading)
                }
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
        appState.saveAdminConfig(baseUrl: baseURL, adminApiKey: adminAPIKey)
        baseURL = ""
        adminAPIKey = ""
        showingForm = false
        await refresh()
        loading = false
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

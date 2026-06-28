import SakrylleShared
import SwiftUI

@main
struct SakrylleAdminApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.adminAPIClient, AdminAPIClient(
                    baseURLProvider: { appState.baseURL },
                    apiKeyProvider: { appState.adminAPIKey }
                ))
                .environment(\.statusAPIClient, StatusAPIClient())
                .task {
                    await appState.hydrate()
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if !appState.hydrated {
                ZStack {
                    ColorPalette.page.ignoresSafeArea()
                    ProgressView()
                }
            } else if !hasAuthenticatedAdminSession(baseURL: appState.baseURL, adminAPIKey: appState.adminAPIKey) {
                LoginView()
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MonitorView()
                .tabItem { Label("概览", systemImage: "chart.line.uptrend.xyaxis") }
            UsersView()
                .tabItem { Label("用户", systemImage: "person.2") }
            ServiceStatusView()
                .tabItem { Label("状态", systemImage: "waveform.path.ecg") }
            SettingsView()
                .tabItem { Label("服务器", systemImage: "server.rack") }
        }
        .tint(ColorPalette.primary)
    }
}

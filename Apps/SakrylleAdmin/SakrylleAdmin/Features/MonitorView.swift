import SakrylleShared
import SwiftUI

struct MonitorView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.adminAPIClient) private var client
    @State private var rangeKey: RangeKey = .d7
    @State private var stats: DashboardStatsDTO?
    @State private var settings: AdminSettingsDTO?
    @State private var accountsPage: PaginatedData<AdminAccountDTO>?
    @State private var trend: [TrendPointDTO] = []
    @State private var models: [ModelStatDTO] = []
    @State private var isLoading = false
    @State private var errorMessageText: String?

    var body: some View {
        ScreenScaffold("概览", subtitle: "\(settings?.siteName ?? "管理控制台") 的运行状态。") {
            Picker("范围", selection: $rangeKey) {
                Text("24H").tag(RangeKey.h24)
                Text("7D").tag(RangeKey.d7)
                Text("30D").tag(RangeKey.d30)
            }
            .pickerStyle(.segmented)

            let range = makeDateRange(rangeKey)
            Text("\(range.startDate) - \(range.endDate)").font(.caption).foregroundStyle(ColorPalette.subtext)

            if appState.baseURL.isEmpty {
                ListCard {
                    Text("未连接服务器").font(.headline)
                    NavigationLink("检查服务器") { SettingsView() }
                }
            } else if isLoading {
                ListCard { Text("正在加载概览").foregroundStyle(ColorPalette.subtext) }
            } else if let errorMessageText {
                ListCard {
                    Text("加载失败").font(.headline)
                    Text(errorMessageText).font(.footnote).foregroundStyle(ColorPalette.danger)
                    HStack {
                        Button("重试") { Task { await load() } }
                        NavigationLink("检查服务器") { SettingsView() }
                    }
                }
            } else if let stats {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "\(rangeKey.rawValue) Token", value: formatTokenValue(Double(stats.todayTokens)))
                    MetricTile(title: "\(rangeKey.rawValue) 成本", value: formatMoney(stats.todayCost))
                }

                accountOverview(stats: stats)

                if trend.count > 1 {
                    ListCard {
                        Text("Token 吞吐").font(.headline)
                        LineTrendChart(points: trend.map { Double($0.totalTokens) })
                        Text("请求趋势").font(.headline)
                        LineTrendChart(points: trend.map { Double($0.requests) }, color: ColorPalette.primaryDark)
                        Text("成本趋势").font(.headline)
                        LineTrendChart(points: trend.map(\.cost), color: ColorPalette.warning)
                    }
                    ListCard {
                        Text("Token 结构").font(.headline)
                        BarChart(values: [
                            ("输入", Double(trend.map(\.inputTokens).reduce(0, +))),
                            ("输出", Double(trend.map(\.outputTokens).reduce(0, +))),
                            ("缓存", Double(trend.map(\.cacheReadTokens).reduce(0, +)))
                        ])
                    }
                }

                if !models.isEmpty {
                    ListCard {
                        Text("热点模型").font(.headline)
                        BarChart(values: models.prefix(5).map { ($0.model, Double($0.totalTokens)) })
                    }
                }

                ListCard {
                    Text("趋势摘要").font(.headline)
                    ForEach(trend.suffix(6).reversed()) { point in
                        HStack {
                            Text(point.date)
                            Spacer()
                            Text("\(point.requests) 次 · \(formatTokenValue(Double(point.totalTokens))) · \(formatMoney(point.cost))")
                                .font(.caption)
                                .foregroundStyle(ColorPalette.subtext)
                        }
                    }
                }
            }
        }
        .task(id: rangeKey) { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func accountOverview(stats: DashboardStatsDTO) -> some View {
        let accounts = accountsPage?.items ?? []
        let total = max(stats.totalAccounts, accountsPage?.total ?? accounts.count)
        let currentErrors = accounts.filter(accountHasError).count
        let errors = max(stats.errorAccounts, currentErrors)
        let healthy = max(stats.normalAccounts, total - errors)
        let limited = accounts.filter { accountIsRateLimited($0) }.count
        let busy = accounts.filter { ($0.currentConcurrency ?? 0) > 0 && !accountHasError($0) && !accountIsRateLimited($0) }.count
        ListCard {
            HStack {
                Text("账号健康").font(.headline)
                Spacer()
                NavigationLink("账号清单") { AccountsView() }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MetricTile(title: "总数", value: "\(total)")
                MetricTile(title: "健康", value: "\(healthy)")
                MetricTile(title: "异常", value: "\(errors)")
                MetricTile(title: "限流/忙碌", value: "\(limited)/\(busy)")
            }
        }
    }

    private func load() async {
        isLoading = stats == nil
        errorMessageText = nil
        do {
            let range = makeDateRange(rangeKey)
            async let statsValue = client.getDashboardStats()
            async let settingsValue = client.getAdminSettings()
            async let accountsValue = client.listAccounts()
            async let trendValue = client.getDashboardTrend(startDate: range.startDate, endDate: range.endDate, granularity: range.granularity)
            async let modelsValue = client.getDashboardModels(startDate: range.startDate, endDate: range.endDate)
            let nextStats = try await statsValue
            let nextSettings = try await settingsValue
            let nextAccounts = try await accountsValue
            let nextTrend = try await trendValue
            let nextModels = try await modelsValue
            stats = nextStats
            settings = nextSettings
            accountsPage = nextAccounts
            trend = nextTrend.trend
            models = nextModels.models
        } catch {
            errorMessageText = errorMessage(error)
        }
        isLoading = false
    }
}

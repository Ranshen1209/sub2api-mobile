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
    @State private var loadGeneration = 0

    var body: some View {
        ScreenScaffold("概览", subtitle: "\(settings?.siteName ?? "管理控制台") 的运行状态。", iconName: "SakrylleHomeIcon") {
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
                    HStack(spacing: 10) {
                        Button {
                            Task { await load() }
                        } label: {
                            Label("重试", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Label("检查服务器", systemImage: "server.rack")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            } else if let stats {
                dashboardContent(stats: stats)
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
        let errors = accounts.isEmpty ? stats.errorAccounts : currentErrors
        let healthy = accounts.isEmpty ? stats.normalAccounts : max(total - errors, 0)
        let limited = accounts.filter { accountIsRateLimited($0) }.count
        let busy = accounts.filter { ($0.currentConcurrency ?? 0) > 0 && !accountHasError($0) && !accountIsRateLimited($0) }.count
        OverviewCard {
            HStack {
                Text("账号健康").font(.headline)
                Spacer()
                NavigationLink("账号清单") { AccountsView() }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                OverviewMetricPill(title: "总数", value: "\(total)")
                OverviewMetricPill(title: "健康", value: "\(healthy)")
                OverviewMetricPill(title: "异常", value: "\(errors)")
                OverviewMetricPill(title: "限流/忙碌", value: "\(limited)/\(busy)")
            }
        }
    }

    @ViewBuilder
    private func dashboardContent(stats: DashboardStatsDTO) -> some View {
        let metrics = dashboardMetrics
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    summaryTiles
                    accountOverview(stats: stats)
                    tokenStructureSection(metrics)
                    modelsSection
                }
                .frame(minWidth: 360, maxWidth: 430, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 16) {
                    chartsSection(metrics)
                    trendSummarySection
                }
                .frame(minWidth: 520, maxWidth: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 16) {
                summaryTiles
                accountOverview(stats: stats)
                chartsSection(metrics)
                tokenStructureSection(metrics)
                modelsSection
                trendSummarySection
            }
        }
    }

    private var summaryTiles: some View {
        let rangeTotals = dashboardRangeTotals
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            OverviewMetricPill(title: "\(rangeLabel) Token", value: formatTokenValue(rangeTotals.tokens), prominent: true)
            OverviewMetricPill(title: "\(rangeLabel) 成本", value: formatMoney(rangeTotals.cost), prominent: true)
        }
    }

    @ViewBuilder
    private func chartsSection(_ metrics: DashboardMetrics) -> some View {
        if trend.count > 1 {
            OverviewCard {
                VStack(spacing: 16) {
                    trendChart(
                        title: "Token 吞吐",
                        subtitle: "总计 \(formatTokenValue(metrics.totalTokens))",
                        points: metrics.tokenChartPoints
                    )
                    trendChart(
                        title: "请求趋势",
                        subtitle: "总计 \(metrics.totalRequests) 次",
                        points: metrics.requestChartPoints,
                        color: ColorPalette.primaryDark
                    )
                    trendChart(
                        title: "成本趋势",
                        subtitle: "总计 \(formatMoney(metrics.totalCost))",
                        points: metrics.costChartPoints,
                        color: ColorPalette.warning
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func tokenStructureSection(_ metrics: DashboardMetrics) -> some View {
        if trend.count > 1 {
            OverviewCard {
                Text("Token 结构").font(.headline)
                BarChart(values: [
                    ("输入", metrics.inputTokens),
                    ("输出", metrics.outputTokens),
                    ("缓存", metrics.cacheReadTokens)
                ])
            }
        }
    }

    @ViewBuilder
    private var modelsSection: some View {
        if !models.isEmpty {
            OverviewCard {
                Text("热点模型").font(.headline)
                BarChart(values: models.prefix(5).map { ($0.model, Double($0.totalTokens)) })
            }
        }
    }

    private var trendSummarySection: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("趋势摘要").font(.headline)
                    Spacer()
                    Text("最近 6 个节点")
                        .font(.caption)
                        .foregroundStyle(ColorPalette.subtext)
                }
                VStack(spacing: 8) {
                    ForEach(trend.suffix(6).reversed()) { point in
                        TrendSummaryRow(point: point)
                    }
                }
            }
        }
    }

    private func trendChart(title: String, subtitle: String, points: [Double], color: Color = ColorPalette.primary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ColorPalette.text)
                Spacer()
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(ColorPalette.subtext)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            LineTrendChart(points: points, color: color)
        }
    }

    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
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
            guard generation == loadGeneration, !Task.isCancelled else { return }
            stats = nextStats
            settings = nextSettings
            accountsPage = nextAccounts
            trend = nextTrend.trend
            models = nextModels.models
        } catch {
            guard generation == loadGeneration, !Task.isCancelled, !isCancellationError(error) else { return }
            errorMessageText = errorMessage(error)
        }
        if generation == loadGeneration {
            isLoading = false
        }
    }

    private var dashboardRangeTotals: (tokens: Double, cost: Double?) {
        guard !trend.isEmpty else {
            return (Double(stats?.todayTokens ?? 0), stats?.todayCost)
        }
        return (
            Double(trend.map(\.totalTokens).reduce(0, +)),
            trend.map(\.cost).reduce(0, +)
        )
    }

    private var dashboardMetrics: DashboardMetrics {
        let totalTokens = Double(trend.map(\.totalTokens).reduce(0, +))
        let totalRequests = trend.map(\.requests).reduce(0, +)
        let totalCost = trend.map(\.cost).reduce(0, +)
        return DashboardMetrics(
            totalTokens: totalTokens,
            totalRequests: totalRequests,
            totalCost: totalCost,
            inputTokens: Double(trend.map(\.inputTokens).reduce(0, +)),
            outputTokens: Double(trend.map(\.outputTokens).reduce(0, +)),
            cacheReadTokens: Double(trend.map(\.cacheReadTokens).reduce(0, +)),
            tokenChartPoints: chartDisplayPoints(trend.map { Double($0.totalTokens) }),
            requestChartPoints: chartDisplayPoints(trend.map { Double($0.requests) }),
            costChartPoints: chartDisplayPoints(trend.map(\.cost))
        )
    }

    private var rangeLabel: String {
        switch rangeKey {
        case .h24: return "24H"
        case .d7: return "7D"
        case .d30: return "30D"
        }
    }
}

private struct TrendSummaryRow: View {
    let point: TrendPointDTO

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorPalette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(dateLabel)
                    .font(.caption2)
                    .foregroundStyle(ColorPalette.faintText)
                    .lineLimit(1)
            }
            .frame(width: 106, alignment: .leading)

            HStack(spacing: 6) {
                SummaryPill(text: "\(point.requests) 次")
                SummaryPill(text: formatTokenValue(Double(point.totalTokens)))
                SummaryPill(text: formatMoney(point.cost))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ColorPalette.mutedCard.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dateLabel: String {
        if point.date.count <= 10 {
            return "日汇总"
        }
        return String(point.date.prefix(10))
    }

    private var timeLabel: String {
        if point.date.count >= 16 {
            return String(point.date.dropFirst(11).prefix(5))
        }
        return String(point.date.prefix(10))
    }
}

private struct SummaryPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(ColorPalette.subtext)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(ColorPalette.card.opacity(0.64), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct OverviewCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.card.opacity(0.74), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ColorPalette.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct OverviewMetricPill: View {
    let title: String
    let value: String
    var prominent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(ColorPalette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(value)
                .font(prominent ? .title3.bold() : .headline.bold())
                .foregroundStyle(ColorPalette.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(ColorPalette.card.opacity(prominent ? 0.76 : 0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ColorPalette.borderSoft.opacity(0.72), lineWidth: 1)
        )
    }
}

private struct DashboardMetrics {
    let totalTokens: Double
    let totalRequests: Int
    let totalCost: Double
    let inputTokens: Double
    let outputTokens: Double
    let cacheReadTokens: Double
    let tokenChartPoints: [Double]
    let requestChartPoints: [Double]
    let costChartPoints: [Double]
}

import SakrylleShared
import SwiftUI

struct ProviderStatusGroup: Identifiable {
    var id: String { provider }
    let provider: String
    let providerName: String
    let up: Int
    let degraded: Int
    let down: Int
    let channels: [StatusGroupDTO]
}

struct ServiceStatusView: View {
    @Environment(\.statusAPIClient) private var client
    @State private var period: StatusPeriod = .twentyFourHours
    @State private var channels: [StatusGroupDTO] = []
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("服务状态", subtitle: "按 provider 分组展示可用性、延迟和 timeline。") {
            Picker("周期", selection: $period) {
                Text("90m").tag(StatusPeriod.ninetyMinutes)
                Text("24h").tag(StatusPeriod.twentyFourHours)
                Text("7d").tag(StatusPeriod.sevenDays)
                Text("30d").tag(StatusPeriod.thirtyDays)
            }
            .pickerStyle(.segmented)

            if let errorText { Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger) }

            ForEach(providerGroups) { item in
                ListCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.providerName).font(.headline)
                            Text("正常 \(item.up) · 波动 \(item.degraded) · 异常 \(item.down)")
                                .font(.caption)
                                .foregroundStyle(ColorPalette.subtext)
                        }
                        Spacer()
                        Badge(text: statusLabel(computeOverallStatus(item.channels)), tone: computeOverallStatus(item.channels) == 1 ? .success : .warning)
                    }
                    ForEach(item.channels) { channel in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(channel.channelName ?? channel.channel).font(.subheadline.bold())
                                Spacer()
                                Text("\(channel.layers.first?.currentStatus?.latency ?? 0)ms").font(.caption)
                            }
                            Text("可用性 \(computeAvailability(channel.layers.first?.timeline ?? [])) · \(statusLabel(channel.currentStatus))")
                                .font(.caption)
                                .foregroundStyle(ColorPalette.subtext)
                        }
                        Divider()
                    }
                }
            }
        }
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private var providerGroups: [ProviderStatusGroup] {
        let grouped = Dictionary(grouping: channels, by: \.provider)
        var result: [ProviderStatusGroup] = []
        for (provider, channels) in grouped {
            let up = channels.filter { $0.currentStatus == 1 }.count
            let degraded = channels.filter { $0.currentStatus == 2 }.count
            let down = channels.filter { $0.currentStatus == 0 }.count
            result.append(ProviderStatusGroup(
                provider: provider,
                providerName: channels.first?.providerName ?? provider,
                up: up,
                degraded: degraded,
                down: down,
                channels: channels
            ))
        }
        return result.sorted { $0.providerName < $1.providerName }
    }

    private func load() async {
        do {
            channels = try await client.getServiceStatus(period: period)
            errorText = nil
        } catch { errorText = errorMessage(error) }
    }
}

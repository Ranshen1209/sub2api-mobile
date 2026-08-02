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

private enum StatusSortMode: String, CaseIterable, Identifiable {
    case groupName
    case serviceName
    case latency
    case availability
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .groupName: return "分组名称"
        case .serviceName: return "模型类型"
        case .latency: return "延迟"
        case .availability: return "可用性"
        case .health: return "状态"
        }
    }

    var systemImage: String {
        switch self {
        case .groupName: return "rectangle.stack"
        case .serviceName: return "cpu"
        case .latency: return "timer"
        case .availability: return "percent"
        case .health: return "heart.text.square"
        }
    }
}

struct ServiceStatusView: View {
    @Environment(\.statusAPIClient) private var client
    @State private var period: StatusPeriod = .twentyFourHours
    @State private var sortMode: StatusSortMode = .groupName
    @State private var channels: [StatusGroupDTO] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusHeader
                    statusControls

                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger)
                    }

                    if isLoading && channels.isEmpty {
                        ListCard { Text("正在加载服务状态").foregroundStyle(ColorPalette.subtext) }
                    } else {
                        statusMatrix
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, 12, for: .scrollContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .fullScreenScrollEdges()
            .fullScreenPageBackground()
            .edgeToEdgeToolbarChrome()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fullScreenPageBackground()
        .task(id: period) { await load() }
        .refreshable { await load() }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image("SakrylleHomeIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .padding(7)
                    .liquidGlassCard(cornerRadius: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Sakrylle Status")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(ColorPalette.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text("服务可用性监测")
                        .font(.caption)
                        .foregroundStyle(ColorPalette.subtext)
                        .lineLimit(1)
                }
                .layoutPriority(1)
            }

            HStack(spacing: 8) {
                StatusCountPill(systemImage: "checkmark.circle", value: "\(upCount)", color: statusColor(1))
                StatusCountPill(systemImage: "exclamationmark.triangle", value: "\(downCount)", color: statusColor(0))
            }
        }
    }

    private var statusControls: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("排序", selection: $sortMode) {
                    ForEach(StatusSortMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.subheadline.weight(.semibold))
                    Text(sortMode.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ColorPalette.accentText)
            .background(
                ColorPalette.accentBg.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ColorPalette.primary.opacity(0.24), lineWidth: 1)
            )
            .accessibilityLabel("选择状态排序")

            Picker("周期", selection: $period) {
                Text("近90分钟").tag(StatusPeriod.ninetyMinutes)
                Text("近24小时").tag(StatusPeriod.twentyFourHours)
                Text("近7天").tag(StatusPeriod.sevenDays)
                Text("近30天").tag(StatusPeriod.thirtyDays)
            }
            .pickerStyle(.segmented)
        }
    }

    private var statusMatrix: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sortedChannels.enumerated()), id: \.element.id) { index, channel in
                if index > 0 {
                    Divider().overlay(ColorPalette.borderSoft.opacity(0.75))
                }
                StatusMatrixRow(channel: channel, period: period)
            }
        }
        .liquidGlassCard(cornerRadius: 18)
    }

    private var sortedChannels: [StatusGroupDTO] {
        channels.sorted { lhs, rhs in
            switch sortMode {
            case .groupName:
                return channelGroupNameKey(lhs) < channelGroupNameKey(rhs)
            case .serviceName:
                return channelServiceNameKey(lhs) < channelServiceNameKey(rhs)
            case .latency:
                let left = (currentLatency(lhs), channelGroupNameKey(lhs))
                let right = (currentLatency(rhs), channelGroupNameKey(rhs))
                return left < right
            case .availability:
                let leftAvailability = currentAvailability(lhs)
                let rightAvailability = currentAvailability(rhs)
                if leftAvailability != rightAvailability {
                    return leftAvailability > rightAvailability
                }
                return channelGroupNameKey(lhs) < channelGroupNameKey(rhs)
            case .health:
                let left = (statusSortRank(lhs.currentStatus), channelGroupNameKey(lhs))
                let right = (statusSortRank(rhs.currentStatus), channelGroupNameKey(rhs))
                return left < right
            }
        }
    }

    private var upCount: Int {
        channels.filter { $0.currentStatus == 1 }.count
    }

    private var downCount: Int {
        channels.filter { $0.currentStatus == 0 }.count
    }

    private func load() async {
        isLoading = channels.isEmpty
        do {
            channels = try await client.getServiceStatus(period: period)
            errorText = nil
        } catch { errorText = errorMessage(error) }
        isLoading = false
    }

    private func channelGroupNameKey(_ channel: StatusGroupDTO) -> String {
        [
            channel.channelName ?? channel.channel,
            channel.providerName ?? channel.provider,
            channel.serviceName ?? channel.service
        ].joined(separator: "\u{001F}")
    }

    private func channelServiceNameKey(_ channel: StatusGroupDTO) -> String {
        [
            channel.serviceName ?? channel.service,
            channel.providerName ?? channel.provider,
            channel.channelName ?? channel.channel
        ].joined(separator: "\u{001F}")
    }

    private func currentLatency(_ channel: StatusGroupDTO) -> Int {
        channel.layers.first?.currentStatus?.latency ?? Int.max
    }

    private func currentAvailability(_ channel: StatusGroupDTO) -> Double {
        let value = computeAvailabilityValue(Array((channel.layers.first?.timeline ?? []).suffix(period.timelineLimit)))
        return value ?? -1
    }

    private func statusSortRank(_ status: Int?) -> Int {
        switch status {
        case 0: return 0
        case 2: return 1
        case 1: return 2
        default: return 3
        }
    }
}

private struct StatusMatrixRow: View {
    let channel: StatusGroupDTO
    let period: StatusPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(groupName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ColorPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(detailName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ColorPalette.accentText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: 180, alignment: .leading)

                Text(computeAvailability(timeline))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(statusColor(channel.currentStatus))
                    .lineLimit(1)
                    .frame(width: 68, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor(channel.currentStatus))
                            .frame(width: 8, height: 8)
                        Text(latencyText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Text(lastTime)
                        .foregroundStyle(ColorPalette.faintText)
                        .lineLimit(1)
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(ColorPalette.subtext)
                .frame(width: 88, alignment: .leading)
            }

            StatusTimelineBlocks(points: timeline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var timeline: [StatusTimePointDTO] {
        Array((channel.layers.first?.timeline ?? []).suffix(period.timelineLimit))
    }

    private var groupName: String {
        channel.channelName ?? channel.channel
    }

    private var detailName: String {
        let service = channel.serviceName ?? channel.service
        let provider = channel.providerName ?? channel.provider
        guard service != provider else { return service }
        return "\(service) · \(provider)"
    }

    private var latencyText: String {
        String(format: "%dms", channel.layers.first?.currentStatus?.latency ?? 0)
    }

    private var lastTime: String {
        guard let text = timeline.last?.time, text.count >= 5 else { return "--:--" }
        return String(text.suffix(5))
    }
}

private struct StatusTimelineBlocks: View {
    let points: [StatusTimePointDTO]

    var body: some View {
        HStack(spacing: 4) {
            let blocks = points.isEmpty ? placeholderPoints : points
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, point in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(statusColor(point.status))
                    .frame(maxWidth: .infinity)
                    .frame(height: 18)
            }
        }
    }

    private var placeholderPoints: [StatusTimePointDTO] {
        []
    }
}

private struct ServiceTag: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundStyle(ColorPalette.accentText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ColorPalette.accentBg.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(ColorPalette.primary.opacity(0.24), lineWidth: 1)
            )
    }
}

private struct StatusCountPill: View {
    let systemImage: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(value)
                .monospacedDigit()
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(ColorPalette.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.24), lineWidth: 1)
        )
    }
}

private func statusColor(_ status: Int) -> Color {
    switch status {
    case 1: return Color(red: 0.31, green: 0.60, blue: 0.40)
    case 2: return ColorPalette.warning
    case 0: return Color(red: 0.91, green: 0.33, blue: 0.39)
    default: return ColorPalette.faintText
    }
}

private extension StatusPeriod {
    var title: String {
        switch self {
        case .ninetyMinutes: return "近90分钟"
        case .twentyFourHours: return "近24小时"
        case .sevenDays: return "近7天"
        case .thirtyDays: return "近30天"
        }
    }

    var timelineLimit: Int {
        switch self {
        case .ninetyMinutes: return 30
        case .twentyFourHours: return 24
        case .sevenDays: return 14
        case .thirtyDays: return 30
        }
    }
}

import SakrylleShared
import SwiftUI
import UIKit

struct UserDetailView: View {
    let userID: Int
    @Environment(\.adminAPIClient) private var client
    @State private var user: AdminUserDTO?
    @State private var keys: [AdminAPIKeyDTO] = []
    @State private var usage: UsageStatsDTO?
    @State private var snapshot: DashboardSnapshotDTO?
    @State private var rangeKey: RangeKey = .d7
    @State private var searchText = ""
    @State private var copiedKeyID: Int?
    @State private var amount = "10"
    @State private var notes = ""
    @State private var operation: BalanceOperation = .add
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("用户详情", subtitle: user?.email) {
            if let user {
                ListCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.email).font(.headline)
                            Text(user.username ?? "未命名").foregroundStyle(ColorPalette.subtext)
                            Text("余额 \(formatMoney(user.balance)) · 最近使用 \(displayDate(user.lastUsedAt))").font(.caption)
                        }
                        Spacer()
                        Badge(text: user.status ?? "unknown", tone: user.status == "active" ? .success : .muted)
                    }
                    if user.role?.lowercased() == "admin" {
                        Text("管理员用户不支持禁用。").font(.caption).foregroundStyle(ColorPalette.warning)
                    } else {
                        Button(user.status == "disabled" ? "启用用户" : "禁用用户") {
                            Task { await updateStatus(user.status == "disabled" ? "active" : "disabled") }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                ListCard {
                    Picker("范围", selection: $rangeKey) {
                        Text("24H").tag(RangeKey.h24)
                        Text("7D").tag(RangeKey.d7)
                        Text("30D").tag(RangeKey.d30)
                    }
                    .pickerStyle(.segmented)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                        MetricTile(title: "请求", value: "\(usage?.totalRequests ?? 0)")
                        MetricTile(title: "Token", value: formatTokenValue(Double(usage?.totalTokens ?? 0)))
                        MetricTile(title: "成本", value: formatMoney(usage?.totalAccountCost ?? usage?.totalActualCost ?? usage?.totalCost))
                    }
                    Text("输入 \(formatTokenValue(Double(usage?.totalInputTokens ?? 0))) · 输出 \(formatTokenValue(Double(usage?.totalOutputTokens ?? 0)))")
                        .font(.caption)
                        .foregroundStyle(ColorPalette.subtext)
                    if let points = snapshot?.trend, points.count > 1 {
                        LineTrendChart(points: points.map { Double($0.totalTokens) })
                    }
                }

                ListCard {
                    Text("API Keys").font(.headline)
                    TextField("搜索 name/key/group", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    ForEach(filteredKeys) { key in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(key.name).font(.subheadline.bold())
                                Spacer()
                                Button(copiedKeyID == key.id ? "已复制" : "复制") { copy(key) }
                            }
                            Text(key.group?.name ?? "未分组").font(.caption).foregroundStyle(ColorPalette.subtext)
                            Text(key.key).font(.caption2).foregroundStyle(ColorPalette.faintText)
                            Text("已用 \(formatMoney(key.quotaUsed)) · 最近 \(displayDate(key.lastUsedAt))").font(.caption)
                            Badge(text: key.status, tone: key.status == "active" ? .success : .muted)
                        }
                        Divider()
                    }
                }

                ListCard {
                    Text("余额操作").font(.headline)
                    Picker("操作", selection: $operation) {
                        Text("充值").tag(BalanceOperation.add)
                        Text("扣减").tag(BalanceOperation.subtract)
                        Text("设为").tag(BalanceOperation.set)
                    }
                    .pickerStyle(.segmented)
                    TextField("10", text: $amount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("备注", text: $notes)
                        .textFieldStyle(.roundedBorder)
                    Button("提交余额变更") { Task { await submitBalance() } }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger)
            }
        }
        .task(id: rangeKey) { await load() }
        .refreshable { await load() }
    }

    private var filteredKeys: [AdminAPIKeyDTO] {
        let needle = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return keys }
        return keys.filter { [$0.name, $0.key, $0.group?.name].compactMap { $0 }.joined(separator: " ").lowercased().contains(needle) }
    }

    private func load() async {
        do {
            let range = makeDateRange(rangeKey)
            async let userValue = client.getUser(userID)
            async let keysValue = client.listUserAPIKeys(userID: userID)
            async let usageValue = client.getUsageStats(params: ["user_id": userID, "start_date": range.startDate, "end_date": range.endDate, "range": rangeKey.rawValue])
            async let snapshotValue = client.getDashboardSnapshot(params: ["user_id": userID, "include_stats": false, "include_trend": true, "include_model_stats": false, "include_group_stats": false, "include_users_trend": false])
            let nextUser = try await userValue
            let nextKeys = try await keysValue
            let nextUsage = try await usageValue
            let nextSnapshot = try await snapshotValue
            user = nextUser
            keys = nextKeys.items
            usage = nextUsage
            snapshot = nextSnapshot
            errorText = nil
        } catch {
            errorText = errorMessage(error)
        }
    }

    private func updateStatus(_ status: String) async {
        do {
            user = try await client.updateUserStatus(userID: userID, status: status)
        } catch { errorText = errorMessage(error) }
    }

    private func submitBalance() async {
        guard let value = Double(amount), value >= 0 else {
            errorText = "请输入有效金额。"
            return
        }
        do {
            user = try await client.updateUserBalance(userID: userID, request: UpdateBalanceRequestDTO(balance: value, operation: operation, notes: trimNil(notes)))
            errorText = nil
        } catch { errorText = errorMessage(error) }
    }

    private func copy(_ key: AdminAPIKeyDTO) {
        UIPasteboard.general.string = key.key
        copiedKeyID = key.id
        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copiedKeyID = nil }
    }
}

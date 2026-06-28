import SakrylleShared
import SwiftUI

enum UserSortOrder: String, CaseIterable {
    case desc
    case asc
}

struct UsersView: View {
    @Environment(\.adminAPIClient) private var client
    @State private var searchText = ""
    @State private var sortOrder: UserSortOrder = .desc
    @State private var users: [AdminUserDTO] = []
    @State private var usageByUserID: [Int: UsageStatsDTO] = [:]
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("用户", subtitle: "搜索用户、查看 7 天用量并进入详情。") {
            HStack {
                TextField("搜索邮箱 / 用户名", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Picker("排序", selection: $sortOrder) {
                    Text("新到旧").tag(UserSortOrder.desc)
                    Text("旧到新").tag(UserSortOrder.asc)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                NavigationLink { CreateUserView() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderedProminent)
            }

            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger)
            }

            ForEach(sortedUsers) { user in
                NavigationLink { UserDetailView(userID: user.id) } label: {
                    userCard(user)
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await load()
        }
        .task(id: sortOrder) { await load() }
        .refreshable { await load() }
    }

    private var sortedUsers: [AdminUserDTO] {
        users.sorted {
            let left = $0.lastUsedAt ?? $0.updatedAt ?? $0.createdAt ?? "\($0.id)"
            let right = $1.lastUsedAt ?? $1.updatedAt ?? $1.createdAt ?? "\($1.id)"
            return sortOrder == .desc ? left > right : left < right
        }
    }

    private func userCard(_ user: AdminUserDTO) -> some View {
        let usage = usageByUserID[user.id]
        let name = trimNil(user.username ?? "") ?? trimNil(user.notes ?? "") ?? user.email.split(separator: "@").first.map(String.init) ?? "未命名"
        let badge = [user.role?.lowercased() == "admin" ? "admin" : nil, user.status, name].compactMap { $0 }.joined(separator: " · ")
        return ListCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.email).font(.headline).foregroundStyle(ColorPalette.text)
                    Text("最近使用 \(displayDate(user.lastUsedAt))").font(.caption).foregroundStyle(ColorPalette.subtext)
                    Text(badge).font(.caption2).foregroundStyle(ColorPalette.faintText)
                }
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                MetricTile(title: "消费", value: formatMoney(usage?.totalAccountCost ?? usage?.totalActualCost ?? usage?.totalCost ?? 0))
                MetricTile(title: "总 Token", value: formatTokenValue(Double(usage?.totalTokens ?? 0)))
                MetricTile(title: "总请求", value: "\(usage?.totalRequests ?? 0)")
            }
        }
    }

    private func load() async {
        do {
            let page = try await client.listUsers(search: searchText)
            users = page.items
            let range = makeDateRange(.d7)
            try await withThrowingTaskGroup(of: (Int, UsageStatsDTO).self) { group in
                for user in page.items.prefix(20) {
                    group.addTask {
                        let usage = try await client.getUsageStats(params: ["start_date": range.startDate, "end_date": range.endDate, "user_id": user.id])
                        return (user.id, usage)
                    }
                }
                var next: [Int: UsageStatsDTO] = [:]
                for try await item in group { next[item.0] = item.1 }
                usageByUserID = next
            }
            errorText = nil
        } catch {
            errorText = errorMessage(error)
        }
    }
}

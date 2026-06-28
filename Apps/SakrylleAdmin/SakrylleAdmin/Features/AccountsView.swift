import SakrylleShared
import SwiftUI

enum UsageSort: String, CaseIterable {
    case desc
    case asc
}

struct AccountsView: View {
    @Environment(\.adminAPIClient) private var client
    @State private var searchText = ""
    @State private var filter: AccountStatusFilter = .all
    @State private var usageSort: UsageSort = .desc
    @State private var accounts: [AdminAccountDTO] = []
    @State private var todayByAccountID: [Int: AccountTodayStatsDTO] = [:]
    @State private var feedback: [Int: String] = [:]
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("账号清单", subtitle: "搜索、筛选、测试并暂停或恢复账号。") {
            HStack {
                TextField("搜索账号名称 / 平台", text: $searchText).textFieldStyle(.roundedBorder)
                NavigationLink { CreateAccountView() } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderedProminent)
            }
            Picker("筛选", selection: $filter) {
                Text("全部 \(accounts.count)").tag(AccountStatusFilter.all)
                Text("正常 \(count(.active))").tag(AccountStatusFilter.active)
                Text("暂停 \(count(.paused))").tag(AccountStatusFilter.paused)
                Text("异常 \(count(.error))").tag(AccountStatusFilter.error)
            }
            .pickerStyle(.segmented)
            Picker("排序", selection: $usageSort) {
                Text("请求高→低").tag(UsageSort.desc)
                Text("请求低→高").tag(UsageSort.asc)
            }
            .pickerStyle(.segmented)

            if let errorText { Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger) }
            ForEach(filteredAccounts) { account in
                accountCard(account)
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await load()
        }
        .task(id: filter) { await load() }
        .task(id: usageSort) { await load() }
        .refreshable { await load() }
    }

    private var filteredAccounts: [AdminAccountDTO] {
        accounts
            .filter { filter == .all || visualStatus($0).filter == filter }
            .sorted {
                let left = todayByAccountID[$0.id]?.requests ?? 0
                let right = todayByAccountID[$1.id]?.requests ?? 0
                return usageSort == .desc ? left > right : left < right
            }
    }

    private func count(_ value: AccountStatusFilter) -> Int {
        accounts.filter { visualStatus($0).filter == value }.count
    }

    private func accountCard(_ account: AdminAccountDTO) -> some View {
        let status = visualStatus(account)
        let today = todayByAccountID[account.id]
        return ListCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name).font(.headline)
                    Text("\(account.platform) · \(account.type)").font(.caption).foregroundStyle(ColorPalette.subtext)
                }
                Spacer()
                Badge(text: status.label, tone: status.tone)
            }
            Text("\(account.status ?? "unknown") · 最近 \(displayDate(account.lastUsedAt))").font(.caption)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                MetricTile(title: "请求次数", value: "\(today?.requests ?? 0)")
                MetricTile(title: "消费金额", value: formatMoney(today?.cost ?? 0))
                MetricTile(title: "token消耗", value: formatTokenValue(Double(today?.tokens ?? 0)))
            }
            Text("优先级 \(account.priority ?? 0) · 倍率 \(String(format: "%.2f", account.rateMultiplier ?? 1))x").font(.caption)
            if let groups = account.groups, !groups.isEmpty {
                Text(groups.prefix(3).map(\.name).joined(separator: " · ")).font(.caption).foregroundStyle(ColorPalette.subtext)
            }
            if let error = account.errorMessage, !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(ColorPalette.danger)
            }
            if let feedback = feedback[account.id] {
                Text(feedback).font(.caption).foregroundStyle(ColorPalette.subtext)
            }
            HStack {
                Button("测试") { Task { await test(account) } }.buttonStyle(.bordered)
                Button(account.schedulable == false ? "恢复" : "暂停") {
                    Task { await toggle(account) }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func load() async {
        do {
            let page = try await client.listAccounts(search: searchText)
            accounts = page.items
            try await withThrowingTaskGroup(of: (Int, AccountTodayStatsDTO).self) { group in
                for account in page.items {
                    group.addTask { (account.id, try await client.getAccountTodayStats(accountID: account.id)) }
                }
                var next: [Int: AccountTodayStatsDTO] = [:]
                for try await item in group { next[item.0] = item.1 }
                todayByAccountID = next
            }
            errorText = nil
        } catch { errorText = errorMessage(error) }
    }

    private func test(_ account: AdminAccountDTO) async {
        do {
            _ = try await client.testAccount(accountID: account.id)
            feedback[account.id] = "测试完成"
        } catch { feedback[account.id] = errorMessage(error) }
    }

    private func toggle(_ account: AdminAccountDTO) async {
        do {
            _ = try await client.setAccountSchedulable(accountID: account.id, schedulable: account.schedulable == false)
            await load()
        } catch { feedback[account.id] = errorMessage(error) }
    }
}

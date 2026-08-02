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
    @State private var pageData: PaginatedData<AdminUserDTO>?
    @State private var currentPage = 1
    @State private var usageByUserID: [Int: UsageStatsDTO] = [:]
    @State private var isLoading = false
    @State private var errorText: String?
    private let pageSize = 20
    private let userColumns = [GridItem(.adaptive(minimum: 480), spacing: 12, alignment: .top)]

    var body: some View {
        ScreenScaffold("用户", subtitle: "搜索用户、查看 7 天用量并进入详情。", iconName: "SakrylleHomeIcon") {
            HStack(spacing: 10) {
                StyledSearchField(text: $searchText, placeholder: "搜索邮箱 / 用户名")
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

            if isLoading && users.isEmpty {
                ListCard { Text("正在加载用户").foregroundStyle(ColorPalette.subtext) }
            }

            if let pageData, pageData.total > pageSize {
                paginationControls(pageData)
            }

            LazyVGrid(columns: userColumns, alignment: .leading, spacing: 12) {
                ForEach(users) { user in
                    NavigationLink { UserDetailView(userID: user.id) } label: {
                        userCard(user)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let pageData, pageData.total > pageSize {
                paginationControls(pageData)
            }
        }
        .task(id: searchText) {
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            currentPage = 1
            await load(page: 1)
        }
        .task(id: sortOrder) {
            currentPage = 1
            await load(page: 1)
        }
        .refreshable { await load(page: currentPage) }
    }

    private func userCard(_ user: AdminUserDTO) -> some View {
        let usage = usageByUserID[user.id]
        let name = trimNil(user.username ?? "") ?? trimNil(user.notes ?? "") ?? user.email.split(separator: "@").first.map(String.init) ?? "未命名"
        let badge = [user.role?.lowercased() == "admin" ? "admin" : nil, user.status, name].compactMap { $0 }.joined(separator: " · ")
        return UserListCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.email).font(.headline).foregroundStyle(ColorPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("最近使用 \(displayDate(user.lastUsedAt))").font(.caption).foregroundStyle(ColorPalette.subtext)
                    Text(badge).font(.caption2).foregroundStyle(ColorPalette.faintText)
                        .lineLimit(1)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                UserMetricPill(title: "消费", value: formatMoney(usage?.totalAccountCost ?? usage?.totalActualCost ?? usage?.totalCost ?? 0))
                UserMetricPill(title: "Token", value: formatTokenValue(Double(usage?.totalTokens ?? 0)))
                UserMetricPill(title: "请求", value: "\(usage?.totalRequests ?? 0)")
            }
        }
    }

    private func paginationControls(_ pageData: PaginatedData<AdminUserDTO>) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { await goToPage(currentPage - 1) }
            } label: {
                Label("上一页", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(isLoading || currentPage <= 1)

            Spacer()

            VStack(spacing: 2) {
                Text("第 \(pageData.page) / \(max(pageData.pages, 1)) 页")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ColorPalette.text)
                Text("共 \(pageData.total) 个用户")
                    .font(.caption2)
                    .foregroundStyle(ColorPalette.subtext)
            }

            Spacer()

            Button {
                Task { await goToPage(currentPage + 1) }
            } label: {
                Label("下一页", systemImage: "chevron.right")
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered)
            .disabled(isLoading || currentPage >= pageData.pages)
        }
        .padding(.horizontal, 4)
    }

    private func goToPage(_ page: Int) async {
        let nextPage = max(page, 1)
        currentPage = nextPage
        await load(page: nextPage)
    }

    private func load(page: Int) async {
        isLoading = true
        do {
            let page = try await client.listUsers(search: searchText, page: page, pageSize: pageSize, sortOrder: sortOrder.rawValue)
            currentPage = page.page
            pageData = page
            users = page.items
            let range = makeDateRange(.d7)
            try await withThrowingTaskGroup(of: (Int, UsageStatsDTO).self) { group in
                for user in page.items {
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
            guard !Task.isCancelled, !isCancellationError(error) else {
                isLoading = false
                return
            }
            errorText = errorMessage(error)
        }
        isLoading = false
    }
}

private struct UserListCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorPalette.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ColorPalette.borderSoft.opacity(0.82), lineWidth: 1)
        )
    }
}

private struct UserMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(ColorPalette.mutedText)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ColorPalette.textStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(ColorPalette.mutedCard.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

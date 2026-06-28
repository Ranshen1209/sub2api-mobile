import SakrylleShared
import SwiftUI

struct GroupsView: View {
    @Environment(\.adminAPIClient) private var client
    @State private var searchText = ""
    @State private var groups: [AdminGroupDTO] = []
    @State private var errorText: String?

    var body: some View {
        ScreenScaffold("分组", subtitle: "搜索分组并查看平台、倍率和账号数。") {
            TextField("搜索分组名称", text: $searchText)
                .textFieldStyle(.roundedBorder)
            if let errorText { Text(errorText).font(.footnote).foregroundStyle(ColorPalette.danger) }
            ForEach(groups) { group in
                ListCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name).font(.headline)
                            Text("\(group.platform) · 倍率 \(String(format: "%.2f", group.rateMultiplier ?? 1)) · \(group.subscriptionType ?? "standard")")
                                .font(.caption)
                                .foregroundStyle(ColorPalette.subtext)
                            Text("账号数 \(group.accountCount ?? 0) · \((group.isExclusive ?? false) ? "独占分组" : "共享分组")")
                                .font(.caption)
                                .foregroundStyle(ColorPalette.faintText)
                        }
                        Spacer()
                        Badge(text: group.status ?? "active", tone: group.status == "disabled" ? .muted : .success)
                    }
                }
            }
        }
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await load()
        }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            let page = try await client.listGroups(search: searchText)
            groups = page.items
            errorText = nil
        } catch { errorText = errorMessage(error) }
    }
}

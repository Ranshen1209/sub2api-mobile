import Foundation
import SakrylleShared
import Vapor

struct KeysQuery: Content {
    var page: Int?
    var page_size: Int?
    var search: String?
    var status: String?
}

struct KeysAggregationController {
    func index(req: Request) async throws -> Response {
        let query = try req.query.decode(KeysQuery.self)
        let page = max(query.page ?? 1, 1)
        let pageSize = min(max(query.page_size ?? 10, 1), 100)
        let search = (query.search ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let status = (query.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let client = Sub2APIClient(req: req)
        var users: [AdminUserDTO] = []
        var currentPage = 1
        var totalPages = 1
        repeat {
            let pageData: PaginatedData<AdminUserDTO> = try await client.fetchAdminJSON(path: "/api/v1/admin/users?page=\(currentPage)&page_size=100")
            users.append(contentsOf: pageData.items)
            totalPages = pageData.pages
            currentPage += 1
        } while currentPage <= totalPages

        let keys = try await withThrowingTaskGroup(of: [AdminAPIKeyDTO].self) { group in
            for user in users {
                group.addTask {
                    let keyPage: PaginatedData<AdminAPIKeyDTO> = try await client.fetchAdminJSON(path: "/api/v1/admin/users/\(user.id)/api-keys?page=1&page_size=100")
                    return keyPage.items.map { key in key.withUser(user) }
                }
            }

            var collected: [AdminAPIKeyDTO] = []
            for try await pageKeys in group {
                collected.append(contentsOf: pageKeys)
            }
            return collected
        }

        let filtered = keys
            .filter { key in
                guard !search.isEmpty else { return true }
                let haystack = [
                    key.name,
                    key.key,
                    key.user?.email,
                    key.user?.username,
                    key.group?.name
                ].compactMap { $0 }.joined(separator: " ").lowercased()
                return haystack.contains(search)
            }
            .filter { key in
                status.isEmpty || key.status == status
            }
            .sorted { lhs, rhs in
                parseDate(lhs.updatedAt ?? lhs.lastUsedAt ?? "1970-01-01") > parseDate(rhs.updatedAt ?? rhs.lastUsedAt ?? "1970-01-01")
            }

        let total = filtered.count
        let start = (page - 1) * pageSize
        let items = start < total ? Array(filtered[start..<min(start + pageSize, total)]) : []
        let pages = max(Int(ceil(Double(total) / Double(pageSize))), 1)
        let data = PaginatedData(items: items, total: total, page: page, pageSize: pageSize, pages: pages)
        return try jsonResponse(APIEnvelope(code: 0, message: "success", data: data))
    }

    private func parseDate(_ text: String) -> Date {
        if let date = ISO8601DateFormatter().date(from: text) {
            return date
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: text) ?? Date(timeIntervalSince1970: 0)
    }
}

private extension AdminAPIKeyDTO {
    func withUser(_ user: AdminUserDTO) -> AdminAPIKeyDTO {
        AdminAPIKeyDTO(
            id: id,
            userId: userId,
            key: key,
            name: name,
            groupId: groupId,
            status: status,
            quota: quota,
            quotaUsed: quotaUsed,
            lastUsedAt: lastUsedAt,
            expiresAt: expiresAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            usage5h: usage5h,
            usage1d: usage1d,
            usage7d: usage7d,
            group: group,
            user: AdminAPIKeyUserDTO(id: user.id, email: user.email, username: user.username)
        )
    }
}

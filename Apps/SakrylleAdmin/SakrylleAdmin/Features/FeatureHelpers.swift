import Foundation
import SakrylleShared
import SwiftUI

enum AccountStatusFilter: String, CaseIterable {
    case all
    case active
    case paused
    case error
}

func accountHasError(_ account: AdminAccountDTO) -> Bool {
    account.status == "error" || !(account.errorMessage ?? "").isEmpty
}

func accountIsRateLimited(_ account: AdminAccountDTO, now: Date = Date()) -> Bool {
    if case .string(let text)? = account.extra?["rate_limit_reset_at"],
       let date = ISO8601DateFormatter().date(from: text),
       date > now { return true }
    guard case .object(let modelLimits)? = account.extra?["model_rate_limits"] else { return false }
    return modelLimits.values.contains { value in
        guard case .object(let info) = value,
              case .string(let text)? = info["rate_limit_reset_at"],
              let date = ISO8601DateFormatter().date(from: text) else { return false }
        return date > now
    }
}

func visualStatus(_ account: AdminAccountDTO) -> (filter: AccountStatusFilter, label: String, tone: BadgeTone) {
    let normalized = (account.status ?? "").lowercased()
    let paused = ["inactive", "disabled", "paused", "stop", "stopped"].contains(normalized)
    if account.status == "error" || !(account.errorMessage ?? "").isEmpty {
        return (.error, "异常", .danger)
    }
    if paused || account.schedulable == false {
        return (.paused, "暂停", .muted)
    }
    return (.active, "正常", .success)
}

func statusLabel(_ status: Int?) -> String {
    switch status {
    case 1: return "正常"
    case 2: return "波动"
    case 0: return "异常"
    default: return "未知"
    }
}

func computeOverallStatus(_ channels: [StatusGroupDTO]) -> Int {
    if channels.contains(where: { $0.currentStatus == 0 }) { return 0 }
    if channels.contains(where: { $0.currentStatus == 2 }) { return 2 }
    return 1
}

func computeAvailability(_ timeline: [StatusTimePointDTO]) -> String {
    let valid = timeline.filter { $0.availability >= 0 }
    guard !valid.isEmpty else { return "--" }
    let avg = valid.map(\.availability).reduce(0, +) / Double(valid.count)
    return String(format: "%.1f%%", avg)
}

func displayDate(_ text: String?) -> String {
    guard let text, !text.isEmpty else { return "时间未知" }
    if let date = ISO8601DateFormatter().date(from: text) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }
    return text
}

func parseScalarObject(_ text: String) throws -> [String: JSONScalar] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [:] }
    let data = Data(trimmed.utf8)
    let decoded = try JSONDecoder().decode([String: JSONScalar].self, from: data)
    return decoded
}

func parseIntList(_ text: String) -> [Int]? {
    let values = text
        .split(separator: ",")
        .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
    return values.isEmpty ? nil : values
}

func trimNil(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func errorMessage(_ error: Error) -> String {
    if let apiError = error as? APIClientError {
        return apiError.errorDescription ?? "\(apiError)"
    }
    return error.localizedDescription
}

import Foundation
import SakrylleShared
import SwiftUI

let defaultAdminBaseURL = "ai1.sakrylle.com"

enum AccountStatusFilter: String, CaseIterable {
    case all
    case active
    case paused
    case error
}

func accountHasError(_ account: AdminAccountDTO) -> Bool {
    let normalized = (account.status ?? "").lowercased()
    return ["error", "errored", "failed"].contains(normalized)
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
    if accountHasError(account) {
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
    guard let avg = computeAvailabilityValue(timeline) else { return "--" }
    return String(format: "%.1f%%", avg)
}

func computeAvailabilityValue(_ timeline: [StatusTimePointDTO]) -> Double? {
    let valid = timeline.filter { $0.availability >= 0 }
    guard !valid.isEmpty else { return nil }
    return valid.map(\.availability).reduce(0, +) / Double(valid.count)
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

func normalizedAdminBaseURLForRequest(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    let hasScheme = trimmed.range(of: "http://", options: [.anchored, .caseInsensitive]) != nil
        || trimmed.range(of: "https://", options: [.anchored, .caseInsensitive]) != nil
    return hasScheme ? trimmed : "https://\(trimmed)"
}

func errorMessage(_ error: Error) -> String {
    if let apiError = error as? APIClientError {
        return apiError.errorDescription ?? "\(apiError)"
    }
    return error.localizedDescription
}

func isCancellationError(_ error: Error) -> Bool {
    error is CancellationError || (error as NSError).code == NSURLErrorCancelled
}

func chartDisplayPoints(_ points: [Double], targetCount: Int = 7) -> [Double] {
    guard points.count > targetCount else { return points }
    return (0..<targetCount).map { index in
        let start = points.count * index / targetCount
        let end = points.count * (index + 1) / targetCount
        let bucket = points[start..<max(end, start + 1)]
        return bucket.reduce(0, +) / Double(bucket.count)
    }
}

struct StyledSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ColorPalette.mutedText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ColorPalette.faintText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(ColorPalette.mutedCard.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ColorPalette.borderSoft, lineWidth: 1)
        )
    }
}

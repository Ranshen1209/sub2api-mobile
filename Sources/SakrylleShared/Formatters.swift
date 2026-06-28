import Foundation

public enum RangeKey: String, CaseIterable, Sendable {
    case h24 = "24h"
    case d7 = "7d"
    case d30 = "30d"
}

public struct DateRangeQuery: Sendable, Equatable {
    public let startDate: String
    public let endDate: String
    public let granularity: String

    public init(startDate: String, endDate: String, granularity: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.granularity = granularity
    }
}

public func makeDateRange(_ key: RangeKey, now: Date = Date(), calendar: Calendar = .current) -> DateRangeQuery {
    var start = now
    let end = now

    switch key {
    case .h24:
        start = calendar.date(byAdding: .hour, value: -23, to: now) ?? now
    case .d7:
        start = calendar.date(byAdding: .day, value: -6, to: now) ?? now
    case .d30:
        start = calendar.date(byAdding: .day, value: -29, to: now) ?? now
    }

    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"

    return DateRangeQuery(
        startDate: formatter.string(from: start),
        endDate: formatter.string(from: end),
        granularity: key == .h24 ? "hour" : "day"
    )
}

public func formatCompactNumber(_ value: Double, digits: Int = 1) -> String {
    let absValue = abs(value)
    let units: [(Double, String)] = [(1_000_000_000_000, "T"), (1_000_000_000, "B"), (1_000_000, "M"), (1_000, "K")]
    for (threshold, suffix) in units where absValue >= threshold {
        var text = String(format: "%.\(digits)f", value / threshold)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return text + suffix
    }
    return String(Int(value.rounded()))
}

public func formatTokenValue(_ value: Double) -> String {
    formatCompactNumber(value, digits: 1)
}

public func formatMoney(_ value: Double?) -> String {
    guard let value else { return "--" }
    return "￥" + String(format: "%.2f", value)
}

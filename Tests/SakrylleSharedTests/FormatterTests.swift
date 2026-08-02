import XCTest
@testable import SakrylleShared

final class FormatterTests: XCTestCase {
    func testUsageMoneyKeepsSubCentConsumptionVisible() {
        XCTAssertEqual(formatUsageMoney(0.0049), "￥0.0049")
        XCTAssertEqual(formatUsageMoney(nil), "--")
    }
    func testMoneyUsesYuanPrefix() {
        XCTAssertEqual(formatMoney(12.3), "￥12.30")
        XCTAssertEqual(formatMoney(nil), "--")
    }

    func testCompactNumber() {
        XCTAssertEqual(formatTokenValue(1_250), "1.2K")
        XCTAssertEqual(formatCompactNumber(1_000_000, digits: 1), "1M")
    }

    func testDateRangeSevenDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-06-28T12:00:00Z")!
        let range = makeDateRange(.d7, now: now, calendar: calendar)
        XCTAssertEqual(range.startDate, "2026-06-22")
        XCTAssertEqual(range.endDate, "2026-06-28")
        XCTAssertEqual(range.granularity, "day")
    }
}

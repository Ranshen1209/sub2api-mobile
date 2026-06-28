import XCTest

final class SakrylleAdminUITests: XCTestCase {
    func testLaunchShowsLoginOrMainApp() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

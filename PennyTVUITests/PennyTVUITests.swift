import XCTest

@MainActor
final class PennyTVUITests: XCTestCase {
  func testDashboardDataAndRemoteFocus() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launchEnvironment["PENNY_UI_TESTING"] = "1"
    app.launch()

    let remaining = app.staticTexts["remainingBudgetValue"]
    XCTAssertTrue(remaining.waitForExistence(timeout: 10))
    XCTAssertTrue(remaining.label.contains("2,930.00"), remaining.label)
    let needs = app.descendants(matching: .any)["category-needs"]
    let wants = app.descendants(matching: .any)["category-wants"]
    XCTAssertTrue(needs.waitForExistence(timeout: 5))
    XCTAssertTrue(wants.exists)
    XCTAssertTrue(app.descendants(matching: .any)["Current category spending"].exists)
    XCTAssertTrue(app.descendants(matching: .any)["Income and spending across recent months"].exists)

    for _ in 0..<4 where !needs.hasFocus {
      XCUIRemote.shared.press(.down)
    }
    XCTAssertTrue(needs.hasFocus)
    XCUIRemote.shared.press(.right)
    XCTAssertTrue(wants.waitForExistence(timeout: 5))
    XCTAssertTrue(wants.hasFocus)
  }
}

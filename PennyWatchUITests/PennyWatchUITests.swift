import XCTest

@MainActor
final class PennyWatchUITests: XCTestCase {
  func testSharedBudgetOpensSpendingForm() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Left in plan"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["$1,000.00"].exists)
    app.buttons["Add spending"].tap()

    let amount = app.textFields["Amount (USD)"]
    XCTAssertTrue(amount.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["Send to iPhone"].exists)
    XCTAssertFalse(app.buttons["Send to iPhone"].isEnabled)
  }

  func testQueuesSpendingToPairedIPhone() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-testing-send-entry"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Left in plan"].waitForExistence(timeout: 10))
    app.buttons["Add spending"].tap()
    let send = app.buttons["Send to iPhone"]
    XCTAssertTrue(send.waitForExistence(timeout: 5))
    XCTAssertTrue(send.isEnabled)
    send.tap()

    XCTAssertTrue(app.staticTexts["Queued for iPhone"].waitForExistence(timeout: 10))
  }
}

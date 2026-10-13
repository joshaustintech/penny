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
    for _ in 0..<4 where !app.buttons["Send to iPhone"].exists { app.swipeUp() }
    XCTAssertTrue(app.buttons["Send to iPhone"].exists)
    XCTAssertFalse(app.buttons["Send to iPhone"].isEnabled)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "watch-entry-form"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testQueuesSpendingToPairedIPhone() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--ui-testing-send-entry"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Left in plan"].waitForExistence(timeout: 10))
    app.buttons["Add spending"].tap()
    let send = app.buttons["Send to iPhone"]
    for _ in 0..<4 where !send.exists { app.swipeUp() }
    XCTAssertTrue(send.waitForExistence(timeout: 5))
    XCTAssertTrue(send.isEnabled)
    send.tap()

    XCTAssertTrue(app.staticTexts["Queued for iPhone"].waitForExistence(timeout: 10))
  }
}

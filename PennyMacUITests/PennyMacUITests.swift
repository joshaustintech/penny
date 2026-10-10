import XCTest

@MainActor
final class PennyMacUITests: XCTestCase {
  func testExportOpensNativeSavePanel() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()

    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 10))
    income.click()
    income.typeText("5000")
    app.buttons["createBudgetButton"].click()
    XCTAssertTrue(app.buttons["Export"].waitForExistence(timeout: 10))

    app.buttons["Export"].click()
    let markdown = app.buttons["Markdown report"]
    XCTAssertTrue(markdown.waitForExistence(timeout: 5))
    markdown.click()

    let savePanel = app.dialogs.firstMatch
    XCTAssertTrue(savePanel.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(savePanel.buttons["Cancel"].exists)
    savePanel.buttons["Cancel"].click()
  }
}

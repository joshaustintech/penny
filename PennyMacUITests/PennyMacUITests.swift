import XCTest

@MainActor
final class PennyMacUITests: XCTestCase {
  func testTransactionHistoryUsesNativeTableAndContextMenu() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 10))
    income.click()
    income.typeText("5000")
    app.buttons["createBudgetButton"].click()
    app.buttons["addEntryButton"].click()
    let amount = app.textFields["entryAmountField"]
    XCTAssertTrue(amount.waitForExistence(timeout: 5))
    amount.click()
    amount.typeText("40")
    let note = app.textFields["Note (optional)"]
    note.click()
    note.typeText("Lunch")
    app.buttons["saveEntryButton"].click()

    let table = app.tables["transactionTable"]
    XCTAssertTrue(table.waitForExistence(timeout: 10))
    let lunch = table.staticTexts["Lunch"]
    XCTAssertTrue(lunch.waitForExistence(timeout: 5))
    lunch.rightClick()
    XCTAssertTrue(app.menuItems["Edit"].waitForExistence(timeout: 5))
    app.menuItems["Edit"].click()
    XCTAssertTrue(app.navigationBars["Edit entry"].waitForExistence(timeout: 5))
  }

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

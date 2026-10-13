import XCTest

@MainActor
final class PennyMacUITests: XCTestCase {
  func testDashboardBalanceHierarchy() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store", "--screenshot-fixture"]
    app.launch()
    let balance = app.descendants(matching: .any)["remainingPlanSummary"]
    XCTAssertTrue(balance.waitForExistence(timeout: 5))
    XCTAssertTrue(balance.label.contains("$2,930.00"))
    let spending = app.descendants(matching: .any)["actualSpendingSummary"]
    XCTAssertLessThan(balance.frame.minY, spending.frame.minY)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "macos-dashboard-light"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testFileMenuAddsEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 10))
    income.click()
    income.typeText("5000")
    app.buttons["createBudgetButton"].click()

    app.menuBars.menuBarItems["File"].click()
    app.menuItems["Add Entry"].click()
    XCTAssertTrue(app.navigationBars["Add entry"].waitForExistence(timeout: 5))
  }

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

    app.descendants(matching: .any)["Activity"].firstMatch.click()
    let table = app.descendants(matching: .any)["transactionTable"]
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

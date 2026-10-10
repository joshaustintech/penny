import XCTest

@MainActor
final class PennyUITests: XCTestCase {
  func testOnboardAddSpendingAndReload() {
    let app = XCUIApplication()
    app.launch()

    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 10))
    enter("5000", in: income, app: app)
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Your monthly budget"].waitForExistence(timeout: 5))

    app.buttons["addEntryButton"].tap()
    let entryAmount = app.textFields["entryAmountField"]
    XCTAssertTrue(entryAmount.waitForExistence(timeout: 5))
    enter("100", in: entryAmount, app: app)
    app.textFields["Note (optional)"].tap()
    app.textFields["Note (optional)"].typeText("Groceries")
    app.buttons["saveEntryButton"].tap()
    XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 5))
    app.buttons["Previous month"].tap()
    XCTAssertFalse(app.staticTexts["Groceries"].exists)
    app.buttons["Next month"].tap()
    XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 5))
    app.buttons["Change budget style"].tap()
    app.buttons["Housing First"].tap()
    XCTAssertTrue(app.staticTexts["Housing"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Groceries"].exists)
    app.buttons["Change budget style"].tap()
    app.buttons["Balanced"].tap()

    app.terminate()
    app.launch()
    XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["$2,400.00"].exists)
  }

  private func enter(_ value: String, in field: XCUIElement, app: XCUIApplication) {
    field.tap()
    let selectAll = app.menuItems["Select All"]
    if selectAll.waitForExistence(timeout: 1) {
      selectAll.tap()
    } else {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
    }
    field.typeText(value)
  }
}

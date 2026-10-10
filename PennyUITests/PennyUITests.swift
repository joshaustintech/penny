import XCTest

@MainActor
final class PennyUITests: XCTestCase {
  func testSettingsPersistAppearanceAndShowPrivacy() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.staticTexts["Budget data stays on this device."].waitForExistence(timeout: 5))
    let appearance = app.buttons["appearancePicker"]
    XCTAssertTrue(appearance.waitForExistence(timeout: 5))
    appearance.tap()
    app.buttons["Dark"].tap()
    app.buttons["settingsDoneButton"].tap()

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["settingsButton"].tap()
    XCTAssertEqual(app.buttons["appearancePicker"].value as? String, "Dark")
    XCTAssertTrue(app.staticTexts["Budget data stays on this device."].exists)
  }

  func testOnboardAddSpendingAndReload() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()

    app.buttons["Previous month"].tap()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 10))
    enter("5000", in: income, app: app)
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Your monthly budget"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["$5,000.00"].exists)
    let plannedChart = app.staticTexts["Planned versus actual"]
    for _ in 0..<3 where !plannedChart.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(plannedChart.isHittable)
    let chartScreenshot = XCTAttachment(screenshot: app.screenshot())
    chartScreenshot.name = "Penny planned versus actual"
    chartScreenshot.lifetime = .keepAlways
    add(chartScreenshot)

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
    app.buttons["Next month"].tap()
    let nextIncome = app.textFields["incomeField"]
    XCTAssertTrue(nextIncome.waitForExistence(timeout: 5))
    enter("6000", in: nextIncome, app: app)
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(
      app.descendants(matching: .any)["Monthly spending history"].waitForExistence(timeout: 5))

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["Previous month"].tap()
    XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["$2,400.00"].exists)
    for _ in 0..<4 { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(app.descendants(matching: .any)["Monthly spending history"].isHittable)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Penny budget overview"
    screenshot.lifetime = .keepAlways
    add(screenshot)
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

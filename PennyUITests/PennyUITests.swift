import XCTest

@MainActor
final class PennyUITests: XCTestCase {
  func testSettingsPersistAppearanceAndShowPrivacy() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    app.buttons["settingsButton"].tap()
    let style = app.buttons["defaultBudgetModePicker"]
    XCTAssertTrue(style.waitForExistence(timeout: 5))
    XCTAssertEqual(style.value as? String, "Balanced")
    style.tap()
    app.collectionViews.buttons["Housing First"].tap()
    XCTAssertEqual(style.value as? String, "Housing First")
    let currency = app.buttons["preferredCurrencyPicker"]
    XCTAssertTrue(currency.waitForExistence(timeout: 5))
    XCTAssertEqual(currency.value as? String, "USD")
    currency.tap()
    app.buttons["UYU — Uruguayan Peso"].tap()
    XCTAssertEqual(currency.value as? String, "UYU")
    let appearance = app.buttons["appearancePicker"]
    XCTAssertTrue(appearance.waitForExistence(timeout: 5))
    appearance.tap()
    app.buttons["Dark"].tap()
    let privacy = app.staticTexts["Budget data stays on this device."]
    for _ in 0..<4 where !privacy.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(privacy.isHittable)
    app.buttons["settingsDoneButton"].tap()

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["settingsButton"].tap()
    XCTAssertEqual(app.buttons["appearancePicker"].value as? String, "Dark")
    XCTAssertEqual(app.buttons["defaultBudgetModePicker"].value as? String, "Housing First")
    XCTAssertEqual(app.buttons["preferredCurrencyPicker"].value as? String, "UYU")
    let savedPrivacy = app.staticTexts["Budget data stays on this device."]
    for _ in 0..<4 where !savedPrivacy.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(savedPrivacy.isHittable)
    app.buttons["settingsDoneButton"].tap()
    app.buttons["Previous month"].tap()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 5))
    enter("1000", in: income, app: app)
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Housing"].waitForExistence(timeout: 5))
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
    let actualSpending = app.descendants(matching: .any)["actualSpendingSummary"]
    XCTAssertTrue(actualSpending.label.contains("$0.00"))
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
    XCTAssertTrue(actualSpending.label.contains("$100.00"))
    app.buttons["addEntryButton"].tap()
    let overspendAmount = app.textFields["entryAmountField"]
    XCTAssertTrue(overspendAmount.waitForExistence(timeout: 5))
    enter("2500", in: overspendAmount, app: app)
    app.buttons["saveEntryButton"].tap()
    XCTAssertTrue(app.staticTexts["Over budget"].waitForExistence(timeout: 5))
    XCTAssertTrue(actualSpending.label.contains("$2,600.00"))
    let trendHeading = app.staticTexts["Spending through month"]
    for _ in 0..<4 where !trendHeading.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(trendHeading.isHittable)
    XCTAssertTrue(app.descendants(matching: .any)["Spending against monthly plan"].exists)
    let trendScreenshot = XCTAttachment(screenshot: app.screenshot())
    trendScreenshot.name = "Penny spending trend"
    trendScreenshot.lifetime = .keepAlways
    add(trendScreenshot)
    for _ in 0..<4 { app.scrollViews.firstMatch.swipeDown() }
    app.buttons["Previous month"].tap()
    XCTAssertFalse(app.staticTexts["Groceries"].exists)
    app.buttons["Next month"].tap()
    XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 5))
    app.buttons["Change budget style"].tap()
    XCTAssertTrue(
      app.staticTexts[
        "Category allocations for September 2026 will change. Recorded transactions stay the same."
      ].waitForExistence(timeout: 5))
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

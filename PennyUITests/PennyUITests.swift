import XCTest

@MainActor
final class PennyUITests: XCTestCase {
  func testIPadSetupHidesEmptyMonthsSidebar() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    guard app.windows.firstMatch.frame.width > 700 else {
      throw XCTSkip("The split view is only used on iPad.")
    }
    XCTAssertTrue(
      app.staticTexts["This budget stays on this device. Sync with iCloud in Settings."]
        .waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["Months"].exists)
    let income = app.textFields["incomeField"]
    enter("1000", in: income, app: app)
    app.scrollViews.firstMatch.swipeUp()
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Months"].waitForExistence(timeout: 5))
  }

  func testAccessibilityAuditForSetupSettingsAndBudget() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 5))
    enter("1000", in: income, app: app)
    app.scrollViews.firstMatch.swipeUp()
    try audit(app)
    app.buttons["settingsButton"].tap()
    try audit(app)
    app.buttons["settingsDoneButton"].tap()
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Your monthly budget"].waitForExistence(timeout: 5))
    try audit(app)
  }

  private func audit(_ app: XCUIApplication) throws {
    try app.performAccessibilityAudit { issue in
      print("AUDIT ISSUE: \(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "")")
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = "Accessibility audit issue"
      attachment.lifetime = .keepAlways
      self.add(attachment)
      return false
    }
  }

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
    let cloudSync = app.switches["privateCloudSyncToggle"]
    XCTAssertTrue(cloudSync.isHittable)
    XCTAssertEqual(cloudSync.value as? String, "0")
    let syncPrompt = app.staticTexts["Turn on iCloud sync to sync now."]
    for _ in 0..<4 where !syncPrompt.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(syncPrompt.isHittable)
    let watchSharing = app.switches["watchSharingToggle"]
    for _ in 0..<4 where !watchSharing.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(watchSharing.isHittable)
    XCTAssertEqual(watchSharing.value as? String, "0")
    watchSharing.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    XCTAssertEqual(watchSharing.value as? String, "1")
    XCTAssertTrue(
      app.staticTexts["Budget data stays on your devices."].waitForExistence(timeout: 3))
    app.buttons["settingsDoneButton"].tap()

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["settingsButton"].tap()
    XCTAssertEqual(app.buttons["appearancePicker"].value as? String, "Dark")
    XCTAssertEqual(app.buttons["defaultBudgetModePicker"].value as? String, "Housing First")
    XCTAssertEqual(app.buttons["preferredCurrencyPicker"].value as? String, "UYU")
    let savedWatchSharing = app.switches["watchSharingToggle"]
    for _ in 0..<10 where !savedWatchSharing.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertEqual(savedWatchSharing.value as? String, "1")
    let savedPrivacy = app.staticTexts["Budget data stays on your devices."]
    for _ in 0..<4 where !savedPrivacy.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(savedPrivacy.isHittable)
    app.buttons["settingsDoneButton"].tap()
    app.buttons["Previous month"].tap()
    XCTAssertTrue(
      app.staticTexts["This budget stays on this device. Sync with iCloud in Settings."]
        .waitForExistence(timeout: 5))
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 5))
    enter("1000", in: income, app: app)
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Housing"].waitForExistence(timeout: 5))
  }

  func testWatchSharingPublishesCurrentBudget() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 5))
    enter("1000", in: income, app: app)
    app.scrollViews.firstMatch.swipeUp()
    app.buttons["createBudgetButton"].tap()
    XCTAssertTrue(app.staticTexts["Your monthly budget"].waitForExistence(timeout: 5))
    app.buttons["settingsButton"].tap()
    let sharing = app.switches["watchSharingToggle"]
    for _ in 0..<4 where !sharing.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(sharing.isHittable)
    sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    XCTAssertEqual(sharing.value as? String, "1")
  }

  func testEditAndDeleteSpendingEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["--ui-testing", "--reset-store"]
    app.launch()
    let income = app.textFields["incomeField"]
    XCTAssertTrue(income.waitForExistence(timeout: 5))
    enter("1000", in: income, app: app)
    app.scrollViews.firstMatch.swipeUp()
    app.buttons["createBudgetButton"].tap()
    app.buttons["addEntryButton"].tap()
    let amount = app.textFields["entryAmountField"]
    XCTAssertTrue(amount.waitForExistence(timeout: 5))
    enter("40", in: amount, app: app)
    app.textFields["Note (optional)"].tap()
    app.textFields["Note (optional)"].typeText("Lunch")
    app.buttons["saveEntryButton"].tap()
    XCTAssertTrue(app.navigationBars["Add entry"].waitForNonExistence(timeout: 5))

    XCTAssertTrue(app.staticTexts["Lunch"].waitForExistence(timeout: 5))
    app.buttons["Edit Lunch"].tap()
    XCTAssertTrue(app.navigationBars["Edit entry"].waitForExistence(timeout: 5))
    let editAmount = app.textFields["entryAmountField"]
    XCTAssertTrue(editAmount.waitForExistence(timeout: 5))
    enter("55", in: editAmount, app: app)
    let note = app.textFields["Note (optional)"]
    note.tap()
    enter("Dinner", in: note, app: app)
    app.buttons["saveEntryButton"].tap()
    XCTAssertTrue(app.navigationBars["Edit entry"].waitForNonExistence(timeout: 5))
    let editedEntry = app.staticTexts["Dinner"]
    XCTAssertTrue(editedEntry.waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["$55.00"].exists)

    app.buttons["Delete Dinner"].tap()
    let confirmDelete = app.buttons["Delete"]
    XCTAssertTrue(confirmDelete.waitForExistence(timeout: 5))
    confirmDelete.tap()
    XCTAssertFalse(editedEntry.waitForExistence(timeout: 2))
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
    let allocation = app.descendants(matching: .any)["Budget allocation"]
    XCTAssertTrue(allocation.waitForExistence(timeout: 5))
    XCTAssertTrue((allocation.value as? String ?? "").contains("Needs: 50% of income"))
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
    app.buttons["Done"].tap()
    app.buttons["saveEntryButton"].tap()
    XCTAssertTrue(app.staticTexts["Over budget"].waitForExistence(timeout: 5))
    XCTAssertTrue(actualSpending.label.contains("$2,600.00"))
    let trendHeading = app.staticTexts["Spending through month"]
    for _ in 0..<16 where !trendHeading.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(trendHeading.isHittable)
    XCTAssertTrue(app.descendants(matching: .any)["Spending against monthly plan"].exists)
    let trendScreenshot = XCTAttachment(screenshot: app.screenshot())
    trendScreenshot.name = "Penny spending trend"
    trendScreenshot.lifetime = .keepAlways
    add(trendScreenshot)
    let scrollView = app.scrollViews.firstMatch
    let previousMonth = app.buttons["Previous month"]
    for _ in 0..<12 where !previousMonth.isHittable { scrollView.swipeDown() }
    previousMonth.tap()
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
    let savedBudgetTitle = app.staticTexts["Your monthly budget"]
    app.buttons["Create budget"].tap()
    if !savedBudgetTitle.waitForExistence(timeout: 2) {
      app.buttons["createBudgetButton"].tap()
    }
    XCTAssertTrue(savedBudgetTitle.waitForExistence(timeout: 5))
    XCTAssertTrue(
      app.descendants(matching: .any)["Monthly spending history"].waitForExistence(timeout: 5))

    app.terminate()
    app.launchArguments = ["--ui-testing"]
    app.launch()
    app.buttons["Previous month"].tap()
    XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["$2,400.00"].exists)
    let history = app.descendants(matching: .any)["Monthly spending history"]
    for _ in 0..<20 where !history.isHittable { app.scrollViews.firstMatch.swipeUp() }
    XCTAssertTrue(history.isHittable)
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

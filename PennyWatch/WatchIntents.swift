import AppIntents
import Foundation

private enum WatchBudgetQuery {
  static let noBudget = "Open Penny on iPhone and share this month's budget with Apple Watch."

  static func snapshot() -> WatchBudgetSnapshot? {
    guard let data = UserDefaults.standard.data(forKey: "watchBudgetSnapshot") else { return nil }
    return try? JSONDecoder().decode(WatchBudgetSnapshot.self, from: data)
  }

  static func amount(_ minor: Int64, _ snapshot: WatchBudgetSnapshot) -> String {
    let scale = Decimal(sign: .plus, exponent: snapshot.fractionDigits, significand: 1)
    return (Decimal(minor) / scale).formatted(.currency(code: snapshot.currency))
  }

  static func period(_ snapshot: WatchBudgetSnapshot) -> String {
    guard
      let date = Calendar.current.date(
        from: DateComponents(year: snapshot.year, month: snapshot.month))
    else { return "\(snapshot.month)/\(snapshot.year)" }
    return date.formatted(.dateTime.month(.wide).year())
  }

  static func categoryLabel(_ category: String, _ snapshot: WatchBudgetSnapshot) -> String {
    category == "housing" && !snapshot.categories.contains { $0.category == "housing" }
      ? "needs" : category
  }
}

enum WatchRemainingCategory: String, AppEnum {
  case housing, needs, wants, giving, debt, savings

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Budget category"
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .housing: "housing", .needs: "needs", .wants: "wants", .giving: "giving",
    .debt: "debt", .savings: "savings",
  ]
}

enum WatchSpendingCategory: String, AppEnum {
  case housing, needs, wants, giving

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Spending category"
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .housing: "housing", .needs: "needs", .wants: "wants", .giving: "giving",
  ]
}

struct WatchRemainingIntent: AppIntent {
  static let title: LocalizedStringResource = "Get remaining budget"
  static let description = IntentDescription("Reports the amount left in your shared Penny budget.")
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let snapshot = WatchBudgetQuery.snapshot() else {
      return .result(
        value: WatchBudgetQuery.noBudget,
        dialog: IntentDialog(stringLiteral: WatchBudgetQuery.noBudget))
    }
    guard let minor = snapshot.overallRemainingMinor else {
      let answer = "Penny couldn't calculate the remaining budget from these amounts."
      return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
    let answer =
      "You have \(WatchBudgetQuery.amount(minor, snapshot)) left in Penny for \(WatchBudgetQuery.period(snapshot))."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct WatchSpendingIntent: AppIntent {
  static let title: LocalizedStringResource = "Get monthly spending"
  static let description = IntentDescription("Reports spending in your shared Penny budget.")
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let snapshot = WatchBudgetQuery.snapshot() else {
      return .result(
        value: WatchBudgetQuery.noBudget,
        dialog: IntentDialog(stringLiteral: WatchBudgetQuery.noBudget))
    }
    guard let minor = snapshot.overallSpentMinor else {
      let answer = "Penny couldn't calculate spending from these amounts."
      return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
    let answer =
      "You've spent \(WatchBudgetQuery.amount(minor, snapshot)) in Penny for \(WatchBudgetQuery.period(snapshot))."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct WatchCategoryRemainingIntent: AppIntent {
  static let title: LocalizedStringResource = "Get category budget remaining"
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  @Parameter(title: "Category") var category: WatchRemainingCategory
  static var parameterSummary: some ParameterSummary { Summary("Get remaining for \(\.$category)") }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let snapshot = WatchBudgetQuery.snapshot() else {
      return .result(
        value: WatchBudgetQuery.noBudget,
        dialog: IntentDialog(stringLiteral: WatchBudgetQuery.noBudget))
    }
    guard let minor = snapshot.remainingMinor(for: category.rawValue) else {
      let answer = "Penny has no budget for \(category.rawValue)."
      return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
    let label = WatchBudgetQuery.categoryLabel(category.rawValue, snapshot)
    let answer =
      "You have \(WatchBudgetQuery.amount(minor, snapshot)) left in \(label) for \(WatchBudgetQuery.period(snapshot))."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct WatchCategorySpentIntent: AppIntent {
  static let title: LocalizedStringResource = "Get category spending"
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  @Parameter(title: "Category") var category: WatchSpendingCategory
  static var parameterSummary: some ParameterSummary { Summary("Get spending for \(\.$category)") }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let snapshot = WatchBudgetQuery.snapshot() else {
      return .result(
        value: WatchBudgetQuery.noBudget,
        dialog: IntentDialog(stringLiteral: WatchBudgetQuery.noBudget))
    }
    guard let minor = snapshot.spentMinor(for: category.rawValue) else {
      let answer = "Penny has no spending for \(category.rawValue)."
      return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }
    let label = WatchBudgetQuery.categoryLabel(category.rawValue, snapshot)
    let answer =
      "You've spent \(WatchBudgetQuery.amount(minor, snapshot)) in \(label) for \(WatchBudgetQuery.period(snapshot))."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct WatchPennyShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: WatchRemainingIntent(),
      phrases: ["How much money do I have left in \(.applicationName)?"],
      shortTitle: "Remaining budget", systemImageName: "chart.pie")
    AppShortcut(
      intent: WatchSpendingIntent(),
      phrases: ["How much have I spent in \(.applicationName)?"],
      shortTitle: "Monthly spending", systemImageName: "dollarsign.circle")
    AppShortcut(
      intent: WatchCategoryRemainingIntent(),
      phrases: ["How much is left in my \(\.$category) budget in \(.applicationName)?"],
      shortTitle: "Category remaining", systemImageName: "chart.bar")
    AppShortcut(
      intent: WatchCategorySpentIntent(),
      phrases: ["How much have I spent on \(\.$category) in \(.applicationName)?"],
      shortTitle: "Category spending", systemImageName: "dollarsign.circle")
  }
}

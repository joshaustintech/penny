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
    let minor = snapshot.categories.reduce(Int64(0)) { $0 + $1.remainingMinor }
    let answer = "You have \(WatchBudgetQuery.amount(minor, snapshot)) left in Penny."
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
    let minor = snapshot.categories.filter { !["debt", "savings"].contains($0.category) }
      .reduce(Int64(0)) { $0 + $1.usedMinor }
    let answer = "You've spent \(WatchBudgetQuery.amount(minor, snapshot)) in Penny."
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
  }
}

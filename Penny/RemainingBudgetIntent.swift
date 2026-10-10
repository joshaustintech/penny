import AppIntents
import Foundation
import SwiftData

struct RemainingBudgetIntent: AppIntent {
  static let title: LocalizedStringResource = "Get remaining budget"
  static let description = IntentDescription(
    "Reports how much remains in this month's Penny budget.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let components = Calendar.current.dateComponents([.year, .month], from: .now)
    let container = try ModelContainer(for: BudgetMonth.self, LedgerEntry.self)
    let context = ModelContext(container)
    let months = try context.fetch(FetchDescriptor<BudgetMonth>())
    guard
      let month = months.first(where: { $0.year == components.year && $0.month == components.month }
      )
    else {
      return .result(
        value: "No Penny budget is set up for this month.",
        dialog: "No Penny budget is set up for this month.")
    }

    let entries = try context.fetch(FetchDescriptor<LedgerEntry>()).filter {
      $0.dateComponents?.year == month.year && $0.dateComponents?.month == month.month
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = month.currencyCode
    let digits = formatter.maximumFractionDigits
    let report = try BudgetReporting.make(
      entries: entries, currencyCode: month.currencyCode, fractionDigits: digits,
      mode: BudgetMode(rawValue: month.mode) ?? .balanced)
    let remaining = try BudgetReporting.overallRemaining(from: report)
    let scale = Decimal(sign: .plus, exponent: digits, significand: 1)
    let amount = (Decimal(remaining.minorUnits) / scale)
      .formatted(.currency(code: month.currencyCode))
    let answer = "You have \(amount) left in Penny this month."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct PennyShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RemainingBudgetIntent(),
      phrases: ["How much money do I have left in \(.applicationName) this month?"],
      shortTitle: "Remaining budget", systemImageName: "chart.pie")
  }
}

import Foundation
import SwiftData

enum BudgetScreenshotFixture {
  @MainActor static func seed(in context: ModelContext, mode: BudgetMode) throws {
    let store = BudgetStore(context: context)
    guard try store.months().isEmpty else { return }
    let now = Date.now
    let parts = Calendar.current.dateComponents([.year, .month], from: now)
    guard let year = parts.year, let month = parts.month else { return }
    try store.createBudget(
      BudgetMonth(year: year, month: month, mode: mode.rawValue, currencyCode: "USD"),
      income: LedgerEntry(
        amountMinor: 500_000, currencyCode: "USD", fractionDigits: 2,
        kind: "income", category: "income", occurredAt: now, note: "Take-home pay"))
    for (amount, kind, category, note) in [
      (90_000, "spending", "needs", "Groceries"),
      (35_000, "spending", "wants", "Dining"),
      (12_000, "spending", "giving", "Community giving"),
      (20_000, "debt", "debt", "Debt payment"),
      (50_000, "savings", "savings", "Emergency fund"),
    ] {
      try store.save(
        LedgerEntry(
          amountMinor: Int64(amount), currencyCode: "USD", fractionDigits: 2,
          kind: kind, category: category, occurredAt: now, note: note))
    }
    if ProcessInfo.processInfo.arguments.contains("--screenshot-overspent") {
      try store.save(LedgerEntry(amountMinor: 450_000, currencyCode: "USD", fractionDigits: 2,
        kind: "spending", category: "needs", occurredAt: now, note: "Urgent home repair"))
    }
  }
}

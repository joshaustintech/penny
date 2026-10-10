import Foundation
import SwiftData
import Testing

@testable import PennyCore

struct PersistenceTests {
  @MainActor @Test func createsBudgetAndIncomeTogether() throws {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let store = BudgetStore(context: ModelContext(container))
    let budget = BudgetMonth(year: 2026, month: 10, mode: "balanced", currencyCode: "USD")
    let income = LedgerEntry(
      amountMinor: 500_000, currencyCode: "USD", fractionDigits: 2,
      kind: "income", category: "income")

    try store.createBudget(budget, income: income)
    #expect(try store.months().map(\.id) == [budget.id])
    #expect(try store.entries().map(\.amountMinor) == [500_000])
  }

  @MainActor @Test func storesAndDeletesLedgerEntries() throws {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let store = BudgetStore(context: ModelContext(container))
    let entry = LedgerEntry(
      amountMinor: 4_250, currencyCode: "USD", fractionDigits: 2,
      kind: "spending", category: "needs", note: "Market")

    try store.save(entry)
    #expect(try store.entries().map(\.id) == [entry.id])
    try store.delete(entry)
    #expect(try store.entries().isEmpty)
  }

  @MainActor @Test func rejectsDuplicateIdentifiers() throws {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let store = BudgetStore(context: ModelContext(container))
    let original = LedgerEntry(
      amountMinor: 1, currencyCode: "USD", fractionDigits: 2,
      kind: "income", category: "income")
    let duplicate = LedgerEntry(
      amountMinor: 1, currencyCode: "USD", fractionDigits: 2,
      kind: "income", category: "income")
    duplicate.id = original.id

    try store.save(original)
    #expect(throws: StoreError.duplicateIdentifier) { try store.save(duplicate) }
  }
}

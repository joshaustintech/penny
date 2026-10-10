import Foundation
import SwiftData
import Testing

@testable import PennyCore

struct PersistenceTests {
  @Test func transactionMonthUsesStoredCalendarDate() throws {
    let entry = LedgerEntry(
      amountMinor: 100, currencyCode: "USD", fractionDigits: 2,
      kind: "spending", category: "needs")
    entry.calendarDate = "2026-10-1"
    entry.occurredAt = try #require(
      Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 1)))

    #expect(entry.dateComponents?.year == 2026)
    #expect(entry.dateComponents?.month == 10)
    #expect(entry.transactionDate != entry.occurredAt)
  }

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

  @MainActor @Test func rejectsInvalidLedgerCategory() throws {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let store = BudgetStore(context: ModelContext(container))
    let invalid = LedgerEntry(
      amountMinor: 10, currencyCode: "USD", fractionDigits: 2,
      kind: "spending", category: "savings")

    #expect(throws: StoreError.invalidEntry) { try store.save(invalid) }
    #expect(try store.entries().isEmpty)
  }

  @MainActor @Test func updatesExistingEntryWithoutChangingIdentifier() throws {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let store = BudgetStore(context: ModelContext(container))
    let entry = LedgerEntry(
      amountMinor: 100, currencyCode: "USD", fractionDigits: 2,
      kind: "spending", category: "needs")

    try store.save(entry)
    entry.amountMinor = 250
    try store.update(entry)
    #expect(try store.entries().first?.amountMinor == 250)
    #expect(try store.entries().first?.id == entry.id)
  }
}

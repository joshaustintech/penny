import Foundation
import Testing

@testable import PennyCore

struct ReportingTests {
  @Test func reportsNetSpendingAndSeparateSavingsAndDebtProgress() throws {
    let entries = [
      LedgerEntry(
        amountMinor: 10_000, currencyCode: "USD", fractionDigits: 2,
        kind: "income", category: "income"),
      LedgerEntry(
        amountMinor: 1_000, currencyCode: "USD", fractionDigits: 2,
        kind: "spending", category: "housing"),
      LedgerEntry(
        amountMinor: 200, currencyCode: "USD", fractionDigits: 2,
        kind: "refund", category: "housing"),
      LedgerEntry(
        amountMinor: 500, currencyCode: "USD", fractionDigits: 2,
        kind: "savings", category: "savings"),
      LedgerEntry(
        amountMinor: 700, currencyCode: "USD", fractionDigits: 2,
        kind: "debt", category: "debt"),
    ]

    let report = try BudgetReporting.make(
      entries: entries, currencyCode: "USD", fractionDigits: 2, mode: .balanced)
    #expect(report.income.minorUnits == 10_000)
    #expect(report.categories[0].spent.minorUnits == 800)
    #expect(report.categories[0].remaining.minorUnits == 4_200)
    #expect(report.categories[3].contributed.minorUnits == 700)
    #expect(report.categories[3].remaining.minorUnits == 300)
    #expect(report.categories[4].spent.minorUnits == 0)
    #expect(report.categories[4].remaining.minorUnits == 500)
    #expect(try BudgetReporting.spent(for: .needs, from: report).minorUnits == 800)
    #expect(try BudgetReporting.contributed(for: .savings, from: report).minorUnits == 500)
    #expect(try BudgetReporting.contributed(for: .debt, from: report).minorUnits == 700)
    #expect(try BudgetReporting.remaining(for: .wants, from: report).minorUnits == 2_000)
    #expect(try BudgetReporting.overallSpent(from: report).minorUnits == 800)
    #expect(try BudgetReporting.overallRemaining(from: report).minorUnits == 8_000)
    #expect(!BudgetReporting.isOverBudget(from: report))
  }

  @Test func detectsCategoryOverspendingEvenWhenOtherCategoriesRemain() throws {
    let report = try BudgetReporting.make(
      entries: [
        LedgerEntry(
          amountMinor: 10_000, currencyCode: "USD", fractionDigits: 2,
          kind: "income", category: "income"),
        LedgerEntry(
          amountMinor: 5_001, currencyCode: "USD", fractionDigits: 2,
          kind: "spending", category: "needs"),
      ], currencyCode: "USD", fractionDigits: 2, mode: .balanced)
    #expect(BudgetReporting.isOverBudget(from: report))
  }

  @Test func supportsEmptyMonthAndRejectsWrongCurrency() throws {
    let report = try BudgetReporting.make(
      entries: [], currencyCode: "JPY", fractionDigits: 0, mode: .housingFirst)
    #expect(report.income.minorUnits == 0)
    #expect(report.categories.allSatisfy { $0.remaining.minorUnits == 0 })
    let wrong = LedgerEntry(
      amountMinor: 1, currencyCode: "USD", fractionDigits: 2,
      kind: "spending", category: "needs")
    #expect(throws: BudgetError.invalidTransaction) {
      try BudgetReporting.make(
        entries: [wrong], currencyCode: "JPY", fractionDigits: 0, mode: .balanced)
    }
  }

  @Test func dailyTrendIncludesQuietDaysAndRefunds() throws {
    let date = try #require(
      Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1)))
    let entries = [
      LedgerEntry(
        amountMinor: 1_000, currencyCode: "USD", fractionDigits: 2,
        kind: "spending", category: "needs", occurredAt: date),
      LedgerEntry(
        amountMinor: 300, currencyCode: "USD", fractionDigits: 2,
        kind: "refund", category: "needs",
        occurredAt: Calendar.current.date(byAdding: .day, value: 1, to: date)!),
      LedgerEntry(
        amountMinor: 200, currencyCode: "USD", fractionDigits: 2,
        kind: "adjustment", category: "needs",
        occurredAt: Calendar.current.date(byAdding: .day, value: 3, to: date)!),
    ]
    let trend = try BudgetReporting.dailySpending(
      entries: entries, year: 2026, month: 9, currencyCode: "USD", fractionDigits: 2)
    #expect(trend.count == 30)
    #expect(trend[0].cumulative.minorUnits == 1_000)
    #expect(trend[1].cumulative.minorUnits == 700)
    #expect(trend[2].cumulative.minorUnits == 700)
    #expect(trend[3].cumulative.minorUnits == 900)
  }

  @Test func rejectsInvalidCurrencyPrecisionWithoutCrashing() {
    let entry = LedgerEntry(
      amountMinor: 1, currencyCode: "USD", fractionDigits: 8,
      kind: "spending", category: "needs")
    #expect(throws: BudgetError.invalidTransaction) {
      try BudgetReporting.make(
        entries: [entry], currencyCode: "USD", fractionDigits: 2, mode: .balanced)
    }
  }

  @Test func watchSnapshotCarriesBudgetAndNewestFiveTransactions() throws {
    let entries = (1...6).map { day in
      LedgerEntry(
        amountMinor: Int64(day * 100), currencyCode: "USD", fractionDigits: 2,
        kind: "spending", category: "needs",
        occurredAt: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: day))!)
    }
    let report = try BudgetReporting.make(
      entries: entries, currencyCode: "USD", fractionDigits: 2, mode: .balanced)
    let snapshot = try WatchBudgetSnapshot(report: report, entries: entries, year: 2026, month: 9)
    let decoded = try JSONDecoder().decode(
      WatchBudgetSnapshot.self, from: JSONEncoder().encode(snapshot))

    #expect(decoded == snapshot)
    #expect(snapshot.incomeMinor == 0)
    #expect(snapshot.categories[0].usedMinor == 2_100)
    #expect(snapshot.recentTransactions.map(\.day) == [6, 5, 4, 3, 2])
  }
}

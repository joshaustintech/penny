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
    #expect(try BudgetReporting.remaining(for: .wants, from: report).minorUnits == 2_000)
    #expect(try BudgetReporting.overallSpent(from: report).minorUnits == 800)
    #expect(try BudgetReporting.overallRemaining(from: report).minorUnits == 8_000)
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

  @Test func rejectsInvalidCurrencyPrecisionWithoutCrashing() {
    let entry = LedgerEntry(
      amountMinor: 1, currencyCode: "USD", fractionDigits: 8,
      kind: "spending", category: "needs")
    #expect(throws: BudgetError.invalidTransaction) {
      try BudgetReporting.make(
        entries: [entry], currencyCode: "USD", fractionDigits: 2, mode: .balanced)
    }
  }
}

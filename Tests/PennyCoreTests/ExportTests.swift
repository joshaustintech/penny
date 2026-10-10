import Testing

@testable import PennyCore

struct ExportTests {
  @Test func csvEscapesTextAndProtectsFormulaFields() {
    let entry = LedgerEntry(
      amountMinor: -1_234, currencyCode: "USD", fractionDigits: 2,
      kind: "adjustment", category: "needs", note: " =SUM(A1:A2),\"bad\"")
    entry.calendarDate = "2026-10-3"

    let csv = BudgetExport.csv(entries: [entry])
    #expect(csv.hasPrefix(BudgetExport.csvHeaders + "\r\n"))
    #expect(csv.contains("\"2026-10-03\",\"-12.34\",\"USD\""))
    #expect(csv.contains("\"' =SUM(A1:A2),\"\"bad\"\"\""))
  }

  @Test func markdownIncludesIncomeSpendingAndTransactions() throws {
    let month = BudgetMonth(year: 2026, month: 10, mode: "balanced", currencyCode: "USD")
    let entries = [
      LedgerEntry(
        amountMinor: 500_000, currencyCode: "USD", fractionDigits: 2,
        kind: "income", category: "income"),
      LedgerEntry(
        amountMinor: 10_000, currencyCode: "USD", fractionDigits: 2,
        kind: "spending", category: "needs", note: "Market | food"),
    ]
    let report = try BudgetReporting.make(
      entries: entries, currencyCode: "USD", fractionDigits: 2, mode: .balanced)

    let markdown = try BudgetExport.markdown(month: month, report: report, entries: entries)
    #expect(markdown.contains("Income: USD 5000.00"))
    #expect(markdown.contains("Actual spending: USD 100.00"))
    #expect(markdown.contains("Remaining: USD 4900.00"))
    #expect(markdown.contains("Market \\| food"))
  }

  @Test func markdownEscapesRawHTMLInNotes() throws {
    let month = BudgetMonth(year: 2026, month: 10, mode: "balanced", currencyCode: "USD")
    let income = LedgerEntry(
      amountMinor: 1_000, currencyCode: "USD", fractionDigits: 2,
      kind: "income", category: "income")
    let note = "<img src=x onerror=alert(1)> & safe"
    let entry = LedgerEntry(
      amountMinor: 100, currencyCode: "USD", fractionDigits: 2,
      kind: "spending", category: "needs", note: note)
    let entries = [income, entry]
    let report = try BudgetReporting.make(
      entries: entries, currencyCode: "USD", fractionDigits: 2, mode: .balanced)

    let markdown = try BudgetExport.markdown(month: month, report: report, entries: entries)

    #expect(markdown.contains("&lt;img src=x onerror=alert(1)&gt; &amp; safe"))
    #expect(!markdown.contains("<img"))
  }
}

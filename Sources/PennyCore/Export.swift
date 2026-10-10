import Foundation

public enum BudgetExport {
  public static let csvHeaders =
    "id,date,amount,currency,type,category,subcategory,description"

  public static func csv(entries: [LedgerEntry]) -> String {
    let rows = entries.sorted(by: ordered).map { entry in
      [
        cell(entry.id.uuidString), cell(date(entry)),
        cell(
          decimal(entry.amountMinor, fractionDigits: entry.fractionDigits), protectFormula: false),
        cell(entry.currencyCode), cell(entry.kind), cell(entry.category),
        cell(entry.subcategory ?? ""), cell(entry.note ?? ""),
      ].joined(separator: ",")
    }
    return ([csvHeaders] + rows).joined(separator: "\r\n") + "\r\n"
  }

  public static func markdown(
    month: BudgetMonth, report: MonthlyReport, entries: [LedgerEntry]
  ) throws -> String {
    guard month.currencyCode == report.income.currency,
      let mode = BudgetMode(rawValue: month.mode)
    else { throw BudgetError.invalidTransaction }
    let spent = try total(report.categories.map(\.spent.minorUnits))
    let debt = try total(
      report.categories.map(\.contributed.minorUnits).enumerated().filter {
        report.categories[$0.offset].category == .debt
      }.map(\.element))
    let savings = try total(
      report.categories.map(\.contributed.minorUnits).enumerated().filter {
        report.categories[$0.offset].category == .savings
      }.map(\.element))
    let allocated = try total(report.categories.map(\.allocated.minorUnits))
    let remaining = try total(report.categories.map(\.remaining.minorUnits))
    var lines = [
      "# Penny budget — \(month.year)-\(String(format: "%02d", month.month))",
      "", "- Mode: \(mode == .balanced ? "Balanced" : "Housing First")",
      "- Income: \(money(report.income.minorUnits, currency: month.currencyCode, digits: report.income.fractionDigits))",
      "- Allocated: \(money(allocated, currency: month.currencyCode, digits: report.income.fractionDigits))",
      "- Actual spending: \(money(spent, currency: month.currencyCode, digits: report.income.fractionDigits))",
      "- Debt paid: \(money(debt, currency: month.currencyCode, digits: report.income.fractionDigits))",
      "- Savings contributed: \(money(savings, currency: month.currencyCode, digits: report.income.fractionDigits))",
      "- Remaining: \(money(remaining, currency: month.currencyCode, digits: report.income.fractionDigits))",
      "", "| Category | Allocated | Spent or contributed | Remaining |",
      "| --- | ---: | ---: | ---: |",
    ]
    for item in report.categories {
      let actual =
        item.category == .debt || item.category == .savings
        ? item.contributed.minorUnits : item.spent.minorUnits
      lines.append(
        "| \(item.category.rawValue.capitalized) | \(money(item.allocated.minorUnits, currency: month.currencyCode, digits: report.income.fractionDigits)) | \(money(actual, currency: month.currencyCode, digits: report.income.fractionDigits)) | \(money(item.remaining.minorUnits, currency: month.currencyCode, digits: report.income.fractionDigits)) |"
      )
    }
    lines += [
      "", "## Transactions", "", "| Date | Type | Category | Amount | Description |",
      "| --- | --- | --- | ---: | --- |",
    ]
    for entry in entries.sorted(by: ordered) {
      lines.append(
        "| \(date(entry)) | \(entry.kind.capitalized) | \(entry.category.capitalized) | \(money(entry.amountMinor, currency: entry.currencyCode, digits: entry.fractionDigits)) | \(markdownCell(entry.note ?? "")) |"
      )
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private static func total(_ values: [Int64]) throws -> Int64 {
    try values.reduce(Int64(0)) { sum, value in
      let (next, overflow) = sum.addingReportingOverflow(value)
      guard !overflow else { throw ExportError.overflow }
      return next
    }
  }

  private static func money(_ value: Int64, currency: String, digits: Int) -> String {
    "\(currency) \(decimal(value, fractionDigits: digits))"
  }

  private static func decimal(_ value: Int64, fractionDigits: Int) -> String {
    var scale: UInt64 = 1
    for _ in 0..<fractionDigits { scale *= 10 }
    let magnitude = value.magnitude
    let whole = magnitude / scale
    guard fractionDigits > 0 else { return "\(value < 0 ? "-" : "")\(whole)" }
    let fraction = String(magnitude % scale)
    let padding = String(repeating: "0", count: fractionDigits - fraction.count)
    return "\(value < 0 ? "-" : "")\(whole).\(padding)\(fraction)"
  }

  private static func date(_ entry: LedgerEntry) -> String {
    guard let parts = entry.dateComponents,
      let year = parts.year, let month = parts.month, let day = parts.day
    else { return "" }
    return String(format: "%04d-%02d-%02d", year, month, day)
  }

  private static func ordered(_ left: LedgerEntry, _ right: LedgerEntry) -> Bool {
    if date(left) != date(right) { return date(left) < date(right) }
    if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
    return left.id.uuidString < right.id.uuidString
  }

  private static func cell(_ value: String, protectFormula: Bool = true) -> String {
    let trimmed = value.drop(while: \.isWhitespace)
    let unsafe = trimmed.first.map { "=+-@".contains($0) } ?? false
    let safe = protectFormula && unsafe ? "'\(value)" : value
    return "\"\(safe.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private static func markdownCell(_ value: String) -> String {
    value.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "[", with: "\\[")
      .replacingOccurrences(of: "]", with: "\\]")
      .replacingOccurrences(of: "|", with: "\\|")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\r", with: " ")
  }
}

public enum ExportError: Error, Equatable {
  case overflow
}

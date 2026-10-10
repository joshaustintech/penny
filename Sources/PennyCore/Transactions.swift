import Foundation

public enum TransactionKind: String, CaseIterable, Sendable {
  case income, spending, savings, debt, refund, adjustment
}

public enum BudgetCategory: String, CaseIterable, Sendable {
  case income, housing, needs, wants, giving, debt, savings
}

public struct CategoryResult: Equatable, Sendable {
  public let category: BudgetCategory
  public let percent: Int
  public let allocated: Money
  public let spent: Money
  public let contributed: Money
  public let remaining: Money
}

public struct MonthlyReport: Equatable, Sendable {
  public let income: Money
  public let categories: [CategoryResult]
}

public enum BudgetReporting {
  public static func overallSpent(from report: MonthlyReport) throws -> Money {
    var total: Int64 = 0
    for category in report.categories {
      let (sum, overflow) = total.addingReportingOverflow(category.spent.minorUnits)
      guard !overflow else { throw BudgetError.overflow }
      total = sum
    }
    return Money(
      minorUnits: total, currency: report.income.currency,
      fractionDigits: report.income.fractionDigits)
  }

  public static func overallRemaining(from report: MonthlyReport) throws -> Money {
    var total: Int64 = 0
    for category in report.categories {
      let (sum, overflow) = total.addingReportingOverflow(category.remaining.minorUnits)
      guard !overflow else { throw BudgetError.overflow }
      total = sum
    }
    return Money(
      minorUnits: total, currency: report.income.currency,
      fractionDigits: report.income.fractionDigits)
  }

  public static func make(
    entries: [LedgerEntry], currencyCode: String, fractionDigits: Int, mode: BudgetMode
  ) throws -> MonthlyReport {
    guard (0...4).contains(fractionDigits),
      entries.allSatisfy({ (0...4).contains($0.fractionDigits) })
    else { throw BudgetError.invalidTransaction }
    let money = entries.map {
      Money(
        minorUnits: $0.amountMinor, currency: $0.currencyCode, fractionDigits: $0.fractionDigits)
    }
    let incomeEntries = zip(entries, money).filter { $0.0.kind == TransactionKind.income.rawValue }
    let income = incomeEntries.map(\.1)
    for (entry, amount) in incomeEntries {
      guard entry.category == BudgetCategory.income.rawValue,
        amount.currency == currencyCode, amount.fractionDigits == fractionDigits,
        amount.minorUnits >= 0
      else { throw BudgetError.invalidTransaction }
    }
    let source =
      income.isEmpty
      ? [Money(minorUnits: 0, currency: currencyCode, fractionDigits: fractionDigits)] : income
    let allocations = try Budget.allocate(income: source, mode: mode)
    var spent: [BudgetCategory: Int64] = [:]
    var contributed: [BudgetCategory: Int64] = [:]

    for (entry, amount) in zip(entries, money) where entry.kind != TransactionKind.income.rawValue {
      guard let kind = TransactionKind(rawValue: entry.kind),
        let category = BudgetCategory(rawValue: entry.category),
        amount.currency == currencyCode, amount.fractionDigits == fractionDigits,
        category != .income, kind == .adjustment || amount.minorUnits >= 0
      else { throw BudgetError.invalidTransaction }
      let reportCategory: BudgetCategory =
        category == .housing && mode == .balanced ? .needs : category
      guard mode.allocations.contains(where: { $0.category == reportCategory.rawValue }) else {
        throw BudgetError.invalidTransaction
      }
      switch kind {
      case .income: throw BudgetError.invalidTransaction
      case .spending, .refund, .adjustment:
        guard ![BudgetCategory.debt, .savings].contains(category) else {
          throw BudgetError.invalidTransaction
        }
        let delta = kind == .refund ? -amount.minorUnits : amount.minorUnits
        try add(delta, to: reportCategory, in: &spent)
      case .savings:
        guard category == .savings else { throw BudgetError.invalidTransaction }
        try add(amount.minorUnits, to: category, in: &contributed)
      case .debt:
        guard category == .debt else { throw BudgetError.invalidTransaction }
        try add(amount.minorUnits, to: category, in: &contributed)
      }
    }

    let incomeTotal = try total(income, currencyCode: currencyCode, fractionDigits: fractionDigits)
    let results = try allocations.map { allocation -> CategoryResult in
      guard let category = BudgetCategory(rawValue: allocation.category) else {
        throw BudgetError.invalidTransaction
      }
      let isContribution = category == .debt || category == .savings
      let used = isContribution ? contributed[category, default: 0] : spent[category, default: 0]
      let (remaining, overflow) = allocation.amount.minorUnits.subtractingReportingOverflow(used)
      guard !overflow else { throw BudgetError.overflow }
      return CategoryResult(
        category: category, percent: allocation.percent, allocated: allocation.amount,
        spent: Money(
          minorUnits: spent[category, default: 0], currency: currencyCode,
          fractionDigits: fractionDigits),
        contributed: Money(
          minorUnits: contributed[category, default: 0], currency: currencyCode,
          fractionDigits: fractionDigits),
        remaining: Money(
          minorUnits: remaining, currency: currencyCode, fractionDigits: fractionDigits))
    }
    return MonthlyReport(income: incomeTotal, categories: results)
  }

  private static func total(_ amounts: [Money], currencyCode: String, fractionDigits: Int) throws
    -> Money
  {
    var sum: Int64 = 0
    for amount in amounts {
      guard amount.currency == currencyCode, amount.fractionDigits == fractionDigits,
        amount.minorUnits >= 0
      else { throw BudgetError.invalidTransaction }
      let (next, overflow) = sum.addingReportingOverflow(amount.minorUnits)
      guard !overflow else { throw BudgetError.overflow }
      sum = next
    }
    return Money(minorUnits: sum, currency: currencyCode, fractionDigits: fractionDigits)
  }

  private static func add(
    _ amount: Int64, to category: BudgetCategory, in totals: inout [BudgetCategory: Int64]
  ) throws {
    let (sum, overflow) = totals[category, default: 0].addingReportingOverflow(amount)
    guard !overflow else { throw BudgetError.overflow }
    totals[category] = sum
  }
}

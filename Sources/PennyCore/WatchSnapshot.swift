import Foundation

public struct WatchCategorySnapshot: Codable, Equatable, Sendable {
  public let category: String
  public let allocatedMinor: Int64
  public let usedMinor: Int64
  public let remainingMinor: Int64

  public init(category: CategoryResult) {
    self.category = category.category.rawValue
    self.allocatedMinor = category.allocated.minorUnits
    self.usedMinor =
      category.category == .debt || category.category == .savings
      ? category.contributed.minorUnits : category.spent.minorUnits
    self.remainingMinor = category.remaining.minorUnits
  }
}

public struct WatchTransactionSnapshot: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let amountMinor: Int64
  public let category: String
  public let kind: String
  public let note: String?
  public let day: Int
}

public struct WatchBudgetSnapshot: Codable, Equatable, Sendable {
  public let version: Int
  public let year: Int
  public let month: Int
  public let currency: String
  public let fractionDigits: Int
  public let incomeMinor: Int64
  public let categories: [WatchCategorySnapshot]
  public let recentTransactions: [WatchTransactionSnapshot]

  public init(report: MonthlyReport, entries: [LedgerEntry], year: Int, month: Int) throws {
    guard year > 0, (1...12).contains(month) else { throw BudgetError.invalidTransaction }
    version = 1
    self.year = year
    self.month = month
    currency = report.income.currency
    fractionDigits = report.income.fractionDigits
    incomeMinor = report.income.minorUnits
    categories = report.categories.map(WatchCategorySnapshot.init(category:))
    recentTransactions = entries.compactMap { entry in
      guard let date = entry.dateComponents, date.year == year, date.month == month,
        let day = date.day
      else { return nil }
      return WatchTransactionSnapshot(
        id: entry.id, amountMinor: entry.amountMinor, category: entry.category, kind: entry.kind,
        note: entry.note, day: day)
    }.suffix(5).reversed()
  }
}

public struct WatchSpendingRequest: Codable, Equatable, Sendable {
  public let id: UUID
  public let year: Int
  public let month: Int
  public let amountMinor: Int64
  public let fractionDigits: Int
  public let category: String
  public let note: String?

  public init(
    id: UUID = UUID(), year: Int, month: Int, amountMinor: Int64, fractionDigits: Int,
    category: String, note: String?
  ) {
    self.id = id
    self.year = year
    self.month = month
    self.amountMinor = amountMinor
    self.fractionDigits = fractionDigits
    self.category = category
    self.note = note
  }
}

public struct WatchSpendingReceipt: Codable, Equatable, Sendable {
  public let id: UUID
  public let saved: Bool

  public init(id: UUID, saved: Bool) {
    self.id = id
    self.saved = saved
  }
}

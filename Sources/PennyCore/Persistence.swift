import Foundation
import SwiftData

@Model
public final class BudgetMonth {
  public var id: UUID = UUID()
  public var year: Int = 0
  public var month: Int = 1
  public var mode: String = "balanced"
  public var currencyCode: String = "USD"
  public var createdAt: Date = Date.now
  public var updatedAt: Date = Date.now

  public init(year: Int, month: Int, mode: String, currencyCode: String) {
    self.year = year
    self.month = month
    self.mode = mode
    self.currencyCode = currencyCode
  }
}

@Model
public final class LedgerEntry {
  public var id: UUID = UUID()
  public var amountMinor: Int64 = 0
  public var currencyCode: String = "USD"
  public var fractionDigits: Int = 2
  public var kind: String = "spending"
  public var category: String = "needs"
  public var subcategory: String?
  public var note: String?
  public var occurredAt: Date = Date.now
  public var calendarDate: String = ""
  public var createdAt: Date = Date.now
  public var updatedAt: Date = Date.now

  public init(
    amountMinor: Int64, currencyCode: String, fractionDigits: Int, kind: String,
    category: String, occurredAt: Date = Date.now, note: String? = nil
  ) {
    self.amountMinor = amountMinor
    self.currencyCode = currencyCode
    self.fractionDigits = fractionDigits
    self.kind = kind
    self.category = category
    self.occurredAt = occurredAt
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: occurredAt)
    self.calendarDate = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    self.note = note
  }

  public var dateComponents: DateComponents? {
    guard !calendarDate.isEmpty else {
      return Calendar.current.dateComponents([.year, .month, .day], from: occurredAt)
    }
    let parts = calendarDate.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3,
      let date = Calendar.current.date(
        from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    else { return nil }
    let verified = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return verified.year == parts[0] && verified.month == parts[1] && verified.day == parts[2]
      ? verified : nil
  }

  public var transactionDate: Date {
    guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else {
      return occurredAt
    }
    return date
  }
}

@MainActor
public struct BudgetStore {
  private let context: ModelContext

  public init(context: ModelContext) {
    self.context = context
  }

  public func entries() throws -> [LedgerEntry] {
    try context.fetch(FetchDescriptor<LedgerEntry>(sortBy: [SortDescriptor(\.occurredAt)]))
  }

  public func months() throws -> [BudgetMonth] {
    try context.fetch(
      FetchDescriptor<BudgetMonth>(sortBy: [SortDescriptor(\.year), SortDescriptor(\.month)]))
  }

  public func createBudget(_ month: BudgetMonth, income: LedgerEntry) throws {
    guard try !months().contains(where: { $0.year == month.year && $0.month == month.month })
    else { throw StoreError.duplicateIdentifier }
    try validate(income)
    guard income.kind == TransactionKind.income.rawValue else { throw StoreError.invalidEntry }
    context.insert(month)
    context.insert(income)
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  public func save(_ entry: LedgerEntry) throws {
    guard try !entries().contains(where: { $0.id == entry.id }) else {
      throw StoreError.duplicateIdentifier
    }
    try validate(entry)
    context.insert(entry)
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  public func update(_ entry: LedgerEntry) throws {
    guard try entries().contains(where: { $0.id == entry.id }) else {
      throw StoreError.missingEntry
    }
    try validate(entry)
    entry.updatedAt = .now
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  public func changeMode(of month: BudgetMonth, to mode: BudgetMode) throws {
    guard try months().contains(where: { $0.id == month.id }) else {
      throw StoreError.missingBudget
    }
    month.mode = mode.rawValue
    month.updatedAt = .now
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  private func validate(_ entry: LedgerEntry) throws {
    guard let kind = TransactionKind(rawValue: entry.kind),
      let category = BudgetCategory(rawValue: entry.category),
      (0...4).contains(entry.fractionDigits), validCurrency(entry.currencyCode),
      entry.dateComponents != nil,
      entry.amountMinor > 0 || (kind == .adjustment && entry.amountMinor != 0)
    else { throw StoreError.invalidEntry }
    switch kind {
    case .income: guard category == .income else { throw StoreError.invalidEntry }
    case .savings: guard category == .savings else { throw StoreError.invalidEntry }
    case .debt: guard category == .debt else { throw StoreError.invalidEntry }
    case .spending, .refund, .adjustment:
      guard [.housing, .needs, .wants, .giving].contains(category) else {
        throw StoreError.invalidEntry
      }
    }
  }

  public func delete(_ entry: LedgerEntry) throws {
    context.delete(entry)
    do {
      try context.save()
    } catch {
      context.rollback()
      throw error
    }
  }

  private func validCurrency(_ code: String) -> Bool {
    let bytes = code.utf8
    return bytes.count == 3 && bytes.allSatisfy { (65...90).contains($0) }
  }
}

public enum StoreError: Error, Equatable {
  case duplicateIdentifier
  case invalidEntry
  case missingEntry
  case missingBudget
}

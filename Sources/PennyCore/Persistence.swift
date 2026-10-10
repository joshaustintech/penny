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
    self.note = note
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

  public func save(_ entry: LedgerEntry) throws {
    guard try !entries().contains(where: { $0.id == entry.id }) else {
      throw StoreError.duplicateIdentifier
    }
    context.insert(entry)
    try context.save()
  }

  public func delete(_ entry: LedgerEntry) throws {
    context.delete(entry)
    try context.save()
  }
}

public enum StoreError: Error, Equatable {
  case duplicateIdentifier
}

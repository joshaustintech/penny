import Foundation

public enum BudgetMode: String, CaseIterable, Sendable {
  case balanced, housingFirst

  public var allocations: [(category: String, percent: Int)] {
    switch self {
    case .balanced: [("needs", 50), ("wants", 20), ("giving", 10), ("debt", 10), ("savings", 10)]
    case .housingFirst:
      [("housing", 50), ("needs", 15), ("giving", 10), ("debt", 10), ("savings", 10), ("wants", 5)]
    }
  }
}

public struct Money: Equatable, Sendable {
  public let minorUnits: Int64
  public let currency: String
  public let fractionDigits: Int

  public init(minorUnits: Int64, currency: String, fractionDigits: Int) {
    precondition((0...4).contains(fractionDigits))
    self.minorUnits = minorUnits
    self.currency = currency
    self.fractionDigits = fractionDigits
  }

  public static func minorUnits(
    for amount: Decimal, fractionDigits: Int, allowNegative: Bool = false
  ) throws -> Int64 {
    guard amount != 0, amount > 0 || allowNegative, (0...4).contains(fractionDigits) else {
      throw BudgetError.invalidTransaction
    }
    let scaled = amount * Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    guard scaled <= Decimal(Int64.max),
      allowNegative || scaled >= 0,
      allowNegative ? scaled >= Decimal(Int64.min) : true
    else {
      throw BudgetError.overflow
    }
    var rounded = Decimal()
    var value = scaled
    NSDecimalRound(&rounded, &value, 0, .plain)
    guard rounded == scaled else { throw BudgetError.invalidTransaction }
    return NSDecimalNumber(decimal: rounded).int64Value
  }
}

public enum BudgetError: Error, Equatable {
  case invalidIncome
  case incompatibleMoney
  case invalidTransaction
  case overflow
}

public struct BudgetAllocation: Equatable, Sendable {
  public let category: String
  public let percent: Int
  public let amount: Money
}

public enum Budget {
  public static func allocate(income: [Money], mode: BudgetMode) throws -> [BudgetAllocation] {
    guard let first = income.first, first.minorUnits >= 0 else { throw BudgetError.invalidIncome }
    var total: Int64 = 0
    for amount in income {
      guard amount.minorUnits >= 0 else { throw BudgetError.invalidIncome }
      guard amount.currency == first.currency, amount.fractionDigits == first.fractionDigits else {
        throw BudgetError.incompatibleMoney
      }
      let (sum, overflow) = total.addingReportingOverflow(amount.minorUnits)
      guard !overflow else { throw BudgetError.overflow }
      total = sum
    }
    let rules = mode.allocations
    guard rules.reduce(0, { $0 + $1.percent }) == 100 else { throw BudgetError.invalidIncome }
    var shares = rules.map {
      total / 100 * Int64($0.percent) + total % 100 * Int64($0.percent) / 100
    }
    let remainder = total - shares.reduce(0, +)
    shares[0] += remainder
    return zip(rules, shares).map { rule, share in
      BudgetAllocation(
        category: rule.category, percent: rule.percent,
        amount: Money(
          minorUnits: share, currency: first.currency,
          fractionDigits: first.fractionDigits))
    }
  }
}

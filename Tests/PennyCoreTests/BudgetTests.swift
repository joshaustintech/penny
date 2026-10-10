import Testing

@testable import PennyCore

struct BudgetTests {
  @Test func modesAllocateAllIncomeWithDeterministicRounding() throws {
    let income = [Money(minorUnits: 10_001, currency: "USD", fractionDigits: 2)]
    for mode in BudgetMode.allCases {
      let result = try Budget.allocate(income: income, mode: mode)
      #expect(result.reduce(Int64(0)) { $0 + $1.amount.minorUnits } == 10_001)
      #expect(result.map(\.category) == mode.allocations.map(\.category))
    }
    let balanced = try Budget.allocate(income: income, mode: .balanced)
    #expect(balanced.map(\.amount.minorUnits) == [5001, 2000, 1000, 1000, 1000])
  }

  @Test func irregularIncomeIsSummedExactly() throws {
    let income = [
      Money(minorUnits: 12_345, currency: "USD", fractionDigits: 2),
      Money(minorUnits: 6_789, currency: "USD", fractionDigits: 2),
    ]
    let result = try Budget.allocate(income: income, mode: .housingFirst)
    #expect(result.reduce(Int64(0)) { $0 + $1.amount.minorUnits } == 19_134)
  }

  @Test func rejectsMixedCurrencies() {
    let income = [
      Money(minorUnits: 100, currency: "USD", fractionDigits: 2),
      Money(minorUnits: 100, currency: "JPY", fractionDigits: 0),
    ]
    #expect(throws: BudgetError.incompatibleMoney) {
      try Budget.allocate(income: income, mode: .balanced)
    }
  }

  @Test func rejectsNegativeEntriesAndOverflow() {
    let negative = [
      Money(minorUnits: 100, currency: "USD", fractionDigits: 2),
      Money(minorUnits: -1, currency: "USD", fractionDigits: 2),
    ]
    #expect(throws: BudgetError.invalidIncome) {
      try Budget.allocate(income: negative, mode: .balanced)
    }
    let overflow = [
      Money(minorUnits: .max, currency: "USD", fractionDigits: 2),
      Money(minorUnits: 1, currency: "USD", fractionDigits: 2),
    ]
    #expect(throws: BudgetError.overflow) {
      try Budget.allocate(income: overflow, mode: .balanced)
    }
  }
}

import AppIntents
import Foundation
import SwiftData

struct RemainingBudgetIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Get remaining budget"
  static let description = IntentDescription(
    "Reports how much remains in this month's Penny budget.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let report = try CurrentMonthReport.load() else {
      return .result(
        value: CurrentMonthReport.noBudget,
        dialog: IntentDialog(stringLiteral: CurrentMonthReport.noBudget))
    }
    let amount = CurrentMonthReport.amount(try BudgetReporting.overallRemaining(from: report))
    let answer = "You have \(amount) left in Penny this month."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct SpentBudgetIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Get monthly spending"
  static let description = IntentDescription("Reports spending recorded in Penny this month.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let report = try CurrentMonthReport.load() else {
      return .result(
        value: CurrentMonthReport.noBudget,
        dialog: IntentDialog(stringLiteral: CurrentMonthReport.noBudget))
    }
    let amount = CurrentMonthReport.amount(try BudgetReporting.overallSpent(from: report))
    let answer = "You've spent \(amount) in Penny this month."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct BudgetStatusIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Check budget status"
  static let description = IntentDescription(
    "Reports whether any Penny budget category is over budget.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let report = try CurrentMonthReport.load() else {
      return .result(
        value: CurrentMonthReport.noBudget,
        dialog: IntentDialog(stringLiteral: CurrentMonthReport.noBudget))
    }
    let answer =
      BudgetReporting.isOverBudget(from: report)
      ? "Yes. You're over budget in Penny this month."
      : "No. You're within your Penny budget this month."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct SavingsProgressIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Get savings progress"
  static let description = IntentDescription("Reports savings contributions recorded this month.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let answer = try ContributionProgress.answer(for: .savings, verb: "saved")
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct DebtProgressIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Get debt progress"
  static let description = IntentDescription("Reports debt payments recorded this month.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let answer = try ContributionProgress.answer(for: .debt, verb: "put toward debt")
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

enum BudgetCategoryParameter: String, AppEnum {
  case housing, needs, wants, giving, debt, savings

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Budget category")
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .housing: "Housing", .needs: "Needs", .wants: "Wants", .giving: "Giving",
    .debt: "Debt", .savings: "Savings",
  ]
}

struct CategoryRemainingIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Get category remaining amount"
  static let description = IntentDescription(
    "Reports remaining amount for a Penny budget category.")
  @Parameter(title: "Category") var category: BudgetCategoryParameter
  static var parameterSummary: some ParameterSummary {
    Summary("Get remaining amount for \(\.$category)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let report = try CurrentMonthReport.load() else {
      return .result(
        value: CurrentMonthReport.noBudget,
        dialog: IntentDialog(stringLiteral: CurrentMonthReport.noBudget))
    }
    guard var selected = BudgetCategory(rawValue: category.rawValue) else {
      throw BudgetError.invalidTransaction
    }
    let combinedHousing =
      selected == .housing
      && !report.categories.contains {
        $0.category == .housing
      }
    if combinedHousing { selected = .needs }
    let amount = CurrentMonthReport.amount(
      try BudgetReporting.remaining(for: selected, from: report))
    let label = combinedHousing ? "needs, including housing" : category.rawValue
    let answer = "You have \(amount) left for \(label) this month."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

enum SpendingCategoryParameter: String, AppEnum {
  case housing, needs, wants, giving

  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Spending category")
  static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
    .housing: "Housing", .needs: "Needs", .wants: "Wants", .giving: "Giving",
  ]
}

struct CategorySpentIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Get category spending"
  static let description = IntentDescription("Reports spending for a Penny category this month.")
  @Parameter(title: "Category") var category: SpendingCategoryParameter
  static var parameterSummary: some ParameterSummary {
    Summary("Get spending for \(\.$category)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let report = try CurrentMonthReport.load() else {
      return .result(
        value: CurrentMonthReport.noBudget,
        dialog: IntentDialog(stringLiteral: CurrentMonthReport.noBudget))
    }
    guard var selected = BudgetCategory(rawValue: category.rawValue) else {
      throw BudgetError.invalidTransaction
    }
    let combinedHousing =
      selected == .housing
      && !report.categories.contains {
        $0.category == .housing
      }
    if combinedHousing { selected = .needs }
    let amount = CurrentMonthReport.amount(try BudgetReporting.spent(for: selected, from: report))
    let label = combinedHousing ? "needs, including housing" : category.rawValue
    let answer = "You've spent \(amount) on \(label) this month."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

struct RecordTransactionIntent: AppIntent {
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresLocalDeviceAuthentication }
  static let title: LocalizedStringResource = "Record spending"
  static let description = IntentDescription("Records a confirmed Penny spending entry.")
  @Parameter(title: "Amount") var amount: IntentCurrencyAmount
  @Parameter(title: "What was it for") var note: String
  @Parameter(title: "Category") var category: SpendingCategoryParameter
  static var parameterSummary: some ParameterSummary {
    Summary("Record \(\.$amount) for \(\.$note) in \(\.$category)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let report = try CurrentMonthReport.load() else {
      return .result(
        value: CurrentMonthReport.noBudget,
        dialog: IntentDialog(stringLiteral: CurrentMonthReport.noBudget))
    }
    let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !note.isEmpty, note.count <= 80,
      let category = BudgetCategory(rawValue: category.rawValue)
    else { throw BudgetError.invalidTransaction }
    guard amount.currencyCode == report.income.currency else {
      throw BudgetError.incompatibleMoney
    }
    let minorUnits = try Money.minorUnits(
      for: amount.amount, fractionDigits: report.income.fractionDigits)
    let money = Money(
      minorUnits: minorUnits, currency: report.income.currency,
      fractionDigits: report.income.fractionDigits)
    let confirmation =
      "Record \(CurrentMonthReport.amount(money)) for \(note) under \(category.rawValue)?"
    if #available(iOS 18, macOS 15, *) {
      try await requestConfirmation(dialog: IntentDialog(stringLiteral: confirmation))
    } else {
      try await requestConfirmation()
    }
    try await CurrentMonthReport.save(amount: money, category: category, note: note)
    let answer = "Recorded \(CurrentMonthReport.amount(money)) for \(note)."
    return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
  }
}

private enum CurrentMonthReport {
  static let noBudget = "No Penny budget is set up for this month."

  static func load() throws -> MonthlyReport? {
    let components = Calendar.current.dateComponents([.year, .month], from: .now)
    let container = try modelContainer()
    let context = ModelContext(container)
    guard
      let month = try context.fetch(FetchDescriptor<BudgetMonth>()).first(where: {
        $0.year == components.year && $0.month == components.month
      })
    else { return nil }
    let entries = try context.fetch(FetchDescriptor<LedgerEntry>()).filter {
      $0.dateComponents?.year == month.year && $0.dateComponents?.month == month.month
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = month.currencyCode
    let report = try BudgetReporting.make(
      entries: entries, currencyCode: month.currencyCode,
      fractionDigits: formatter.maximumFractionDigits,
      mode: BudgetMode(rawValue: month.mode) ?? .balanced)
    return report
  }

  @MainActor
  static func save(amount: Money, category: BudgetCategory, note: String) throws {
    let container = try modelContainer()
    let context = ModelContext(container)
    try BudgetStore(context: context).save(
      LedgerEntry(
        amountMinor: amount.minorUnits, currencyCode: amount.currency,
        fractionDigits: amount.fractionDigits, kind: TransactionKind.spending.rawValue,
        category: category.rawValue, note: note))
  }

  private static func modelContainer() throws -> ModelContainer {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self, CloudTombstone.self])
    let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  static func amount(_ money: Money) -> String {
    let scale = Decimal(sign: .plus, exponent: money.fractionDigits, significand: 1)
    return (Decimal(money.minorUnits) / scale).formatted(.currency(code: money.currency))
  }
}

private enum ContributionProgress {
  static func answer(for category: BudgetCategory, verb: String) throws -> String {
    guard let report = try CurrentMonthReport.load() else { return CurrentMonthReport.noBudget }
    let amount = CurrentMonthReport.amount(
      try BudgetReporting.contributed(for: category, from: report))
    return "You've \(verb) \(amount) this month."
  }
}

#if !os(macOS)
  struct PennyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
      AppShortcut(
        intent: RemainingBudgetIntent(),
        phrases: ["How much money do I have left in \(.applicationName) this month?"],
        shortTitle: "Remaining budget", systemImageName: "chart.pie")
      AppShortcut(
        intent: SpentBudgetIntent(),
        phrases: ["How much have I spent in \(.applicationName) this month?"],
        shortTitle: "Monthly spending", systemImageName: "dollarsign.circle")
      AppShortcut(
        intent: CategoryRemainingIntent(),
        phrases: ["How much is left for \(\.$category) in \(.applicationName) this month?"],
        shortTitle: "Category remaining", systemImageName: "chart.pie")
      AppShortcut(
        intent: CategorySpentIntent(),
        phrases: ["How much have I spent on \(\.$category) in \(.applicationName) this month?"],
        shortTitle: "Category spending", systemImageName: "dollarsign.circle")
      AppShortcut(
        intent: BudgetStatusIntent(),
        phrases: ["Am I over budget in \(.applicationName) this month?"],
        shortTitle: "Budget status", systemImageName: "checkmark.circle")
      AppShortcut(
        intent: SavingsProgressIntent(),
        phrases: ["How much have I saved with \(.applicationName) this month?"],
        shortTitle: "Savings progress", systemImageName: "banknote")
      AppShortcut(
        intent: DebtProgressIntent(),
        phrases: ["How much have I put toward debt with \(.applicationName) this month?"],
        shortTitle: "Debt progress", systemImageName: "creditcard")
      AppShortcut(
        intent: RecordTransactionIntent(),
        phrases: ["Record spending in \(.applicationName)"],
        shortTitle: "Record spending", systemImageName: "plus.circle")
    }
  }
#endif

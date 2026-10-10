import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var context
  @State private var months: [BudgetMonth] = []
  @State private var entries: [LedgerEntry] = []
  @State private var selectedMode = BudgetMode.balanced
  @State private var income: Decimal = 0
  @State private var saveError: String?

  private var currentComponents: DateComponents {
    Calendar.current.dateComponents([.year, .month], from: .now)
  }

  private var currentBudget: BudgetMonth? {
    months.first { $0.year == currentComponents.year && $0.month == currentComponents.month }
  }

  private var currency: String {
    currentBudget?.currencyCode ?? (Locale.current.currency?.identifier ?? "USD")
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Every penny has a purpose.")
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)
          if let currentBudget { overview(currentBudget) } else { setup }
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding()
        .frame(maxWidth: .infinity, alignment: .top)
      }
      .navigationTitle("Penny")
      .tint(Color(red: 0.16, green: 0.43, blue: 0.34))
      .task { loadBudget() }
    }
    .alert(
      "Could not save budget",
      isPresented: Binding(
        get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    ) {
      Button("OK") { saveError = nil }
    } message: {
      Text(saveError ?? "Try again.")
    }
  }

  private var setup: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Start with take-home income. Penny will give every dollar a clear place.")
        .foregroundStyle(.secondary)
      Picker("Budget style", selection: $selectedMode) {
        Text("Balanced").tag(BudgetMode.balanced)
        Text("Housing First").tag(BudgetMode.housingFirst)
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("budgetModePicker")
      Text(
        selectedMode == .balanced
          ? "50% needs · 20% wants · 10% giving · 10% debt · 10% savings"
          : "50% housing · 15% needs · 10% giving · 10% debt · 10% savings · 5% wants"
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 12) {
        Text("Monthly take-home income")
          .font(.headline)
        TextField("Income", value: $income, format: .currency(code: currency))
          #if os(iOS)
            .keyboardType(.decimalPad)
          #endif
          .accessibilityHint("Enter income after taxes")
          .accessibilityIdentifier("incomeField")
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
      Button("Create my budget", action: saveBudget)
        .buttonStyle(.borderedProminent)
        .disabled(minorIncome == nil)
        .accessibilityIdentifier("createBudgetButton")
    }
  }

  private func overview(_ budget: BudgetMonth) -> some View {
    let mode = BudgetMode(rawValue: budget.mode) ?? .balanced
    let monthIncome = entries.filter {
      $0.kind == "income"
        && Calendar.current.isDate($0.occurredAt, equalTo: .now, toGranularity: .month)
    }
    let amounts = try? Budget.allocate(
      income: monthIncome.map {
        Money(
          minorUnits: $0.amountMinor, currency: $0.currencyCode, fractionDigits: $0.fractionDigits)
      },
      mode: mode)
    let totalIncome = (amounts ?? []).reduce(Int64(0)) { $0 + $1.amount.minorUnits }
    return VStack(alignment: .leading, spacing: 18) {
      Text("Monthly take-home")
        .font(.headline)
      Text(amount(Int(totalIncome)))
        .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
      Label(mode == .balanced ? "Balanced" : "Housing First", systemImage: "circle.grid.2x2")
        .foregroundStyle(.secondary)
      Divider()
      Text("Your monthly plan")
        .font(.title2.bold())
      ForEach(amounts ?? [], id: \.category) { item in
        HStack {
          Text(item.category.capitalized)
          Spacer()
          Text(amount(Int(item.amount.minorUnits)))
            .monospacedDigit()
          Text("\(item.percent)%")
            .foregroundStyle(.secondary)
            .frame(width: 48, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  private var fractionDigits: Int {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.maximumFractionDigits
  }

  private var minorIncome: Int64? {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    guard income > 0, income <= Decimal(Int64.max) / scale else { return nil }
    return NSDecimalNumber(decimal: income * scale).int64Value
  }

  private func amount(_ minorUnits: Int) -> String {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    let value = NSDecimalNumber(value: minorUnits).decimalValue / scale
    return value.formatted(.currency(code: currency))
  }

  private func saveBudget() {
    guard let year = currentComponents.year, let month = currentComponents.month,
      let minorIncome
    else { return }
    let budget = BudgetMonth(
      year: year, month: month, mode: selectedMode.rawValue, currencyCode: currency)
    let initialIncome = LedgerEntry(
      amountMinor: minorIncome, currencyCode: currency, fractionDigits: fractionDigits,
      kind: "income", category: "income")
    do {
      try BudgetStore(context: context).createBudget(budget, income: initialIncome)
      loadBudget()
    } catch {
      saveError = error.localizedDescription
    }
  }

  private func loadBudget() {
    do {
      let store = BudgetStore(context: context)
      months = try store.months()
      entries = try store.entries()
    } catch {
      saveError = error.localizedDescription
    }
  }
}

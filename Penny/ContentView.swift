import SwiftUI

struct ContentView: View {
  @AppStorage("budgetMode") private var savedMode = ""
  @AppStorage("monthlyIncomeMinor") private var savedIncome = 0
  @AppStorage("currencyCode") private var savedCurrency = ""
  @State private var selectedMode = BudgetMode.balanced
  @State private var income: Decimal = 0

  private var currency: String {
    savedCurrency.isEmpty ? (Locale.current.currency?.identifier ?? "USD") : savedCurrency
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Every penny has a purpose.")
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)
          if savedMode.isEmpty {
            setup
          } else {
            overview
          }
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding()
        .frame(maxWidth: .infinity, alignment: .top)
      }
      .navigationTitle("Penny")
      .tint(Color(red: 0.16, green: 0.43, blue: 0.34))
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

  private var overview: some View {
    let mode = BudgetMode(rawValue: savedMode) ?? .balanced
    let amounts = try? Budget.allocate(
      income: [
        Money(minorUnits: Int64(savedIncome), currency: currency, fractionDigits: fractionDigits)
      ],
      mode: mode)
    return VStack(alignment: .leading, spacing: 18) {
      Text("Monthly take-home")
        .font(.headline)
      Text(amount(savedIncome))
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
    guard let minorIncome, let storedIncome = Int(exactly: minorIncome) else { return }
    savedIncome = storedIncome
    savedCurrency = currency
    savedMode = selectedMode.rawValue
  }
}

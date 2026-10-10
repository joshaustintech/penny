import SwiftUI

struct PennySettingsView: View {
  @AppStorage("appearance") private var appearance = "system"
  @AppStorage("preferredCurrency") private var preferredCurrency =
    Locale.current.currency?.identifier ?? "USD"
  @AppStorage("defaultBudgetMode") private var defaultBudgetMode = BudgetMode.balanced.rawValue

  var body: some View {
    Form {
      Section {
        Picker("Appearance", selection: $appearance) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        .accessibilityIdentifier("appearancePicker")
        .accessibilityValue(appearance.capitalized)
      } header: {
        Text("Appearance").font(.title3.weight(.semibold)).foregroundStyle(.primary)
      }
      Section {
        Picker("Default budget style", selection: $defaultBudgetMode) {
          Text("Balanced").tag(BudgetMode.balanced.rawValue)
          Text("Housing First").tag(BudgetMode.housingFirst.rawValue)
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("defaultBudgetModePicker")
        .accessibilityValue(
          defaultBudgetMode == BudgetMode.housingFirst.rawValue ? "Housing First" : "Balanced")
        Picker("Preferred currency", selection: $preferredCurrency) {
          ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
            Text("\(code) — \(Locale.current.localizedString(forCurrencyCode: code) ?? code)")
              .tag(code)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("preferredCurrencyPicker")
        .accessibilityValue(preferredCurrency)
        Text("Saved months keep their current currency.")
          .font(.caption)
          .foregroundStyle(.primary)
      } header: {
        Text("New budgets").font(.title3.weight(.semibold)).foregroundStyle(.primary)
      }
      Section {
        Label("Budget data stays on this device.", systemImage: "lock.shield")
        Text("iCloud sync isn't configured yet.").foregroundStyle(.primary)
        Text("Penny uses no accounts, bank connections, ads, or analytics.")
          .foregroundStyle(.primary)
      } header: {
        Text("Privacy").font(.title3.weight(.semibold)).foregroundStyle(.primary)
      }
    }
    .formStyle(.grouped)
    .tint(.accentColor)
    .navigationTitle("Settings")
  }
}

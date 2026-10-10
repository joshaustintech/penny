import SwiftUI

struct PennySettingsView: View {
  @AppStorage("appearance") private var appearance = "system"
  @AppStorage("preferredCurrency") private var preferredCurrency =
    Locale.current.currency?.identifier ?? "USD"
  @AppStorage("defaultBudgetMode") private var defaultBudgetMode = BudgetMode.balanced.rawValue
  @AppStorage("watchSharingEnabled") private var watchSharingEnabled = false

  var body: some View {
    Form {
      Section {
        Text("Appearance").font(.headline).accessibilityAddTraits(.isHeader)
        Picker("Appearance", selection: $appearance) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        .accessibilityIdentifier("appearancePicker")
        .accessibilityValue(appearance.capitalized)
      }
      Section {
        Text("New budgets").font(.headline).accessibilityAddTraits(.isHeader)
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
      }
      Section {
        Text("Privacy").font(.headline).accessibilityAddTraits(.isHeader)
        Label(
          watchSharingEnabled
            ? "Budget data stays on your devices." : "Budget data stays on this device.",
          systemImage: "lock.shield")
        #if os(iOS)
          Toggle("Share current budget with Apple Watch", isOn: $watchSharingEnabled)
            .accessibilityIdentifier("watchSharingToggle")
          Text("Shares category balances and the five latest entries with your paired Watch.")
            .font(.caption)
        #endif
        Text("iCloud sync isn't configured yet.").foregroundStyle(.primary)
        Text("Penny uses no accounts, bank connections, ads, or analytics.")
          .foregroundStyle(.primary)
      }
    }
    .formStyle(.grouped)
    .tint(.accentColor)
    .navigationTitle("Settings")
  }
}

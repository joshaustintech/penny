import SwiftUI

struct PennySettingsView: View {
  @AppStorage("appearance") private var appearance = "system"
  @AppStorage("preferredCurrency") private var preferredCurrency =
    Locale.current.currency?.identifier ?? "USD"

  var body: some View {
    Form {
      Section("Appearance") {
        Picker("Appearance", selection: $appearance) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        .accessibilityIdentifier("appearancePicker")
        .accessibilityValue(appearance.capitalized)
      }
      Section("New budgets") {
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
          .foregroundStyle(.secondary)
      }
      Section("Privacy") {
        Label("Budget data stays on this device.", systemImage: "lock.shield")
        Text("Penny uses no accounts, bank connections, ads, or analytics.")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Settings")
  }
}

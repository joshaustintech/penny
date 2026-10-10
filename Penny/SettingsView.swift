import SwiftUI

struct PennySettingsView: View {
  @AppStorage("appearance") private var appearance = "system"

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

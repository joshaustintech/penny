import SwiftData
import SwiftUI

struct PennySettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @AppStorage("appearance") private var appearance = "system"
  @AppStorage("preferredCurrency") private var preferredCurrency =
    Locale.current.currency?.identifier ?? "USD"
  @AppStorage("defaultBudgetMode") private var defaultBudgetMode = BudgetMode.balanced.rawValue
  @AppStorage("watchSharingEnabled") private var watchSharingEnabled = false
  @AppStorage("privateCloudSyncEnabled") private var privateCloudSyncEnabled = false
  @AppStorage("privateCloudSyncError") private var cloudSyncError = ""

  var body: some View {
    Form {
      Section {
        Text("Appearance").font(.headline).accessibilityAddTraits(.isHeader)
        Picker("Appearance", selection: $appearance) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        #if os(iOS)
          .pickerStyle(.navigationLink)
        #else
          .pickerStyle(.menu)
        #endif
        .accessibilityIdentifier("appearancePicker")
        .accessibilityValue(appearance.capitalized)
      }
      Section {
        Text("New budgets").font(.headline).accessibilityAddTraits(.isHeader)
        Picker("Default budget style", selection: $defaultBudgetMode) {
          Text("Balanced").tag(BudgetMode.balanced.rawValue)
          Text("Housing First").tag(BudgetMode.housingFirst.rawValue)
        }
        #if os(iOS)
          .pickerStyle(.navigationLink)
        #else
          .pickerStyle(.menu)
        #endif
        .foregroundStyle(.primary)
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
        .foregroundStyle(.primary)
        .accessibilityIdentifier("preferredCurrencyPicker")
        .accessibilityValue(preferredCurrency)
        .accessibilityHint("Saved months keep their current currency.")
        Text("Saved months keep their current currency.")
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Section {
        Text("Privacy").font(.headline).accessibilityAddTraits(.isHeader)
        Label(
          privateCloudSyncEnabled
            ? "Budget data syncs through your private iCloud database."
            : watchSharingEnabled
              ? "Budget data stays on your devices." : "Budget data stays on this device.",
          systemImage: "lock.shield")
        Toggle("Sync with iCloud", isOn: $privateCloudSyncEnabled)
          .accessibilityIdentifier("privateCloudSyncToggle")
        Text(
          "Syncs budgets and entries with your private iCloud database. Turning it off stops this device from syncing; existing cloud copies remain."
        )
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        if !cloudSyncError.isEmpty {
          Text(cloudSyncError)
            .foregroundStyle(.red)
            .accessibilityIdentifier("privateCloudSyncError")
        }
        if privateCloudSyncEnabled {
          Button("Sync now") { Task { await refreshCloudSync() } }
        } else {
          Text("Turn on iCloud sync to sync now.")
            .foregroundStyle(.primary)
        }
        #if os(iOS)
          Toggle("Share current budget with Apple Watch", isOn: $watchSharingEnabled)
            .accessibilityIdentifier("watchSharingToggle")
          Text("Shares category balances and the five latest entries with your paired Watch.")
        #endif
        Text("Penny uses no accounts, bank connections, ads, or analytics.")
          .foregroundStyle(.primary)
      }
    }
    .formStyle(.grouped)
    .tint(.accentColor)
    .navigationTitle("Settings")
    .onChange(of: privateCloudSyncEnabled) { _, enabled in
      Task {
        if enabled {
          do {
            try await PrivateCloudSync.shared.start(context: modelContext)
            cloudSyncError = ""
          } catch {
            cloudSyncError = PrivateCloudSync.recoveryGuidance
          }
        } else {
          await PrivateCloudSync.shared.stop()
          cloudSyncError = ""
        }
      }
    }
  }

  @MainActor private func refreshCloudSync() async {
    do {
      try await PrivateCloudSync.shared.refresh(context: modelContext)
      cloudSyncError = ""
    } catch {
      cloudSyncError = PrivateCloudSync.recoveryGuidance
    }
  }
}

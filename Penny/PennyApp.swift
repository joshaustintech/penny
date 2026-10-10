import Foundation
import SwiftData
import SwiftUI

@main
struct PennyApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("appearance") private var appearance = "system"
  private let container: ModelContainer?

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let schema = Schema([BudgetMonth.self, LedgerEntry.self, CloudTombstone.self])
    if arguments.contains("--ui-testing-storage-error"), arguments.contains("--ui-testing") {
      container = nil
    } else if arguments.contains("--ui-testing") {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "penny-ui-tests.store")
      if arguments.contains("--reset-store") {
        UserDefaults.standard.removeObject(forKey: "appearance")
        UserDefaults.standard.removeObject(forKey: "preferredCurrency")
        UserDefaults.standard.removeObject(forKey: "defaultBudgetMode")
        UserDefaults.standard.removeObject(forKey: "watchSharingEnabled")
        UserDefaults.standard.removeObject(forKey: "privateCloudSyncEnabled")
        UserDefaults.standard.removeObject(forKey: "privateCloudSyncError")
        for suffix in ["", "-shm", "-wal"] {
          try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
      }
      let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
      do {
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        container = nil
      }
    } else {
      do {
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        container = nil
      }
    }
    #if os(iOS)
      if let container {
        WatchBudgetSync.shared.start { request in
          do {
            _ = try BudgetStore(context: ModelContext(container)).recordWatchSpending(request)
            NotificationCenter.default.post(name: .watchBudgetChanged, object: nil)
            return true
          } catch {
            return false
          }
        }
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      if let container {
        ContentView()
          .preferredColorScheme(
            appearance == "light" ? .light : appearance == "dark" ? .dark : nil
          )
          .modelContainer(container)
          .task { await refreshCloudSyncIfEnabled() }
          .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshCloudSyncIfEnabled() } }
          }
      } else {
        StorageUnavailableView()
        }
    }
    #if os(macOS)
      .commands {
        PennyMenuCommands()
      }
    #endif
    #if os(macOS)
      Settings {
        if let container {
          PennySettingsView().modelContainer(container)
        } else {
          StorageUnavailableView()
        }
      }
    #endif
  }

  @MainActor private func refreshCloudSyncIfEnabled() async {
    guard let container else { return }
    guard UserDefaults.standard.bool(forKey: "privateCloudSyncEnabled") else { return }
    do {
      try await PrivateCloudSync.shared.refresh(context: container.mainContext)
      UserDefaults.standard.removeObject(forKey: "privateCloudSyncError")
    } catch {
      UserDefaults.standard.set(
        PrivateCloudSync.recoveryGuidance, forKey: "privateCloudSyncError")
    }
  }
}

private struct StorageUnavailableView: View {
  var body: some View {
    ContentUnavailableView(
      "Budget Data Unavailable",
      systemImage: "externaldrive.badge.exclamationmark",
      description: Text("Penny couldn't open your saved budgets. Restart the app to try again."))
  }
}

#if os(macOS)
  struct PennyCommandActions {
    let canAddEntry: Bool
    let canExport: Bool
    let addEntry: () -> Void
    let exportMarkdown: () -> Void
    let exportCSV: () -> Void
  }

  private struct PennyCommandActionsKey: FocusedValueKey {
    typealias Value = PennyCommandActions
  }

  extension FocusedValues {
    var pennyCommandActions: PennyCommandActions? {
      get { self[PennyCommandActionsKey.self] }
      set { self[PennyCommandActionsKey.self] = newValue }
    }
  }

  private struct PennyMenuCommands: Commands {
    @FocusedValue(\.pennyCommandActions) private var actions

    var body: some Commands {
      CommandGroup(after: .newItem) {
        Button("Add Entry") { actions?.addEntry() }
          .keyboardShortcut("n", modifiers: .command)
          .disabled(actions?.canAddEntry != true)
      }
      CommandGroup(after: .saveItem) {
        Button("Export Markdown Report") { actions?.exportMarkdown() }
          .disabled(actions?.canExport != true)
        Button("Export CSV Transactions") { actions?.exportCSV() }
          .disabled(actions?.canExport != true)
      }
    }
  }
#endif

#if os(iOS)
  extension Notification.Name {
    static let watchBudgetChanged = Notification.Name("Penny.watchBudgetChanged")
  }
#endif

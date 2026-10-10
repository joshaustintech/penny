import Foundation
import SwiftData
import SwiftUI

@main
struct PennyApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("appearance") private var appearance = "system"
  private let container: ModelContainer

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let schema = Schema([BudgetMonth.self, LedgerEntry.self, CloudTombstone.self])
    if arguments.contains("--ui-testing") {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "penny-ui-tests.store")
      if arguments.contains("--reset-store") {
        UserDefaults.standard.removeObject(forKey: "appearance")
        UserDefaults.standard.removeObject(forKey: "preferredCurrency")
        UserDefaults.standard.removeObject(forKey: "defaultBudgetMode")
        UserDefaults.standard.removeObject(forKey: "watchSharingEnabled")
        UserDefaults.standard.removeObject(forKey: "privateCloudSyncEnabled")
        for suffix in ["", "-shm", "-wal"] {
          try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
      }
      let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
      do {
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        fatalError("Penny could not open the test store: \(error)")
      }
    } else {
      do {
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        fatalError("Penny could not open local storage: \(error)")
      }
    }
    #if os(iOS)
      let container = self.container
      WatchBudgetSync.shared.start { request in
        do {
          _ = try BudgetStore(context: ModelContext(container)).recordWatchSpending(request)
          NotificationCenter.default.post(name: .watchBudgetChanged, object: nil)
          return true
        } catch {
          return false
        }
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(
          appearance == "light" ? .light : appearance == "dark" ? .dark : nil
        )
        .task { await refreshCloudSyncIfEnabled() }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { Task { await refreshCloudSyncIfEnabled() } }
        }
    }
    .modelContainer(container)
    #if os(macOS)
      Settings { PennySettingsView() }
    #endif
  }

  @MainActor private func refreshCloudSyncIfEnabled() async {
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

#if os(iOS)
  extension Notification.Name {
    static let watchBudgetChanged = Notification.Name("Penny.watchBudgetChanged")
  }
#endif

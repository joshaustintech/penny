import SwiftData
import SwiftUI

@main
struct PennyTVApp: App {
  private let container: ModelContainer?
  private let seedTestBudgetForUITests: Bool

  init() {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self, CloudTombstone.self])
    let arguments = ProcessInfo.processInfo.arguments
    let uiTesting = arguments.contains("--ui-testing")
      || ProcessInfo.processInfo.environment["PENNY_UI_TESTING"] == "1"
    seedTestBudgetForUITests = uiTesting
    if uiTesting && arguments.contains("--ui-testing-storage-error") {
      UserDefaults.standard.set(false, forKey: "privateCloudSyncEnabled")
      container = nil
    } else if uiTesting {
      UserDefaults.standard.set(false, forKey: "privateCloudSyncEnabled")
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "penny-tv-ui-tests.store")
      if arguments.contains("--reset-store") {
        UserDefaults.standard.removeObject(forKey: "privateCloudSyncError")
        for suffix in ["", "-shm", "-wal"] {
          try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
      }
      do {
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        container = nil
      }
    } else {
      do {
        container = try ModelContainer(
          for: schema, configurations: [
            ModelConfiguration(schema: schema, cloudKitDatabase: .none)
          ])
      } catch {
        container = nil
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      if let container {
        TVContentView(seedTestBudgetForUITests: seedTestBudgetForUITests)
          .modelContainer(container)
      } else {
        ContentUnavailableView(
          "Budget Data Unavailable",
          systemImage: "externaldrive.badge.exclamationmark",
          description: Text("Penny couldn't open your saved budgets. Restart the app to try again."))
      }
    }
  }
}

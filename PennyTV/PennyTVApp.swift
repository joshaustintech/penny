import SwiftData
import SwiftUI

@main
struct PennyTVApp: App {
  private let container: ModelContainer
  private let seedTestBudgetForUITests: Bool

  init() {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self, CloudTombstone.self])
    let arguments = ProcessInfo.processInfo.arguments
    let uiTesting = arguments.contains("--ui-testing")
      || ProcessInfo.processInfo.environment["PENNY_UI_TESTING"] == "1"
    seedTestBudgetForUITests = uiTesting
    if uiTesting {
      UserDefaults.standard.set(false, forKey: "privateCloudSyncEnabled")
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "penny-tv-ui-tests.store")
      if arguments.contains("--reset-store") {
        for suffix in ["", "-shm", "-wal"] {
          try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
      }
      do {
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        fatalError("Penny TV could not open the test store: \(error)")
      }
    } else {
      do {
        container = try ModelContainer(
          for: schema, configurations: [
            ModelConfiguration(schema: schema, cloudKitDatabase: .none)
          ])
      } catch {
        fatalError("Penny TV could not open local storage: \(error)")
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      TVContentView(seedTestBudgetForUITests: seedTestBudgetForUITests)
    }
    .modelContainer(container)
  }
}

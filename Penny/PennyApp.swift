import Foundation
import SwiftData
import SwiftUI

@main
struct PennyApp: App {
  @AppStorage("appearance") private var appearance = "system"
  private let container: ModelContainer

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    if arguments.contains("--ui-testing") {
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "penny-ui-tests.store")
      if arguments.contains("--reset-store") {
        UserDefaults.standard.removeObject(forKey: "appearance")
        UserDefaults.standard.removeObject(forKey: "preferredCurrency")
        UserDefaults.standard.removeObject(forKey: "defaultBudgetMode")
        for suffix in ["", "-shm", "-wal"] {
          try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
      }
      let configuration = ModelConfiguration(schema: schema, url: url)
      do {
        container = try ModelContainer(for: schema, configurations: [configuration])
      } catch {
        fatalError("Penny could not open the test store: \(error)")
      }
    } else {
      do {
        container = try ModelContainer(for: schema)
      } catch {
        fatalError("Penny could not open local storage: \(error)")
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(
          appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
    }
    .modelContainer(container)
    #if os(macOS)
      Settings { PennySettingsView() }
    #endif
  }
}

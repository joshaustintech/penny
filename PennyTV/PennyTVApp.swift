import SwiftData
import SwiftUI

@main
struct PennyTVApp: App {
  private let container: ModelContainer

  init() {
    let schema = Schema([BudgetMonth.self, LedgerEntry.self])
    do {
      container = try ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)])
    } catch {
      fatalError("Penny TV could not open local storage: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      TVContentView()
    }
    .modelContainer(container)
  }
}

import SwiftData
import SwiftUI

@main
struct PennyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(for: [BudgetMonth.self, LedgerEntry.self])
  }
}

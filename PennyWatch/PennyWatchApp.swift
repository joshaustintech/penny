import Observation
import SwiftUI
import WatchConnectivity

@Observable @MainActor
final class WatchBudgetReceiver: NSObject, WCSessionDelegate {
  var snapshot: WatchBudgetSnapshot?
  var entryStatus: String?

  override init() {
    super.init()
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    snapshot = ProcessInfo.processInfo.arguments.contains("--ui-testing")
      ? Self.uiTestSnapshot() : Self.snapshot(from: session.receivedApplicationContext)
    session.activate()
  }

  nonisolated func session(
    _ session: WCSession, didReceiveApplicationContext context: [String: Any]
  ) {
    guard !ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
    let received = Self.snapshot(from: context)
    Task { @MainActor in snapshot = received }
  }

  func send(_ request: WatchSpendingRequest) {
    guard WCSession.default.activationState == .activated,
      let data = try? JSONEncoder().encode(request)
    else {
      entryStatus = "Connect to iPhone"
      return
    }
    WCSession.default.transferUserInfo(["watchSpendingRequest": data])
    entryStatus = "Queued for iPhone"
  }

  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    guard let data = userInfo["watchSpendingReceipt"] as? Data,
      let receipt = try? JSONDecoder().decode(WatchSpendingReceipt.self, from: data)
    else { return }
    Task { @MainActor in entryStatus = receipt.saved ? "Saved on iPhone" : "Could not save" }
  }

  nonisolated private static func snapshot(from context: [String: Any]) -> WatchBudgetSnapshot? {
    guard context["sharingEnabled"] as? Bool == true,
      let data = context["snapshot"] as? Data,
      let snapshot = try? JSONDecoder().decode(WatchBudgetSnapshot.self, from: data)
    else {
      UserDefaults.standard.removeObject(forKey: "watchBudgetSnapshot")
      return nil
    }
    UserDefaults.standard.set(data, forKey: "watchBudgetSnapshot")
    return snapshot
  }

  private static func uiTestSnapshot() -> WatchBudgetSnapshot? {
    let now = Date.now
    let parts = Calendar.current.dateComponents([.year, .month], from: now)
    guard let year = parts.year, let month = parts.month else { return nil }
    let income = LedgerEntry(
      amountMinor: 100_000, currencyCode: "USD", fractionDigits: 2,
      kind: "income", category: "income", occurredAt: now)
    guard let report = try? BudgetReporting.make(
      entries: [income], currencyCode: "USD", fractionDigits: 2, mode: .balanced)
    else { return nil }
    return try? WatchBudgetSnapshot(report: report, entries: [income], year: year, month: month)
  }
}

@main
struct PennyWatchApp: App {
  @State private var receiver = WatchBudgetReceiver()

  var body: some Scene {
    WindowGroup {
      WatchContentView(
        snapshot: receiver.snapshot, entryStatus: receiver.entryStatus, onSend: receiver.send)
    }
  }
}

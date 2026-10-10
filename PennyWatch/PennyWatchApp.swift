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
    snapshot = Self.snapshot(from: session.receivedApplicationContext)
    session.activate()
  }

  nonisolated func session(
    _ session: WCSession, didReceiveApplicationContext context: [String: Any]
  ) {
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

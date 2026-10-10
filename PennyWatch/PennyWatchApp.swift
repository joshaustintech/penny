import Observation
import SwiftUI
import WatchConnectivity

@Observable @MainActor
final class WatchBudgetReceiver: NSObject, WCSessionDelegate {
  var snapshot: WatchBudgetSnapshot?

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

  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  nonisolated private static func snapshot(from context: [String: Any]) -> WatchBudgetSnapshot? {
    guard context["sharingEnabled"] as? Bool == true,
      let data = context["snapshot"] as? Data
    else { return nil }
    return try? JSONDecoder().decode(WatchBudgetSnapshot.self, from: data)
  }
}

@main
struct PennyWatchApp: App {
  @State private var receiver = WatchBudgetReceiver()

  var body: some Scene {
    WindowGroup {
      WatchContentView(snapshot: receiver.snapshot)
    }
  }
}

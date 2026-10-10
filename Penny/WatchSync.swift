#if os(iOS)
  import Foundation
  import WatchConnectivity

  @MainActor
  final class WatchBudgetSync: NSObject, WCSessionDelegate {
    static let shared = WatchBudgetSync()
    private var pendingContext: [String: Any] = ["sharingEnabled": false]

    func start() {
      guard WCSession.isSupported() else { return }
      WCSession.default.delegate = self
      WCSession.default.activate()
    }

    func publish(_ snapshot: WatchBudgetSnapshot?) {
      guard UserDefaults.standard.bool(forKey: "watchSharingEnabled"), let snapshot,
        let data = try? JSONEncoder().encode(snapshot)
      else {
        pendingContext = ["sharingEnabled": false]
        transferIfReady()
        return
      }
      pendingContext = ["sharingEnabled": true, "snapshot": data]
      transferIfReady()
    }

    nonisolated func session(
      _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
      error: Error?
    ) {
      Task { @MainActor in transferIfReady() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
      session.activate()
    }

    private func transferIfReady() {
      let session = WCSession.default
      guard session.activationState == .activated, session.isWatchAppInstalled else { return }
      try? session.updateApplicationContext(pendingContext)
    }
  }
#endif

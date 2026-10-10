#if os(iOS)
  import Foundation
  import WatchConnectivity

  @MainActor
  final class WatchBudgetSync: NSObject, WCSessionDelegate {
    static let shared = WatchBudgetSync()
    private var pendingContext: [String: Any] = ["sharingEnabled": false]
    private var saveWatchEntry: ((WatchSpendingRequest) -> Bool)?

    func start(saveWatchEntry: @escaping (WatchSpendingRequest) -> Bool) {
      guard WCSession.isSupported() else { return }
      self.saveWatchEntry = saveWatchEntry
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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
      guard let data = userInfo["watchSpendingRequest"] as? Data,
        let request = try? JSONDecoder().decode(WatchSpendingRequest.self, from: data)
      else { return }
      Task { @MainActor in
        let saved =
          UserDefaults.standard.bool(forKey: "watchSharingEnabled")
          && (saveWatchEntry?(request) ?? false)
        guard
          let receipt = try? JSONEncoder().encode(
            WatchSpendingReceipt(id: request.id, saved: saved))
        else { return }
        WCSession.default.transferUserInfo(["watchSpendingReceipt": receipt])
      }
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

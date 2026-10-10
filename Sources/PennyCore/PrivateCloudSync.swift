import CloudKit
import Foundation
import SwiftData

@MainActor
public final class PrivateCloudSync: CKSyncEngineDelegate, Sendable {
  public static let shared = PrivateCloudSync()
  private let zoneID = CKRecordZone.default().zoneID
  private var context: ModelContext?
  private var engine: CKSyncEngine?
  private var observer: NSObjectProtocol?
  private var records: [CKRecord.ID: CKRecord] = [:]

  private init() {}

  public func start(context: ModelContext) async throws {
    guard engine == nil else { return }
    self.context = context
    let store = BudgetStore(context: context)
    for month in try store.months() { cache(CloudRecordCodec.record(for: month, zoneID: zoneID)) }
    for entry in try store.entries() { cache(CloudRecordCodec.record(for: entry, zoneID: zoneID)) }
    for tombstone in try store.tombstones() {
      cache(CloudRecordCodec.record(for: tombstone, zoneID: zoneID))
    }
    let savedState = UserDefaults.standard.data(forKey: "privateCloudSyncState")
    let serialization = savedState.flatMap {
      try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0)
    }
    let configuration = CKSyncEngine.Configuration(
      database: CKContainer.default().privateCloudDatabase,
      stateSerialization: serialization,
      delegate: self)
    let engine = CKSyncEngine(configuration)
    self.engine = engine
    observer = NotificationCenter.default.addObserver(
      forName: .budgetStoreDidChange, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in await self?.refreshAfterLocalChange() }
    }
    let changes = records.keys.map(CKSyncEngine.PendingRecordZoneChange.saveRecord)
    engine.state.add(pendingRecordZoneChanges: changes)
    do {
      try await engine.fetchChanges()
      try await engine.sendChanges()
    } catch {
      await engine.cancelOperations()
      if let observer { NotificationCenter.default.removeObserver(observer) }
      observer = nil
      self.engine = nil
      self.context = nil
      throw error
    }
  }

  public func stop() async {
    await engine?.cancelOperations()
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    engine = nil
    context = nil
    records.removeAll()
  }

  public func refresh(context: ModelContext) async throws {
    guard engine != nil else {
      try await start(context: context)
      return
    }
    let store = BudgetStore(context: context)
    var localRecords = try store.months().map { CloudRecordCodec.record(for: $0, zoneID: zoneID) }
    localRecords += try store.entries().map { CloudRecordCodec.record(for: $0, zoneID: zoneID) }
    localRecords += try store.tombstones().map { CloudRecordCodec.record(for: $0, zoneID: zoneID) }
    for client in localRecords {
      let id = client.recordID
      if client.recordType == CloudRecordCodec.deletionType,
        let deletedID = UUID(uuidString: client["id"] as? String ?? "")
      {
        engine?.state.add(pendingRecordZoneChanges: [
          .deleteRecord(CKRecord.ID(recordName: deletedID.uuidString, zoneID: zoneID))
        ])
      }
      guard let server = records[id] else {
        records[id] = client
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
        continue
      }
      guard let resolved = try? CloudRecordCodec.resolve(client: client, server: server) else {
        continue
      }
      records[id] = resolved
      if recordDate(resolved) > recordDate(server) {
        engine?.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
      } else if recordDate(server) >= recordDate(client) {
        try apply(resolved)
      }
    }
    try await engine?.sendChanges()
  }

  public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
    switch event {
    case .stateUpdate(let update):
      UserDefaults.standard.set(
        try? JSONEncoder().encode(update.stateSerialization), forKey: "privateCloudSyncState")
    case .fetchedRecordZoneChanges(let changes):
      for modification in changes.modifications {
        let server = modification.record
        let id = server.recordID
        let selected: CKRecord
        if let client = records[id],
          let resolved = try? CloudRecordCodec.resolve(
            client: client, server: server)
        {
          selected = resolved
          if (resolved["updatedAt"] as? Date ?? .distantPast)
            > (server["updatedAt"] as? Date ?? .distantPast)
          {
            syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
          } else {
            syncEngine.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
          }
        } else {
          selected = server
        }
        records[id] = selected
        try? apply(selected)
      }
      for deletion in changes.deletions where deletion.recordType == CloudRecordCodec.entryType {
        guard let id = UUID(uuidString: deletion.recordID.recordName) else { continue }
        let store = context.map(BudgetStore.init(context:))
        if let entry = try? store?.entries().first(where: { $0.id == id }) {
          try? store?.delete(entry)
          if let tombstone = try? store?.tombstones().first(where: { $0.id == id }) {
            let record = CloudRecordCodec.record(for: tombstone, zoneID: zoneID)
            records[record.recordID] = record
            syncEngine.state.add(
              pendingRecordZoneChanges: [.saveRecord(record.recordID)])
          }
        }
      }
      NotificationCenter.default.post(name: .cloudBudgetDidChange, object: nil)
    case .sentRecordZoneChanges(let changes):
      for failure in changes.failedRecordSaves
      where failure.error.code == .serverRecordChanged {
        guard let server = failure.error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord,
          let resolved = try? CloudRecordCodec.resolve(client: failure.record, server: server)
        else { continue }
        records[resolved.recordID] = resolved
        try? apply(resolved)
        syncEngine.state.add(
          pendingRecordZoneChanges: [.saveRecord(resolved.recordID)])
      }
    default: break
    }
  }

  public func nextRecordZoneChangeBatch(
    _ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine
  ) async -> CKSyncEngine.RecordZoneChangeBatch? {
    let records = self.records
    return await CKSyncEngine.RecordZoneChangeBatch(
      pendingChanges: syncEngine.state.pendingRecordZoneChanges,
      recordProvider: { records[$0] })
  }

  private func apply(_ record: CKRecord) throws {
    guard let context else { return }
    let store = BudgetStore(context: context)
    switch record.recordType {
    case CloudRecordCodec.deletionType:
      let tombstone = try CloudRecordCodec.tombstone(from: record)
      let deletedID = CKRecord.ID(recordName: tombstone.id.uuidString, zoneID: zoneID)
      engine?.state.add(pendingRecordZoneChanges: [.deleteRecord(deletedID)])
      if let entry = try store.entries().first(where: { $0.id == tombstone.id }) {
        try store.delete(entry)
      }
      if try !store.tombstones().contains(where: { $0.id == tombstone.id }) {
        context.insert(tombstone)
        try context.save()
      }
      if let current = try store.tombstones().first(where: { $0.id == tombstone.id }) {
        cache(CloudRecordCodec.record(for: current, zoneID: zoneID))
      }
    case CloudRecordCodec.entryType:
      let remote = try CloudRecordCodec.entry(from: record)
      guard try !store.tombstones().contains(where: { $0.id == remote.id }) else { return }
      if let local = try store.entries().first(where: { $0.id == remote.id }) {
        guard remote.updatedAt >= local.updatedAt else { return }
        local.amountMinor = remote.amountMinor
        local.currencyCode = remote.currencyCode
        local.fractionDigits = remote.fractionDigits
        local.kind = remote.kind
        local.category = remote.category
        local.subcategory = remote.subcategory
        local.note = remote.note
        local.occurredAt = remote.occurredAt
        local.calendarDate = remote.calendarDate
        local.updatedAt = remote.updatedAt
        try context.save()
      } else {
        context.insert(remote)
        try context.save()
      }
    case CloudRecordCodec.budgetType:
      let remote = try CloudRecordCodec.budget(from: record)
      if let local = try store.months().first(where: { $0.id == remote.id }) {
        guard remote.updatedAt >= local.updatedAt else { return }
        local.mode = remote.mode
        local.currencyCode = remote.currencyCode
        local.updatedAt = remote.updatedAt
      } else {
        context.insert(remote)
      }
      try context.save()
    default: return
    }
  }

  private func recordDate(_ record: CKRecord) -> Date {
    (record["updatedAt"] as? Date) ?? (record["deletedAt"] as? Date) ?? .distantPast
  }

  private func refreshAfterLocalChange() async {
    guard engine != nil, let context else { return }
    try? await refresh(context: context)
  }

  private func cache(_ record: CKRecord) { records[record.recordID] = record }
}

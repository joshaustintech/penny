import CloudKit
import Foundation
import SwiftData
import Testing

@testable import PennyCore

struct CloudRecordCodecTests {
  @MainActor @Test func budgetRecordKeepsStableIdentityAndDates() throws {
    let month = BudgetMonth(year: 2026, month: 10, mode: "balanced", currencyCode: "USD")
    month.id = try #require(UUID(uuidString: "2D4AC950-4F33-4B2B-9DAE-8EC7021E4871"))
    month.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    month.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
    let zone = CKRecordZone.ID(zoneName: "Penny", ownerName: CKCurrentUserDefaultName)

    let record = CloudRecordCodec.record(for: month, zoneID: zone)
    let decoded = try CloudRecordCodec.budget(from: record)

    #expect(record.recordID.recordName == month.id.uuidString)
    #expect(record.recordID.zoneID == zone)
    #expect(decoded.id == month.id)
    #expect(decoded.year == month.year)
    #expect(decoded.month == month.month)
    #expect(decoded.updatedAt == month.updatedAt)
  }

  @MainActor @Test func entryRecordKeepsExactMoneyAndOptionalFields() throws {
    let entry = LedgerEntry(
      amountMinor: 123_456, currencyCode: "KWD", fractionDigits: 3, kind: "spending",
      category: "needs", occurredAt: Date(timeIntervalSince1970: 1_700_000_000), note: "Rent")
    entry.id = try #require(UUID(uuidString: "B332B91A-D85C-4B5F-AEF1-8EA6FC13C2F4"))
    entry.subcategory = "housing"
    entry.calendarDate = "2023-11-14"
    let zone = CKRecordZone.ID(zoneName: "Penny", ownerName: CKCurrentUserDefaultName)

    let decoded = try CloudRecordCodec.entry(
      from: CloudRecordCodec.record(for: entry, zoneID: zone))

    #expect(decoded.id == entry.id)
    #expect(decoded.amountMinor == 123_456)
    #expect(decoded.fractionDigits == 3)
    #expect(decoded.note == "Rent")
    #expect(decoded.subcategory == "housing")
    #expect(decoded.calendarDate == "2023-11-14")
  }

  @Test func rejectsUnsupportedSchemaVersion() throws {
    let zone = CKRecordZone.ID(zoneName: "Penny", ownerName: CKCurrentUserDefaultName)
    let record = CKRecord(
      recordType: CloudRecordCodec.budgetType,
      recordID: CKRecord.ID(
        recordName: "2D4AC950-4F33-4B2B-9DAE-8EC7021E4871", zoneID: zone))
    record["id"] = record.recordID.recordName as CKRecordValue
    record["schemaVersion"] = NSNumber(value: 99)

    #expect(throws: CloudRecordCodecError.self) { try CloudRecordCodec.budget(from: record) }
  }

  @MainActor @Test func newestRecordWinsWholeRecordConflictAndTieUsesServer() throws {
    let id = try #require(UUID(uuidString: "B332B91A-D85C-4B5F-AEF1-8EA6FC13C2F4"))
    let zone = CKRecordZone.ID(zoneName: "Penny", ownerName: CKCurrentUserDefaultName)
    let serverEntry = LedgerEntry(
      amountMinor: 200, currencyCode: "USD", fractionDigits: 2, kind: "spending",
      category: "needs", note: "server")
    serverEntry.id = id
    serverEntry.updatedAt = Date(timeIntervalSince1970: 200)
    let clientEntry = LedgerEntry(
      amountMinor: 100, currencyCode: "USD", fractionDigits: 2, kind: "spending",
      category: "needs", note: "client")
    clientEntry.id = id
    clientEntry.updatedAt = Date(timeIntervalSince1970: 200)
    let server = CloudRecordCodec.record(for: serverEntry, zoneID: zone)
    let tiedClient = CloudRecordCodec.record(for: clientEntry, zoneID: zone)

    #expect(
      try CloudRecordCodec.entry(
        from: CloudRecordCodec.resolve(
          client: tiedClient, server: server)
      ).note == "server")
    clientEntry.updatedAt = Date(timeIntervalSince1970: 300)
    let newerClient = CloudRecordCodec.record(for: clientEntry, zoneID: zone)
    let resolved = try CloudRecordCodec.resolve(client: newerClient, server: server)
    #expect(try CloudRecordCodec.entry(from: resolved).amountMinor == 100)
    #expect(resolved.recordID == server.recordID)
  }

  @MainActor @Test func deletionRecordRetainsOnlyTombstoneData() throws {
    let id = try #require(UUID(uuidString: "2D4AC950-4F33-4B2B-9DAE-8EC7021E4871"))
    let deletedAt = Date(timeIntervalSince1970: 1_700_000_100)
    let tombstone = CloudTombstone(id: id, deletedAt: deletedAt)
    let zone = CKRecordZone.ID(zoneName: "Penny", ownerName: CKCurrentUserDefaultName)

    let record = CloudRecordCodec.record(for: tombstone, zoneID: zone)
    let decoded = try CloudRecordCodec.tombstone(from: record)

    #expect(record.recordType == CloudRecordCodec.deletionType)
    #expect(record.recordID.recordName != id.uuidString)
    #expect(decoded.id == id)
    #expect(decoded.deletedAt == deletedAt)
    #expect(record["amountMinor"] == nil)
    #expect(record["note"] == nil)
  }
}

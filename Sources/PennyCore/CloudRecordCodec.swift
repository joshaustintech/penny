import CloudKit
import Foundation

public enum CloudRecordCodecError: Error {
  case malformedRecord
}

public enum CloudRecordCodec {
  public static let budgetType = "PennyBudgetMonth"
  public static let entryType = "PennyLedgerEntry"
  public static let schemaVersion = 1

  public static func record(for month: BudgetMonth, zoneID: CKRecordZone.ID) -> CKRecord {
    let record = CKRecord(
      recordType: budgetType, recordID: CKRecord.ID(recordName: month.id.uuidString, zoneID: zoneID)
    )
    record["schemaVersion"] = NSNumber(value: schemaVersion)
    record["id"] = month.id.uuidString as CKRecordValue
    record["year"] = NSNumber(value: month.year)
    record["month"] = NSNumber(value: month.month)
    record["mode"] = month.mode as CKRecordValue
    record["currencyCode"] = month.currencyCode as CKRecordValue
    record["createdAt"] = month.createdAt as CKRecordValue
    record["updatedAt"] = month.updatedAt as CKRecordValue
    return record
  }

  public static func record(for entry: LedgerEntry, zoneID: CKRecordZone.ID) -> CKRecord {
    let record = CKRecord(
      recordType: entryType, recordID: CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID))
    record["schemaVersion"] = NSNumber(value: schemaVersion)
    record["id"] = entry.id.uuidString as CKRecordValue
    record["amountMinor"] = NSNumber(value: entry.amountMinor)
    record["currencyCode"] = entry.currencyCode as CKRecordValue
    record["fractionDigits"] = NSNumber(value: entry.fractionDigits)
    record["kind"] = entry.kind as CKRecordValue
    record["category"] = entry.category as CKRecordValue
    record["subcategory"] = entry.subcategory as? CKRecordValue
    record["note"] = entry.note as? CKRecordValue
    record["occurredAt"] = entry.occurredAt as CKRecordValue
    record["calendarDate"] = entry.calendarDate as CKRecordValue
    record["createdAt"] = entry.createdAt as CKRecordValue
    record["updatedAt"] = entry.updatedAt as CKRecordValue
    return record
  }

  public static func budget(from record: CKRecord) throws -> BudgetMonth {
    guard record.recordType == budgetType, valid(record),
      let id = identifier(record), let year = integer(record, "year"), (1...9999).contains(year),
      let monthNumber = integer(record, "month"), (1...12).contains(monthNumber),
      let mode = string(record, "mode"), BudgetMode(rawValue: mode) != nil,
      let currency = string(record, "currencyCode"), validCurrency(currency),
      let createdAt = date(record, "createdAt"), let updatedAt = date(record, "updatedAt")
    else { throw CloudRecordCodecError.malformedRecord }
    let month = BudgetMonth(
      year: year, month: monthNumber, mode: mode, currencyCode: currency)
    month.id = id
    month.createdAt = createdAt
    month.updatedAt = updatedAt
    return month
  }

  public static func entry(from record: CKRecord) throws -> LedgerEntry {
    guard record.recordType == entryType, valid(record),
      let id = identifier(record), let amount = record["amountMinor"] as? NSNumber,
      let currency = string(record, "currencyCode"), validCurrency(currency),
      let fractionDigits = integer(record, "fractionDigits"), (0...4).contains(fractionDigits),
      let kind = string(record, "kind"), TransactionKind(rawValue: kind) != nil,
      let category = string(record, "category"), BudgetCategory(rawValue: category) != nil,
      let occurredAt = date(record, "occurredAt"),
      let calendarDate = string(record, "calendarDate"), !calendarDate.isEmpty,
      let createdAt = date(record, "createdAt"), let updatedAt = date(record, "updatedAt")
    else { throw CloudRecordCodecError.malformedRecord }
    let entry = LedgerEntry(
      amountMinor: amount.int64Value, currencyCode: currency, fractionDigits: fractionDigits,
      kind: kind, category: category, occurredAt: occurredAt, note: string(record, "note"))
    entry.id = id
    entry.subcategory = string(record, "subcategory")
    entry.calendarDate = calendarDate
    entry.createdAt = createdAt
    entry.updatedAt = updatedAt
    return entry
  }

  private static func valid(_ record: CKRecord) -> Bool {
    integer(record, "schemaVersion") == schemaVersion
      && identifier(record)?.uuidString == record.recordID.recordName.uppercased()
  }

  private static func identifier(_ record: CKRecord) -> UUID? {
    guard let value = string(record, "id"), let id = UUID(uuidString: value) else { return nil }
    return id
  }

  private static func integer(_ record: CKRecord, _ key: String) -> Int? {
    (record[key] as? NSNumber)?.intValue
  }

  private static func string(_ record: CKRecord, _ key: String) -> String? {
    record[key] as? String
  }

  private static func date(_ record: CKRecord, _ key: String) -> Date? {
    record[key] as? Date
  }

  private static func validCurrency(_ code: String) -> Bool {
    let bytes = code.utf8
    return bytes.count == 3 && bytes.allSatisfy { (65...90).contains($0) }
  }
}

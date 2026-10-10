import SwiftData
import SwiftUI

struct EntryForm: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var kind = TransactionKind.spending
  @State private var category = BudgetCategory.needs
  @State private var amount: Decimal = 0
  @State private var date = Date.now
  @State private var note = ""
  @State private var errorMessage: String?

  let mode: BudgetMode
  let currency: String
  let existingEntry: LedgerEntry?
  let onSave: () -> Void

  init(
    mode: BudgetMode, currency: String, monthDate: Date = .now,
    existingEntry: LedgerEntry? = nil,
    onSave: @escaping () -> Void
  ) {
    self.mode = mode
    self.currency = currency
    self.existingEntry = existingEntry
    self.onSave = onSave
    _date = State(initialValue: monthDate)
    if let existingEntry {
      let scale = Decimal(sign: .plus, exponent: existingEntry.fractionDigits, significand: 1)
      _kind = State(initialValue: TransactionKind(rawValue: existingEntry.kind) ?? .spending)
      _category = State(initialValue: BudgetCategory(rawValue: existingEntry.category) ?? .needs)
      _amount = State(
        initialValue: NSDecimalNumber(value: existingEntry.amountMinor).decimalValue / scale)
      _date = State(initialValue: existingEntry.transactionDate)
      _note = State(initialValue: existingEntry.note ?? "")
    }
  }

  private var categories: [BudgetCategory] {
    let available: [BudgetCategory]
    switch kind {
    case .income: available = [.income]
    case .savings: available = [.savings]
    case .debt: available = [.debt]
    default:
      available = mode.allocations.compactMap { BudgetCategory(rawValue: $0.category) }
        .filter { ![.debt, .savings].contains($0) }
    }
    guard let existingEntry, let original = BudgetCategory(rawValue: existingEntry.category),
      !available.contains(original)
    else { return available }
    return [original] + available
  }

  private var fractionDigits: Int {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.maximumFractionDigits
  }

  private var minorAmount: Int64? {
    try? Money.minorUnits(
      for: amount, fractionDigits: fractionDigits, allowNegative: kind == .adjustment)
  }

  var body: some View {
    NavigationStack {
      Form {
        Picker("Entry type", selection: $kind) {
          Text("Spending").tag(TransactionKind.spending)
          Text("Income").tag(TransactionKind.income)
          Text("Savings").tag(TransactionKind.savings)
          Text("Debt payment").tag(TransactionKind.debt)
          Text("Refund").tag(TransactionKind.refund)
          Text("Adjustment").tag(TransactionKind.adjustment)
        }
        Picker("Category", selection: $category) {
          ForEach(categories, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        TextField(
          "Amount (\(currency))", value: $amount,
          format: .number.precision(.fractionLength(0...fractionDigits))
        )
        #if os(iOS)
          .keyboardType(.decimalPad)
        #endif
        .accessibilityIdentifier("entryAmountField")
        DatePicker("Date", selection: $date, displayedComponents: .date)
        TextField("Note (optional)", text: $note)
      }
      .navigationTitle(existingEntry == nil ? "Add entry" : "Edit entry")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(existingEntry == nil ? "Save" : "Update", action: save)
            .disabled(minorAmount == nil)
            .accessibilityIdentifier("saveEntryButton")
        }
      }
    }
    .onChange(of: kind) { category = categories.first ?? .needs }
    .alert(
      "Could not save entry",
      isPresented: Binding(
        get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    ) {
      Button("OK") { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "Try again.")
    }
  }

  private func save() {
    guard let minorAmount else { return }
    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      let store = BudgetStore(context: context)
      if let existingEntry {
        existingEntry.amountMinor = minorAmount
        existingEntry.currencyCode = currency
        existingEntry.fractionDigits = fractionDigits
        existingEntry.kind = kind.rawValue
        existingEntry.category = category.rawValue
        existingEntry.occurredAt = date
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        existingEntry.calendarDate = "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
        existingEntry.note = trimmedNote.isEmpty ? nil : trimmedNote
        try store.update(existingEntry)
      } else {
        try store.save(
          LedgerEntry(
            amountMinor: minorAmount, currencyCode: currency, fractionDigits: fractionDigits,
            kind: kind.rawValue, category: category.rawValue, occurredAt: date,
            note: trimmedNote.isEmpty ? nil : trimmedNote))
      }
      onSave()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

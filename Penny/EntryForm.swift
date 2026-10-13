import SwiftData
import SwiftUI

struct EntryForm: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @FocusState private var fieldFocused: Bool
  @State private var kind = TransactionKind.spending
  @State private var category = BudgetCategory.needs
  @State private var amount = ""
  @State private var subtractAdjustment = false
  @State private var date = Date.now
  @State private var note = ""
  @State private var errorMessage: String?

  let mode: BudgetMode
  let currency: String
  let monthDate: Date
  let existingEntry: LedgerEntry?
  let usesSpaciousKeyboard: Bool
  let onSave: () -> Void

  private var monthRange: ClosedRange<Date> {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: monthDate)
    let start = calendar.date(from: components) ?? monthDate
    let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
    return start...next.addingTimeInterval(-1)
  }

  init(
    mode: BudgetMode, currency: String, monthDate: Date = .now,
    existingEntry: LedgerEntry? = nil, usesSpaciousKeyboard: Bool = false,
    onSave: @escaping () -> Void
  ) {
    self.mode = mode
    self.currency = currency
    self.monthDate = monthDate
    self.existingEntry = existingEntry
    self.usesSpaciousKeyboard = usesSpaciousKeyboard
    self.onSave = onSave
    _date = State(initialValue: monthDate)
    _subtractAdjustment = State(initialValue: (existingEntry?.amountMinor ?? 0) < 0)
    if let existingEntry {
      let scale = Decimal(sign: .plus, exponent: existingEntry.fractionDigits, significand: 1)
      _kind = State(initialValue: TransactionKind(rawValue: existingEntry.kind) ?? .spending)
      _category = State(initialValue: BudgetCategory(rawValue: existingEntry.category) ?? .needs)
      let value = NSDecimalNumber(value: existingEntry.amountMinor).decimalValue / scale
      _amount = State(initialValue: value.formatted(.number.grouping(.never)
        .precision(.fractionLength(0...existingEntry.fractionDigits))))
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
    let input = amount.trimmingCharacters(in: .whitespacesAndNewlines)
    let separator = NSRegularExpression.escapedPattern(for: Locale.current.decimalSeparator ?? ".")
    let pattern = "^[+-]?(?:[0-9]+(?:\(separator)[0-9]*)?|\(separator)[0-9]+)$"
    guard input.range(of: pattern, options: .regularExpression) != nil,
      let value = Decimal(string: input, locale: .current) else { return nil }
    let enteredAmount = value < 0 ? -value : value
    let signedAmount = kind == .adjustment && subtractAdjustment ? -enteredAmount : enteredAmount
    return try? Money.minorUnits(
      for: signedAmount, fractionDigits: fractionDigits, allowNegative: kind == .adjustment)
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
        .accessibilityIdentifier("entryKindPicker")
        Picker("Category", selection: $category) {
          ForEach(categories, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        TextField("Amount (\(currency))", text: $amount)
        #if os(iOS)
          .keyboardType(usesSpaciousKeyboard ? .numbersAndPunctuation : .decimalPad)
        #endif
        .focused($fieldFocused)
        .accessibilityIdentifier("entryAmountField")
        if kind == .adjustment {
          Toggle("Subtract from category total", isOn: $subtractAdjustment)
            .accessibilityIdentifier("subtractAdjustmentToggle")
        }
        DatePicker("Date", selection: $date, in: monthRange, displayedComponents: .date)
          .accessibilityHint("Choose a date in the selected budget month")
        TextField("Note (optional)", text: $note)
          .focused($fieldFocused)
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
        #if os(iOS)
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { fieldFocused = false }
          }
        #endif
      }
    }
    .onChange(of: kind) {
      category = categories.first ?? .needs
      if kind != .adjustment { subtractAdjustment = false }
    }
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
      fieldFocused = false
      onSave()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#Preview("New entry") {
  EntryForm(mode: .balanced, currency: "USD", onSave: {})
    .modelContainer(
      for: [BudgetMonth.self, LedgerEntry.self, CloudTombstone.self], inMemory: true)
}

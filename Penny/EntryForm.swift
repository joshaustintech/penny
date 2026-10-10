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
  let onSave: () -> Void

  private var categories: [BudgetCategory] {
    switch kind {
    case .income: return [.income]
    case .savings: return [.savings]
    case .debt: return [.debt]
    default:
      return mode.allocations.compactMap { BudgetCategory(rawValue: $0.category) }
        .filter { ![.debt, .savings].contains($0) }
    }
  }

  private var fractionDigits: Int {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.maximumFractionDigits
  }

  private var minorAmount: Int64? {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    guard amount > 0, amount <= Decimal(Int64.max) / scale else { return nil }
    return NSDecimalNumber(decimal: amount * scale).int64Value
  }

  var body: some View {
    NavigationStack {
      Form {
        Picker("Entry type", selection: $kind) {
          Text("Spending").tag(TransactionKind.spending)
          Text("Income").tag(TransactionKind.income)
          Text("Savings").tag(TransactionKind.savings)
          Text("Debt payment").tag(TransactionKind.debt)
        }
        Picker("Category", selection: $category) {
          ForEach(categories, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        TextField("Amount", value: $amount, format: .currency(code: currency))
          #if os(iOS)
            .keyboardType(.decimalPad)
          #endif
        DatePicker("Date", selection: $date, displayedComponents: .date)
        TextField("Note (optional)", text: $note)
      }
      .navigationTitle("Add entry")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
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
    let entry = LedgerEntry(
      amountMinor: minorAmount, currencyCode: currency, fractionDigits: fractionDigits,
      kind: kind.rawValue, category: category.rawValue, occurredAt: date,
      note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note)
    do {
      try BudgetStore(context: context).save(entry)
      onSave()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

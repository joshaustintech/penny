import SwiftUI

struct WatchContentView: View {
  let snapshot: WatchBudgetSnapshot?
  let entryStatus: String?
  let onSend: (WatchSpendingRequest) -> Void
  @State private var showingEntry = false

  var body: some View {
    Group {
      if let snapshot {
        dashboard(snapshot)
          .safeAreaInset(edge: .bottom) {
            Button("Add spending") { showingEntry = true }
              .buttonStyle(.borderedProminent)
          }
          .sheet(isPresented: $showingEntry) {
            WatchSpendingForm(snapshot: snapshot, onSend: onSend)
          }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "iphone.and.arrow.forward")
            .font(.title2)
            .foregroundStyle(.tint)
          Text("Share a budget from Penny on iPhone.")
            .multilineTextAlignment(.center)
        }
        .padding()
      }
    }
  }

  private func dashboard(_ snapshot: WatchBudgetSnapshot) -> some View {
    let remaining = snapshot.categories.reduce(Int64.zero) { $0 + $1.remainingMinor }
    return List {
      Section {
        if let entryStatus { Text(entryStatus).font(.caption).foregroundStyle(.secondary) }
        Text(money(remaining, snapshot))
          .font(.title2.bold().monospacedDigit())
        Text("Left in plan")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Categories") {
        ForEach(snapshot.categories, id: \.category) { category in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(category.category.capitalized)
              Spacer(minLength: 4)
              Text(money(category.remainingMinor, snapshot)).monospacedDigit()
            }
            if category.allocatedMinor > 0 {
              ProgressView(
                value: min(max(Double(category.usedMinor) / Double(category.allocatedMinor), 0), 1))
              Text(
                "\(money(category.usedMinor, snapshot)) of \(money(category.allocatedMinor, snapshot))"
              )
              .font(.caption2)
              .foregroundStyle(.secondary)
            }
          }
        }
      }
      if !snapshot.recentTransactions.isEmpty {
        Section("Recent") {
          ForEach(snapshot.recentTransactions) { transaction in
            VStack(alignment: .leading, spacing: 2) {
              Text(transaction.note ?? transaction.category.capitalized)
                .lineLimit(1)
              Text("\(transaction.category.capitalized) · \(transaction.day)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  private struct WatchSpendingForm: View {
    let snapshot: WatchBudgetSnapshot
    let onSend: (WatchSpendingRequest) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var category = "needs"
    @State private var note = ""

    private var amountMinor: Int64? {
      guard let value = Decimal(string: amount, locale: .current) else { return nil }
      return try? Money.minorUnits(for: value, fractionDigits: snapshot.fractionDigits)
    }

    var body: some View {
      NavigationStack {
        Form {
          TextField("Amount (\(snapshot.currency))", text: $amount)
          Picker("Category", selection: $category) {
            ForEach(
              snapshot.categories.filter {
                ["housing", "needs", "wants", "giving"].contains($0.category)
              }, id: \.category
            ) { item in
              Text(item.category.capitalized).tag(item.category)
            }
          }
          TextField("Note", text: $note)
          Button("Send to iPhone") { send() }
            .disabled(amountMinor == nil)
        }
        .navigationTitle("New spending")
      }
    }

    private func send() {
      guard let amountMinor else { return }
      onSend(
        WatchSpendingRequest(
          year: snapshot.year, month: snapshot.month, amountMinor: amountMinor,
          fractionDigits: snapshot.fractionDigits, category: category,
          note: String(note.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)))
      dismiss()
    }
  }

  private func money(_ minor: Int64, _ snapshot: WatchBudgetSnapshot) -> String {
    let scale = Decimal(sign: .plus, exponent: snapshot.fractionDigits, significand: 1)
    return (Decimal(minor) / scale).formatted(.currency(code: snapshot.currency))
  }
}

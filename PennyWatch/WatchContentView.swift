import SwiftUI

struct WatchContentView: View {
  let snapshot: WatchBudgetSnapshot?

  var body: some View {
    Group {
      if let snapshot {
        dashboard(snapshot)
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

  private func money(_ minor: Int64, _ snapshot: WatchBudgetSnapshot) -> String {
    let scale = Decimal(sign: .plus, exponent: snapshot.fractionDigits, significand: 1)
    return (Decimal(minor) / scale).formatted(.currency(code: snapshot.currency))
  }
}

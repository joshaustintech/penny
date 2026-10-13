import SwiftUI

struct BudgetOverviewHeader: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let income: String
  let spent: String
  let remaining: String
  let isOverspent: Bool

  private var metricLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
      : AnyLayout(HStackLayout(alignment: .top, spacing: 32))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 6) {
        Label(
          isOverspent ? "Over monthly plan" : "Left in plan",
          systemImage: isOverspent ? "exclamationmark.circle" : "circle.lefthalf.filled")
          .font(.headline)
        Text(remaining)
          .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
          .foregroundStyle(isOverspent ? Color.red : Color.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("remainingPlanSummary")

      Divider()
      metricLayout {
        VStack(alignment: .leading, spacing: 4) {
          Text("Monthly take-home").font(.subheadline).foregroundStyle(.primary)
          Text(income).font(.title3.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Income")
        .accessibilityValue(income)
        VStack(alignment: .leading, spacing: 4) {
          Text("Actual spending").font(.subheadline).foregroundStyle(.primary)
          Text(spent).font(.title3.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("actualSpendingSummary")
      }
    }
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

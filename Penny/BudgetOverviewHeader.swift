import SwiftUI

struct BudgetOverviewHeader: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var availableWidth = 0.0
  @ScaledMetric(relativeTo: .largeTitle) private var desktopAmountSize = 42
  let income: String
  let spent: String
  let remaining: String
  let isOverspent: Bool

  private var isWide: Bool {
    availableWidth >= 680 && !dynamicTypeSize.isAccessibilitySize
  }

  private var headerLayout: AnyLayout {
    isWide
      ? AnyLayout(HStackLayout(alignment: .center, spacing: 40))
      : AnyLayout(VStackLayout(alignment: .leading, spacing: 20))
  }

  private var amountFont: Font {
    #if os(macOS)
      .system(size: desktopAmountSize, weight: .bold, design: .rounded)
    #else
      .system(.largeTitle, design: .rounded).bold()
    #endif
  }

  private var metricLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
      : AnyLayout(HStackLayout(alignment: .top, spacing: 32))
  }

  var body: some View {
    headerLayout {
      VStack(alignment: .leading, spacing: 6) {
        Label(
          isOverspent ? "Over monthly plan" : "Left in plan",
          systemImage: isOverspent ? "exclamationmark.circle" : "circle.lefthalf.filled")
          .font(.headline)
        Text(remaining)
          .font(amountFont.monospacedDigit())
          .foregroundStyle(isOverspent ? Color.red : Color.primary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("remainingPlanSummary")
      .frame(maxWidth: .infinity, alignment: .leading)

      if !isWide { Divider() }
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
    .frame(maxWidth: .infinity, alignment: .leading)
    .onGeometryChange(for: Double.self) { Double($0.size.width) } action: { availableWidth = $0 }
  }
}

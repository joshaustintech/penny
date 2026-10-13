import SwiftUI

struct BudgetCategoryRow: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let item: CategoryResult

  private var isContribution: Bool {
    item.category == .debt || item.category == .savings
  }

  private var used: Money { isContribution ? item.contributed : item.spent }

  private var status: String? {
    if item.remaining.minorUnits < 0 {
      return isContribution ? "Above planned contribution" : "Over budget"
    }
    guard item.allocated.minorUnits > 0 else { return nil }
    if isContribution {
      return used.minorUnits >= item.allocated.minorUnits ? "Plan complete" : nil
    }
    return used.minorUnits >= item.allocated.minorUnits - item.allocated.minorUnits / 5
      ? "Near limit" : nil
  }

  private var icon: String {
    switch item.category {
    case .housing: "house"
    case .needs: "basket"
    case .wants: "sparkles"
    case .giving: "heart"
    case .debt: "creditcard"
    case .savings: "leaf"
    case .income: "banknote"
    }
  }

  private var headingLayout: AnyLayout {
    dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      headingLayout {
        Label(item.category.rawValue.capitalized, systemImage: icon)
          .fixedSize(horizontal: false, vertical: true)
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 12) }
        Text(amount(item.remaining)).monospacedDigit()
          .fixedSize(horizontal: false, vertical: true)
      }
      .font(.headline)
      if item.allocated.minorUnits > 0 {
        ProgressView(
          value: min(max(Double(used.minorUnits) / Double(item.allocated.minorUnits), 0), 1))
          .tint(item.remaining.minorUnits < 0 ? .red : .accentColor)
          .accessibilityHidden(true)
      }
      Text(
        "\(amount(used)) \(isContribution ? "contributed" : "spent") of \(amount(item.allocated)) · \(item.percent)%")
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
      if let status {
        Label(
          status, systemImage: item.remaining.minorUnits < 0
            ? "exclamationmark.circle.fill" : isContribution ? "checkmark.circle" : "hourglass")
          .font(.subheadline)
      }
    }
    .foregroundStyle(.primary)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) {
      Rectangle().fill(.primary.opacity(0.15)).frame(height: 1).accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("budgetCategory-\(item.category.rawValue)")
    .accessibilityLabel("\(item.category.rawValue.capitalized), \(amount(item.remaining)) remaining")
    .accessibilityValue(
      "\(amount(used)) used of \(amount(item.allocated)), \(item.percent)% of income\(status.map { ", \($0)" } ?? "")")
  }

  private func amount(_ money: Money) -> String {
    let scale = Decimal(sign: .plus, exponent: money.fractionDigits, significand: 1)
    return (Decimal(money.minorUnits) / scale).formatted(.currency(code: money.currency))
  }
}

import Charts
import SwiftData
import SwiftUI

struct TVContentView: View {
  @Query(sort: \BudgetMonth.year, order: .reverse) private var months: [BudgetMonth]
  @Query private var entries: [LedgerEntry]
  @FocusState private var focusedCategory: String?

  private var currentMonth: BudgetMonth? {
    let date = Calendar.current.dateComponents([.year, .month], from: .now)
    return months.first { $0.year == date.year && $0.month == date.month }
  }

  private var currentReport: MonthlyReport? {
    guard let month = currentMonth else { return nil }
    return report(for: month)
  }

  var body: some View {
    NavigationStack {
      Group {
        if let month = currentMonth, let report = currentReport {
          dashboard(month, report)
        } else {
          ContentUnavailableView(
            "No local budget", systemImage: "chart.bar.xaxis",
            description: Text(
              "Penny TV is ready for the private iCloud sync option. Sync is not enabled yet."))
        }
      }
      .navigationTitle("Penny")
    }
  }

  private func dashboard(_ month: BudgetMonth, _ report: MonthlyReport) -> some View {
    let remaining = try? BudgetReporting.overallRemaining(from: report)
    let remainingText =
      remaining.map {
        money($0.minorUnits, month.currencyCode, report.income.fractionDigits)
      } ?? "Unavailable"
    return ScrollView {
      VStack(alignment: .leading, spacing: 36) {
        HStack(spacing: 48) {
          VStack(alignment: .leading, spacing: 10) {
            Text(monthLabel(month)).font(.title2).foregroundStyle(.secondary)
            Text("Left in plan").font(.title3)
            Text(remainingText)
              .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
              .accessibilityLabel("Remaining budget, \(remainingText)")
          }
          categoryChart(report, month)
        }
        VStack(alignment: .leading, spacing: 16) {
          Text("Categories").font(.title2.bold())
          ScrollView(.horizontal) {
            HStack(spacing: 20) {
              ForEach(report.categories, id: \.category) { category in
                categoryCard(category, month, report.income.fractionDigits)
                  .focused($focusedCategory, equals: category.category.rawValue)
                  .focusable()
              }
            }
            .padding(12)
          }
        }
        historicalChart(currencyCode: month.currencyCode)
      }
      .padding(.horizontal, 72)
      .padding(.vertical, 36)
    }
  }

  private func categoryChart(_ report: MonthlyReport, _ month: BudgetMonth) -> some View {
    Chart(report.categories, id: \.category) { category in
      BarMark(
        x: .value("Category", category.category.rawValue.capitalized),
        y: .value("Used", used(category).minorUnits)
      )
      .foregroundStyle(.orange.gradient)
    }
    .chartYAxisLabel("Used")
    .frame(height: 260)
    .accessibilityLabel("Current category spending")
  }

  private func categoryCard(
    _ category: CategoryResult, _ month: BudgetMonth, _ fractionDigits: Int
  ) -> some View {
    let value = used(category).minorUnits
    return VStack(alignment: .leading, spacing: 12) {
      Text(category.category.rawValue.capitalized).font(.title3.bold())
      Text(money(category.remaining.minorUnits, month.currencyCode, fractionDigits))
        .font(.title2.monospacedDigit())
      ProgressView(
        value: min(max(Double(value) / Double(max(category.allocated.minorUnits, 1)), 0), 1))
      Text("\(money(value, month.currencyCode, fractionDigits)) used")
        .font(.callout).foregroundStyle(.secondary)
    }
    .frame(width: 280, height: 160, alignment: .leading)
    .padding(24)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .scaleEffect(focusedCategory == category.category.rawValue ? 1.06 : 1)
    .animation(.easeOut(duration: 0.15), value: focusedCategory)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(category.category.rawValue) remaining \(money(category.remaining.minorUnits, month.currencyCode, fractionDigits))"
    )
  }

  private func historicalChart(currencyCode: String) -> some View {
    let history = months.filter { $0.currencyCode == currencyCode }
      .sorted { ($0.year, $0.month) < ($1.year, $1.month) }.suffix(6)
      .compactMap { month -> (label: String, income: Int64, spending: Int64)? in
        guard let report = report(for: month),
          let spending = try? BudgetReporting.overallSpent(from: report)
        else { return nil }
        return (monthLabel(month), report.income.minorUnits, spending.minorUnits)
      }
    return VStack(alignment: .leading, spacing: 12) {
      Text("Monthly comparison").font(.title2.bold())
      Chart {
        ForEach(Array(history.enumerated()), id: \.offset) { _, point in
          BarMark(x: .value("Month", point.label), y: .value("Income", point.income))
            .position(by: .value("Series", "Income"))
          BarMark(x: .value("Month", point.label), y: .value("Spending", point.spending))
            .position(by: .value("Series", "Spending"))
        }
      }
      .chartForegroundStyleScale(["Income": .blue, "Spending": .orange])
      .frame(height: 250)
      .accessibilityLabel("Income and spending across recent months")
    }
  }

  private func report(for month: BudgetMonth) -> MonthlyReport? {
    let items = entries.filter {
      $0.dateComponents?.year == month.year && $0.dateComponents?.month == month.month
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = month.currencyCode
    return try? BudgetReporting.make(
      entries: items, currencyCode: month.currencyCode,
      fractionDigits: formatter.maximumFractionDigits,
      mode: BudgetMode(rawValue: month.mode) ?? .balanced)
  }

  private func used(_ category: CategoryResult) -> Money {
    category.category == .debt || category.category == .savings
      ? category.contributed : category.spent
  }

  private func monthLabel(_ month: BudgetMonth) -> String {
    "\(month.month)/\(month.year)"
  }

  private func money(_ minor: Int64, _ currency: String, _ fractionDigits: Int) -> String {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    return (Decimal(minor) / scale).formatted(.currency(code: currency))
  }
}

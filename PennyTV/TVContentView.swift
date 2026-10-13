import Charts
import SwiftData
import SwiftUI

struct TVContentView: View {
  let seedTestBudgetForUITests: Bool
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage("privateCloudSyncEnabled") private var privateCloudSyncEnabled = false
  @AppStorage("privateCloudSyncError") private var cloudSyncError = ""
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
            "No budget on Apple TV", systemImage: "chart.bar.xaxis",
            description: Text(
              "Create a budget on iPhone, iPad, or Mac, then turn on iCloud sync in Settings."
            ))
        }
      }
      .navigationTitle("Penny")
      .toolbar {
        NavigationLink("Settings") { settings }
      }
    }
    .task {
      if seedTestBudgetForUITests {
        do {
          try seedTestBudget()
        } catch {
          fatalError("Penny TV could not seed UI test data: \(error)")
        }
      }
      await refreshCloudSync()
    }
    .onChange(of: privateCloudSyncEnabled) { _, enabled in
      Task {
        if enabled {
          await refreshCloudSync()
        } else {
          await PrivateCloudSync.shared.stop()
          cloudSyncError = ""
        }
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await refreshCloudSync() } }
    }
  }

  private var settings: some View {
    Form {
      Section("Privacy") {
        Toggle("Sync with iCloud", isOn: $privateCloudSyncEnabled)
          .accessibilityIdentifier("privateCloudSyncToggle")
        Text(
          "Syncs budgets and entries with your private iCloud database. Turning it off stops this device from syncing; existing cloud copies remain."
        )
        if !cloudSyncError.isEmpty {
          Text(cloudSyncError)
            .foregroundStyle(.red)
            .accessibilityIdentifier("privateCloudSyncError")
        }
        Button("Sync now") { Task { await refreshCloudSync() } }
          .disabled(!privateCloudSyncEnabled)
      }
    }
    .navigationTitle("Settings")
  }

  @MainActor private func refreshCloudSync() async {
    guard privateCloudSyncEnabled else { return }
    do {
      try await PrivateCloudSync.shared.refresh(context: modelContext)
      cloudSyncError = ""
    } catch {
      cloudSyncError = PrivateCloudSync.recoveryGuidance
    }
  }

  @MainActor private func seedTestBudget() throws {
    guard try modelContext.fetch(FetchDescriptor<BudgetMonth>()).isEmpty else { return }
    let now = Date.now
    let parts = Calendar.current.dateComponents([.year, .month], from: now)
    guard let year = parts.year, let month = parts.month else { return }
    modelContext.insert(
      BudgetMonth(year: year, month: month, mode: "balanced", currencyCode: "USD"))
    for (amount, kind, category, note) in [
      (500_000, "income", "income", "Take-home pay"),
      (90_000, "spending", "needs", "Groceries"),
      (35_000, "spending", "wants", "Dining"),
      (12_000, "spending", "giving", "Giving"),
      (20_000, "debt", "debt", "Debt payment"),
      (50_000, "savings", "savings", "Savings"),
    ] {
      modelContext.insert(
        LedgerEntry(
          amountMinor: Int64(amount), currencyCode: "USD", fractionDigits: 2,
          kind: kind, category: category, occurredAt: now, note: note))
    }
    try modelContext.save()
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
              .accessibilityIdentifier("remainingBudgetValue")
          }
          categoryChart(report, month)
        }
        VStack(alignment: .leading, spacing: 16) {
          Text("Categories").font(.title2.bold())
          ScrollView(.horizontal) {
            HStack(spacing: 20) {
              ForEach(report.categories, id: \.category) { category in
                categoryCard(category, month, report.income.fractionDigits)
                  .focusable()
                  .focused($focusedCategory, equals: category.category.rawValue)
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
        y: .value("Used", majorUnits(used(category).minorUnits, month.currencyCode))
      )
      .foregroundStyle(by: .value("Measure", "Used"))
      PointMark(
        x: .value("Category", category.category.rawValue.capitalized),
        y: .value("Planned", majorUnits(category.allocated.minorUnits, month.currencyCode))
      )
      .symbol(.square).symbolSize(120)
      .foregroundStyle(by: .value("Measure", "Planned"))
    }
    .chartForegroundStyleScale(["Used": Color.accentColor, "Planned": Color.primary])
    .chartLegend(position: .bottom)
    .chartYAxis {
      AxisMarks { _ in
        AxisGridLine()
        AxisValueLabel(format: .currency(code: month.currencyCode).precision(.fractionLength(0)))
      }
    }
    .chartYAxisLabel("Used and planned")
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
        .font(.callout).foregroundStyle(.primary)
      Text("\(money(category.allocated.minorUnits, month.currencyCode, fractionDigits)) planned")
        .font(.callout).foregroundStyle(.primary)
    }
    .frame(width: 310, height: 220, alignment: .leading)
    .padding(24)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .scaleEffect(!reduceMotion && focusedCategory == category.category.rawValue ? 1.06 : 1)
    .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: focusedCategory)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(category.category.rawValue) remaining \(money(category.remaining.minorUnits, month.currencyCode, fractionDigits))"
    )
    .accessibilityIdentifier("category-\(category.category.rawValue)")
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
          BarMark(x: .value("Month", point.label), y: .value("Income", majorUnits(point.income, currencyCode)))
            .position(by: .value("Series", "Income"))
          BarMark(x: .value("Month", point.label), y: .value("Spending", majorUnits(point.spending, currencyCode)))
            .position(by: .value("Series", "Spending"))
        }
      }
      .chartForegroundStyleScale(["Income": Color.accentColor, "Spending": .orange])
      .chartYAxis {
        AxisMarks { _ in
          AxisGridLine()
          AxisValueLabel(format: .currency(code: currencyCode).precision(.fractionLength(0)))
        }
      }
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

  private func majorUnits(_ minor: Int64, _ currency: String) -> Double {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return Double(minor) / pow(10, Double(formatter.maximumFractionDigits))
  }

  private func money(_ minor: Int64, _ currency: String, _ fractionDigits: Int) -> String {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    return (Decimal(minor) / scale).formatted(.currency(code: currency))
  }
}

#Preview("TV budget") {
  TVContentView(seedTestBudgetForUITests: false)
    .modelContainer(
      for: [BudgetMonth.self, LedgerEntry.self, CloudTombstone.self], inMemory: true)
}

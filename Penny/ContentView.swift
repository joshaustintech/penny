import Charts
import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
  import UniformTypeIdentifiers
#endif

struct ContentView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @AppStorage("preferredCurrency") private var preferredCurrency =
    Locale.current.currency?.identifier ?? "USD"
  #if os(iOS)
    @AppStorage("watchSharingEnabled") private var watchSharingEnabled = false
  #endif
  @State private var months: [BudgetMonth] = []
  @State private var entries: [LedgerEntry] = []
  @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
  @AppStorage("defaultBudgetMode") private var defaultBudgetMode = BudgetMode.balanced.rawValue
  @State private var income: Decimal = 0
  @State private var selectedMonth = Date.now
  @State private var saveError: String?
  @State private var entryPresentation: EntryPresentation?
  @State private var showingSettings = false
  @State private var showingModeChange = false
  @State private var pendingDelete: LedgerEntry?
  #if os(macOS)
    @State private var exportDocument: PennyTextDocument?
    @State private var exportType: UTType = .plainText
    @State private var exportFilename = ""
    @State private var showingExporter = false
  #endif

  private var currentComponents: DateComponents {
    Calendar.current.dateComponents([.year, .month], from: selectedMonth)
  }

  private var selectedMode: BudgetMode {
    BudgetMode(rawValue: defaultBudgetMode) ?? .balanced
  }

  private var selectedModeBinding: Binding<BudgetMode> {
    Binding(
      get: { selectedMode }, set: { defaultBudgetMode = $0.rawValue })
  }

  private var currentBudget: BudgetMonth? {
    months.first { $0.year == currentComponents.year && $0.month == currentComponents.month }
  }

  private var currency: String {
    currentBudget?.currencyCode ?? preferredCurrency
  }

  private var cardBackground: Color {
    #if os(iOS)
      Color(uiColor: .secondarySystemBackground)
    #elseif os(macOS)
      Color(nsColor: .controlBackgroundColor)
    #else
      Color.gray.opacity(0.1)
    #endif
  }

  var body: some View {
    Group {
      #if os(macOS)
        NavigationSplitView {
          monthSidebar
        } detail: {
          dashboard
        }
      #else
        if horizontalSizeClass == .regular {
          NavigationSplitView(columnVisibility: $columnVisibility) {
            monthSidebar
          } detail: {
            dashboard
          }
        } else {
          dashboard
        }
      #endif
    }
    .alert(
      "Penny couldn't complete the action",
      isPresented: Binding(
        get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    ) {
      Button("OK") { saveError = nil }
    } message: {
      Text(saveError ?? "Try again.")
    }
  }

  private var dashboard: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text("Every penny has a purpose.")
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)
          monthSwitcher
          if let currentBudget { overview(currentBudget) } else { setup }
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding()
        .frame(maxWidth: .infinity, alignment: .top)
      }
      .navigationTitle("Penny")
      .tint(.accentColor)
      .task { loadBudget() }
      .onChange(of: selectedMonth) { _, _ in income = 0 }
      .onReceive(NotificationCenter.default.publisher(for: .cloudBudgetDidChange)) { _ in
        loadBudget()
      }
      #if os(iOS)
        .onChange(of: watchSharingEnabled) { _, _ in loadBudget() }
        .onReceive(NotificationCenter.default.publisher(for: .watchBudgetChanged)) { _ in
          loadBudget()
        }
      #endif
      .toolbar {
        #if os(macOS)
          ToolbarItem {
            SettingsLink { Label("Settings", systemImage: "gearshape") }
          }
        #else
          ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape") { showingSettings = true }
              .accessibilityIdentifier("settingsButton")
          }
        #endif
        if currentBudget != nil {
          ToolbarItem(placement: .primaryAction) {
            Button("Add entry", systemImage: "plus") {
              entryPresentation = .new
            }
            #if os(macOS)
              .keyboardShortcut("n", modifiers: .command)
            #endif
            .accessibilityIdentifier("addEntryButton")
          }
          #if os(macOS)
            ToolbarItem(placement: .primaryAction) {
              Menu("Export", systemImage: "square.and.arrow.up") {
                Button("Markdown report") { prepareExport(asCSV: false) }
                Button("CSV transactions") { prepareExport(asCSV: true) }
              }
            }
          #endif
        }
      }
      .sheet(item: $entryPresentation) { presentation in
        if let currentBudget {
          EntryForm(
            mode: BudgetMode(rawValue: currentBudget.mode) ?? .balanced,
            currency: currentBudget.currencyCode,
            monthDate: selectedMonth,
            existingEntry: presentation.entry,
            onSave: loadBudget)
        }
      }
      #if os(iOS)
        .sheet(isPresented: $showingSettings) {
          NavigationStack {
            PennySettingsView()
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button {
                  showingSettings = false
                } label: {
                  Image(systemName: "xmark").foregroundStyle(.primary)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Close settings")
                .accessibilityIdentifier("settingsDoneButton")
              }
            }
          }
          .presentationDetents([.large])
        }
      #endif
      .confirmationDialog(
        "Delete this entry?",
        isPresented: Binding(
          get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive, action: deletePendingEntry)
        Button("Cancel", role: .cancel) { pendingDelete = nil }
      }
      #if os(macOS)
        .fileExporter(
          isPresented: $showingExporter, document: exportDocument, contentType: exportType,
          defaultFilename: exportFilename
        ) { result in
          if case .failure(let error) = result { saveError = error.localizedDescription }
        }
      #endif
    }
  }

  private var monthSidebar: some View {
    List {
      ForEach(months.reversed(), id: \.id) { month in
        Button {
          if let date = Calendar.current.date(
            from: DateComponents(year: month.year, month: month.month, day: 1))
          {
            selectedMonth = date
          }
        } label: {
          Text(
            Calendar.current.date(from: DateComponents(year: month.year, month: month.month))?
              .formatted(.dateTime.month(.wide).year()) ?? "\(month.year)-\(month.month)")
        }
        .buttonStyle(.plain)
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Months")
  }

  private var monthSwitcher: some View {
    HStack {
      Button("Previous month", systemImage: "chevron.left") { moveMonth(by: -1) }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
      Spacer()
      Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
        .font(.title3.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Spacer()
      Button("Next month", systemImage: "chevron.right") { moveMonth(by: 1) }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
    .accessibilityElement(children: .contain)
  }

  private var setup: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Start with take-home income. Penny will give every dollar a clear place.")
        .foregroundStyle(.primary)
      Label(
        "This budget stays on this device. Sync with iCloud in Settings.",
        systemImage: "lock.shield"
      )
      .font(.footnote)
      .foregroundStyle(.primary)
      Picker(
        "Budget style",
        selection: selectedModeBinding
      ) {
        Text("Balanced").tag(BudgetMode.balanced)
        Text("Housing First").tag(BudgetMode.housingFirst)
      }
      .pickerStyle(.segmented)
      .accessibilityIdentifier("budgetModePicker")
      Text(
        selectedMode == .balanced
          ? "50% needs · 20% wants · 10% giving · 10% debt · 10% savings"
          : "50% housing · 15% needs · 10% giving · 10% debt · 10% savings · 5% wants"
      )
      .font(.callout)
      .foregroundStyle(.primary)
      VStack(alignment: .leading, spacing: 12) {
        Text("Monthly take-home income")
          .font(.headline)
        TextField(
          "Income (\(currency))", value: $income,
          format: .number.precision(.fractionLength(0...fractionDigits))
        )
        #if os(iOS)
          .keyboardType(.decimalPad)
        #endif
        .accessibilityHint("Enter income after taxes")
        .accessibilityIdentifier("incomeField")
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBackground, in: RoundedRectangle(cornerRadius: 20))
      Button("Create my budget", action: saveBudget)
        .buttonStyle(.borderedProminent)
        .tint(.primary)
        .disabled(minorIncome == nil)
        .accessibilityIdentifier("createBudgetButton")
    }
  }

  private func overview(_ budget: BudgetMonth) -> some View {
    let mode = BudgetMode(rawValue: budget.mode) ?? .balanced
    let monthEntries = entries.filter {
      $0.dateComponents?.year == budget.year && $0.dateComponents?.month == budget.month
    }
    let report = try? BudgetReporting.make(
      entries: monthEntries, currencyCode: budget.currencyCode, fractionDigits: fractionDigits,
      mode: mode)
    return VStack(alignment: .leading, spacing: 18) {
      Text("Monthly take-home")
        .font(.headline)
      Text(amount(report?.income.minorUnits ?? 0))
        .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
        .accessibilityLabel("Income")
        .accessibilityValue(amount(report?.income.minorUnits ?? 0))
      if let report,
        let spent = try? BudgetReporting.overallSpent(from: report),
        let remaining = try? BudgetReporting.overallRemaining(from: report)
      {
        budgetSummary(spent: spent.minorUnits, remaining: remaining.minorUnits)
      }
      Label(mode == .balanced ? "Balanced" : "Housing First", systemImage: "circle.grid.2x2")
        .foregroundStyle(.primary)
      Button("Change budget style", systemImage: "slider.horizontal.3") {
        showingModeChange = true
      }
      .foregroundStyle(.primary)
      .confirmationDialog(
        "Change budget style?", isPresented: $showingModeChange, titleVisibility: .visible
      ) {
        if mode != .balanced { Button("Balanced") { changeMode(.balanced) } }
        if mode != .housingFirst { Button("Housing First") { changeMode(.housingFirst) } }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          "Category allocations for \(selectedMonth.formatted(.dateTime.month(.wide).year())) will change. Recorded transactions stay the same."
        )
      }
      Text("Your monthly budget")
        .font(.title2.bold())
      if let report, report.income.minorUnits > 0 {
        Chart(report.categories, id: \.category) { item in
          SectorMark(
            angle: .value("Allocation", item.allocated.minorUnits),
            innerRadius: .ratio(0.68), angularInset: 2
          )
          .foregroundStyle(by: .value("Category", item.category.rawValue.capitalized))
          .accessibilityLabel(item.category.rawValue.capitalized)
          .accessibilityValue("\(item.percent)%")
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 220)
        .accessibilityLabel("Budget allocation")
        plannedVsActual(report)
      }
      ForEach(report?.categories ?? [], id: \.category) { item in
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(item.category.rawValue.capitalized).font(.headline)
            Spacer()
            Text(amount(item.remaining.minorUnits)).font(.headline.monospacedDigit())
          }
          Text(
            item.category == .debt || item.category == .savings
              ? "\(amount(item.contributed.minorUnits)) contributed of \(amount(item.allocated.minorUnits))"
              : "\(amount(item.spent.minorUnits)) spent of \(amount(item.allocated.minorUnits))"
          )
          .foregroundStyle(.primary)
          if let status = budgetStatus(for: item) {
            Label(
              status,
              systemImage: status == "Over budget" ? "exclamationmark.circle.fill" : "hourglass"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(status == "Over budget" ? .red : .orange)
          }
          Text("\(item.percent)% of income")
            .font(.caption)
        }
        .padding(14)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
      }
      Text("Recent activity").font(.title2.bold())
      ForEach(monthEntries.reversed(), id: \.id) { entry in
        HStack(spacing: 12) {
          VStack(alignment: .leading) {
            Text(entry.category.capitalized)
            Text(entry.note ?? entry.kind.capitalized).font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
          Text(amount(entry.amountMinor)).monospacedDigit()
          Button {
            entryPresentation = .edit(entry)
          } label: {
            Image(systemName: "pencil")
          }
          .accessibilityLabel("Edit \(entry.note ?? entry.kind)")
          Button(role: .destructive) {
            pendingDelete = entry
          } label: {
            Image(systemName: "trash")
          }
          .accessibilityLabel("Delete \(entry.note ?? entry.kind)")
        }
        .padding(.vertical, 8)
      }
      if let report {
        spendingTrend(report: report, budget: budget, entries: monthEntries)
      }
      Text("Monthly spending")
        .font(.title2.bold())
      let history = spendingHistory(currencyCode: budget.currencyCode)
      if history.count > 1 {
        Chart(history) { point in
          LineMark(
            x: .value("Month", point.date), y: .value("Spent", point.spent)
          )
          .symbol(.circle)
          PointMark(x: .value("Month", point.date), y: .value("Spent", point.spent))
        }
        .chartXScale(
          domain: history[0].date...history[history.count - 1].date.addingTimeInterval(1_209_600)
        )
        .chartXAxis {
          AxisMarks(values: history.map(\.date)) {
            AxisValueLabel(format: .dateTime.month(.abbreviated))
          }
        }
        .chartYAxis { AxisMarks(format: .currency(code: currency)) }
        .frame(height: 200)
        .accessibilityLabel("Monthly spending history")
        .accessibilityValue(
          history.map {
            "\($0.date.formatted(.dateTime.month(.wide))): \($0.spent.formatted(.currency(code: currency)))"
          }.joined(separator: ", "))
      } else {
        ContentUnavailableView(
          "History starts next month", systemImage: "chart.xyaxis.line",
          description: Text("Add another budget month to compare spending.")
        )
      }
    }
  }

  private func budgetSummary(spent: Int64, remaining: Int64) -> some View {
    HStack(alignment: .firstTextBaseline) {
      summaryMetric("Actual spending", amount(spent))
        .accessibilityIdentifier("actualSpendingSummary")
      Spacer(minLength: 12)
      summaryMetric("Left in plan", amount(remaining))
        .accessibilityIdentifier("remainingPlanSummary")
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(cardBackground, in: RoundedRectangle(cornerRadius: 18))
  }

  private func summaryMetric(_ title: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.subheadline).foregroundStyle(.primary)
      Text(value).font(.title3.bold().monospacedDigit())
    }
    .accessibilityElement(children: .combine)
  }

  private func budgetStatus(for item: CategoryResult) -> String? {
    if item.remaining.minorUnits < 0 { return "Over budget" }
    guard item.allocated.minorUnits > 0 else { return nil }
    let used =
      item.category == .debt || item.category == .savings
      ? item.contributed.minorUnits : item.spent.minorUnits
    return used >= item.allocated.minorUnits - item.allocated.minorUnits / 5 ? "Near limit" : nil
  }

  private func plannedVsActual(_ report: MonthlyReport) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Planned versus actual").font(.title2.bold())
      Text("Bars show actual use; square marks show each plan.")
        .font(.caption)
        .foregroundStyle(.primary)
      Chart(report.categories, id: \.category) { item in
        let planned = Double(item.allocated.minorUnits) / pow(10, Double(fractionDigits))
        let actualAmount =
          item.category == .debt || item.category == .savings
          ? item.contributed.minorUnits : item.spent.minorUnits
        let actual = Double(actualAmount) / pow(10, Double(fractionDigits))
        BarMark(
          x: .value("Actual", actual),
          y: .value("Category", item.category.rawValue.capitalized)
        )
        .foregroundStyle(item.remaining.minorUnits < 0 ? Color.red : Color.green)
        .accessibilityLabel("\(item.category.rawValue.capitalized) actual")
        .accessibilityValue(amount(actualAmount))
        PointMark(
          x: .value("Planned", planned),
          y: .value("Category", item.category.rawValue.capitalized)
        )
        .symbol(.square)
        .foregroundStyle(.primary)
        .accessibilityLabel("\(item.category.rawValue.capitalized) planned")
        .accessibilityValue(amount(item.allocated.minorUnits))
      }
      .chartXAxis { AxisMarks(format: .currency(code: currency)) }
      .frame(height: CGFloat(report.categories.count * 34))
      .accessibilityLabel("Planned versus actual")
      .accessibilityValue(
        report.categories.map {
          "\($0.category.rawValue.capitalized): actual \(amount($0.category == .debt || $0.category == .savings ? $0.contributed.minorUnits : $0.spent.minorUnits)), planned \(amount($0.allocated.minorUnits))"
        }.joined(separator: ". "))
    }
  }

  private func spendingTrend(
    report: MonthlyReport, budget: BudgetMonth, entries: [LedgerEntry]
  ) -> some View {
    let allDays =
      (try? BudgetReporting.dailySpending(
        entries: entries, year: budget.year, month: budget.month,
        currencyCode: budget.currencyCode, fractionDigits: fractionDigits)) ?? []
    let now = Calendar.current.dateComponents([.year, .month, .day], from: .now)
    let future =
      budget.year > (now.year ?? budget.year)
      || (budget.year == now.year && budget.month > (now.month ?? budget.month))
    let throughDay =
      future
      ? 0
      : budget.year == now.year && budget.month == now.month
        ? (now.day ?? allDays.count) : allDays.count
    let days = allDays.filter { $0.day <= throughDay }
    let planned = report.categories.filter { ![.debt, .savings].contains($0.category) }
      .reduce(Int64(0)) { $0 + $1.allocated.minorUnits }
    let scale = pow(10, Double(fractionDigits))
    let actualSummary =
      "Actual " + amount(days.last?.cumulative.minorUnits ?? 0) + "; plan " + amount(planned)
    return VStack(alignment: .leading, spacing: 8) {
      Text("Spending through month").font(.title2.bold())
      Text("Actual spending accumulates daily; dashed line marks the plan.")
        .font(.caption)
        .foregroundStyle(.primary)
      if !days.isEmpty {
        Chart {
          ForEach(days, id: \.day) { point in
            LineMark(
              x: .value("Day", point.day),
              y: .value("Actual spending", Double(point.cumulative.minorUnits) / scale)
            )
          }
          RuleMark(y: .value("Monthly plan", Double(planned) / scale))
            .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
            .foregroundStyle(.secondary)
        }
        .chartXAxis { AxisMarks(values: .stride(by: 5)) }
        .chartYAxis { AxisMarks(format: .currency(code: budget.currencyCode)) }
        .chartXScale(domain: 1...max(1, throughDay))
        .frame(height: 190)
        .accessibilityLabel("Spending against monthly plan")
        .accessibilityValue(actualSummary)
      } else {
        Text("Spending trend starts when this month begins.")
          .foregroundStyle(.primary)
      }
    }
  }

  private func spendingHistory(currencyCode: String) -> [MonthSpending] {
    months.compactMap { month in
      guard month.currencyCode == currencyCode,
        let mode = BudgetMode(rawValue: month.mode),
        let date = Calendar.current.date(
          from: DateComponents(year: month.year, month: month.month)),
        let report = try? BudgetReporting.make(
          entries: entries.filter {
            $0.dateComponents?.year == month.year && $0.dateComponents?.month == month.month
          }, currencyCode: currencyCode, fractionDigits: fractionDigits, mode: mode)
      else { return nil }
      var total: Int64 = 0
      for category in report.categories {
        let (sum, overflow) = total.addingReportingOverflow(category.spent.minorUnits)
        guard !overflow else { return nil }
        total = sum
      }
      return MonthSpending(
        date: date, spent: Double(total) / pow(10, Double(fractionDigits)))
    }
    .sorted { $0.date < $1.date }
  }

  private var fractionDigits: Int {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.maximumFractionDigits
  }

  private var minorIncome: Int64? {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    guard income > 0, income <= Decimal(Int64.max) / scale else { return nil }
    return NSDecimalNumber(decimal: income * scale).int64Value
  }

  private func moveMonth(by offset: Int) {
    guard let start = Calendar.current.date(from: currentComponents),
      let next = Calendar.current.date(byAdding: .month, value: offset, to: start)
    else { return }
    selectedMonth = next
  }

  private func amount(_ minorUnits: Int64) -> String {
    let scale = Decimal(sign: .plus, exponent: fractionDigits, significand: 1)
    let value = NSDecimalNumber(value: minorUnits).decimalValue / scale
    return value.formatted(.currency(code: currency))
  }

  private func saveBudget() {
    guard let year = currentComponents.year, let month = currentComponents.month,
      let minorIncome
    else { return }
    let budget = BudgetMonth(
      year: year, month: month, mode: selectedMode.rawValue, currencyCode: currency)
    let initialIncome = LedgerEntry(
      amountMinor: minorIncome, currencyCode: currency, fractionDigits: fractionDigits,
      kind: "income", category: "income", occurredAt: selectedMonth)
    do {
      try BudgetStore(context: context).createBudget(budget, income: initialIncome)
      loadBudget()
    } catch {
      saveError = error.localizedDescription
    }
  }

  private func loadBudget() {
    do {
      let store = BudgetStore(context: context)
      let savedMonths = try store.months()
      months = savedMonths
      entries = try store.entries()
      #if os(iOS)
        if horizontalSizeClass == .regular {
          columnVisibility = savedMonths.isEmpty ? .detailOnly : .all
        }
        publishWatchSnapshot(months: savedMonths, entries: entries)
      #endif
    } catch {
      saveError = error.localizedDescription
    }
  }

  #if os(iOS)
    private func publishWatchSnapshot(months: [BudgetMonth], entries: [LedgerEntry]) {
      guard watchSharingEnabled else {
        WatchBudgetSync.shared.publish(nil)
        return
      }
      let current = Calendar.current.dateComponents([.year, .month], from: .now)
      guard
        let month = months.first(where: { $0.year == current.year && $0.month == current.month })
      else {
        WatchBudgetSync.shared.publish(nil)
        return
      }
      let formatter = NumberFormatter()
      formatter.numberStyle = .currency
      formatter.currencyCode = month.currencyCode
      let monthEntries = entries.filter {
        $0.dateComponents?.year == month.year && $0.dateComponents?.month == month.month
      }
      let report = try? BudgetReporting.make(
        entries: monthEntries, currencyCode: month.currencyCode,
        fractionDigits: formatter.maximumFractionDigits,
        mode: BudgetMode(rawValue: month.mode) ?? .balanced)
      let transfer = report.flatMap {
        try? WatchBudgetSnapshot(
          report: $0, entries: monthEntries, year: month.year, month: month.month)
      }
      WatchBudgetSync.shared.publish(transfer)
    }
  #endif

  private func deletePendingEntry() {
    guard let pendingDelete else { return }
    do {
      try BudgetStore(context: context).delete(pendingDelete)
      self.pendingDelete = nil
      loadBudget()
    } catch {
      saveError = error.localizedDescription
    }
  }

  private func changeMode(_ mode: BudgetMode) {
    guard let currentBudget else { return }
    do {
      try BudgetStore(context: context).changeMode(of: currentBudget, to: mode)
      loadBudget()
    } catch {
      saveError = error.localizedDescription
    }
  }

  #if os(macOS)
    private func prepareExport(asCSV: Bool) {
      guard let currentBudget else { return }
      let selectedEntries = entries.filter {
        $0.dateComponents?.year == currentBudget.year
          && $0.dateComponents?.month == currentBudget.month
      }
      let monthName = String(format: "%04d-%02d", currentBudget.year, currentBudget.month)
      if asCSV {
        exportDocument = PennyTextDocument(BudgetExport.csv(entries: selectedEntries))
        exportType = .commaSeparatedText
        exportFilename = "Penny-\(monthName)-transactions.csv"
      } else {
        let mode = BudgetMode(rawValue: currentBudget.mode) ?? .balanced
        guard
          let report = try? BudgetReporting.make(
            entries: selectedEntries, currencyCode: currentBudget.currencyCode,
            fractionDigits: fractionDigits, mode: mode),
          let markdown = try? BudgetExport.markdown(
            month: currentBudget, report: report, entries: selectedEntries)
        else {
          saveError = "Penny could not prepare this month's report."
          return
        }
        exportDocument = PennyTextDocument(markdown)
        exportType = PennyTextDocument.markdownContentType
        exportFilename = "Penny-\(monthName)-report.md"
      }
      showingExporter = exportDocument != nil
    }
  #endif
}

private enum EntryPresentation: Identifiable {
  case new
  case edit(LedgerEntry)

  var id: String {
    switch self {
    case .new: "new"
    case .edit(let entry): "edit-\(entry.id)"
    }
  }

  var entry: LedgerEntry? {
    guard case .edit(let entry) = self else { return nil }
    return entry
  }
}

private struct MonthSpending: Identifiable {
  let date: Date
  let spent: Double
  var id: Date { date }
}

#if os(macOS)
  private struct PennyTextDocument: FileDocument {
    static let markdownContentType =
      UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    static var readableContentTypes: [UTType] { [markdownContentType, .commaSeparatedText] }
    let text: String

    init(_ text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
      text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
      FileWrapper(regularFileWithContents: Data(text.utf8))
    }
  }
#endif

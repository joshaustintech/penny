import Charts
import SwiftData
import SwiftUI

#if os(macOS)
  import UniformTypeIdentifiers
#endif

struct ContentView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var months: [BudgetMonth] = []
  @State private var entries: [LedgerEntry] = []
  @State private var selectedMode = BudgetMode.balanced
  @State private var income: Decimal = 0
  @State private var selectedMonth = Date.now
  @State private var saveError: String?
  @State private var showingEntry = false
  @State private var showingModeChange = false
  @State private var selectedEntry: LedgerEntry?
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

  private var currentBudget: BudgetMonth? {
    months.first { $0.year == currentComponents.year && $0.month == currentComponents.month }
  }

  private var currency: String {
    currentBudget?.currencyCode ?? (Locale.current.currency?.identifier ?? "USD")
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
          NavigationSplitView {
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
      .tint(Color(red: 0.16, green: 0.43, blue: 0.34))
      .task { loadBudget() }
      .onChange(of: selectedMonth) { _, _ in income = 0 }
      .toolbar {
        if currentBudget != nil {
          ToolbarItem(placement: .primaryAction) {
            Button("Add entry", systemImage: "plus") {
              selectedEntry = nil
              showingEntry = true
            }
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
      .sheet(isPresented: $showingEntry) {
        if let currentBudget {
          EntryForm(
            mode: BudgetMode(rawValue: currentBudget.mode) ?? .balanced,
            currency: currentBudget.currencyCode,
            monthDate: selectedMonth,
            existingEntry: selectedEntry,
            onSave: loadBudget)
        }
      }
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
      Spacer()
      Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
        .font(.title3.weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      Spacer()
      Button("Next month", systemImage: "chevron.right") { moveMonth(by: 1) }
        .labelStyle(.iconOnly)
    }
    .accessibilityElement(children: .contain)
  }

  private var setup: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("Start with take-home income. Penny will give every dollar a clear place.")
        .foregroundStyle(.secondary)
      Picker("Budget style", selection: $selectedMode) {
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
      .foregroundStyle(.secondary)
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
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
      Button("Create my budget", action: saveBudget)
        .buttonStyle(.borderedProminent)
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
      Label(mode == .balanced ? "Balanced" : "Housing First", systemImage: "circle.grid.2x2")
        .foregroundStyle(.secondary)
      Button("Change budget style", systemImage: "slider.horizontal.3") {
        showingModeChange = true
      }
      .confirmationDialog(
        "Change this month's budget?", isPresented: $showingModeChange, titleVisibility: .visible
      ) {
        if mode != .balanced { Button("Balanced") { changeMode(.balanced) } }
        if mode != .housingFirst { Button("Housing First") { changeMode(.housingFirst) } }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Category allocations will change. Recorded transactions stay the same.")
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
          .foregroundStyle(.secondary)
          Text("\(item.percent)% of income")
            .font(.caption)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
      }
      Text("Recent activity").font(.title2.bold())
      ForEach(monthEntries.reversed(), id: \.id) { entry in
        Button {
          selectedEntry = entry
          showingEntry = true
        } label: {
          HStack {
            VStack(alignment: .leading) {
              Text(entry.category.capitalized)
              Text(entry.note ?? entry.kind.capitalized).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount(entry.amountMinor)).monospacedDigit()
          }
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button("Edit", systemImage: "pencil") {
            selectedEntry = entry
            showingEntry = true
          }
          Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = entry }
        }
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
      months = try store.months()
      entries = try store.entries()
    } catch {
      saveError = error.localizedDescription
    }
  }

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
        exportType = .plainText
        exportFilename = "Penny-\(monthName)-report.md"
      }
      showingExporter = exportDocument != nil
    }
  #endif
}

private struct MonthSpending: Identifiable {
  let date: Date
  let spent: Double
  var id: Date { date }
}

#if os(macOS)
  private struct PennyTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .commaSeparatedText] }
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

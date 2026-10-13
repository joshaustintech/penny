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
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @AppStorage("preferredCurrency") private var preferredCurrency =
    Locale.current.currency?.identifier ?? "USD"
  #if os(iOS)
    @AppStorage("watchSharingEnabled") private var watchSharingEnabled = false
  #endif
  @State private var section: DashboardSection = {
    guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return .budget }
    return DashboardSection(rawValue: UserDefaults.standard.string(forKey: "screenshotSection") ?? "Budget") ?? .budget
  }()
  @State private var months: [BudgetMonth] = []
  @State private var entries: [LedgerEntry] = []
  @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
  @AppStorage("defaultBudgetMode") private var defaultBudgetMode = BudgetMode.balanced.rawValue
  @State private var incomeText = ""
  @FocusState private var incomeFieldFocused: Bool
  @State private var selectedMonth = Date.now
  @State private var saveError: String?
  @State private var entryPresentation: EntryPresentation?
  @State private var showingSettings = false
  @State private var showingModeChange = false
  @State private var pendingDelete: LedgerEntry?
  @State private var showingDeleteConfirmation = false
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
          dashboard(section)
        }
      #else
        if horizontalSizeClass == .regular {
          NavigationSplitView(columnVisibility: $columnVisibility) {
            monthSidebar
          } detail: {
            tabbedDashboard
          }
          .navigationSplitViewStyle(.balanced)
        } else {
          tabbedDashboard
        }
      #endif
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

  #if os(iOS)
    private var tabbedDashboard: some View {
      Group {
        if currentBudget != nil {
          if #available(iOS 18.0, *) {
            TabView(selection: $section) {
              ForEach(DashboardSection.allCases) { destination in
                Tab(destination.rawValue, systemImage: destination.systemImage, value: destination) {
                  dashboard(destination)
                }
              }
            }
          } else {
            TabView(selection: $section) {
              ForEach(DashboardSection.allCases) { destination in
                dashboard(destination)
                  .tabItem { Label(destination.rawValue, systemImage: destination.systemImage) }
                  .tag(destination)
              }
            }
          }
        } else { dashboard(.budget) }
      }
    }
  #endif

  private func dashboard(_ destination: DashboardSection) -> some View {
    NavigationStack {
      dashboardPage(destination)
      #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          if currentBudget == nil && !incomeFieldFocused {
            Button("Create my budget", action: saveBudget)
              .buttonStyle(.borderedProminent)
              .tint(.primary)
              .disabled(minorIncome == nil)
              .frame(maxWidth: 620)
              .padding()
              .frame(maxWidth: .infinity)
              .background(.bar)
              .accessibilityIdentifier("createBudgetButton")
          }
        }
      #endif
      .navigationTitle("Penny")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .tint(.accentColor)
      .task { loadBudget() }
      #if os(macOS)
        .focusedSceneValue(
          \.pennyCommandActions,
          PennyCommandActions(
            canAddEntry: currentBudget != nil,
            canExport: currentBudget != nil,
            addEntry: { entryPresentation = .new },
            exportMarkdown: { prepareExport(asCSV: false) },
            exportCSV: { prepareExport(asCSV: true) }))
      #endif
      .onChange(of: selectedMonth) { _, _ in incomeText = "" }
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
          ToolbarItem(placement: addEntryToolbarPlacement) {
            Button("Add entry", systemImage: "plus") {
              entryPresentation = .new
            }
            .frame(minWidth: 48, minHeight: 48)
            .contentShape(Rectangle())
            #if os(iOS)
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
      #if os(iOS)
        .sheet(isPresented: settingsSheetPresented) {
          settingsScreen.presentationDetents([.large])
        }
        .fullScreenCover(isPresented: settingsFullScreenPresented) { settingsScreen }
      #endif
      .alert("Delete this entry?", isPresented: $showingDeleteConfirmation) {
        Button("Delete", role: .destructive, action: deletePendingEntry)
        Button("Cancel", role: .cancel) { pendingDelete = nil }
      } message: {
        Text("This entry will be removed from this month's budget.")
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

  private func dashboardPage(_ destination: DashboardSection) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if currentBudget == nil {
          Text("Every penny has a purpose.")
            .font(.title.bold())
            .accessibilityAddTraits(.isHeader)
        }
        #if !os(iOS)
          monthSwitcher
        #endif
        if let currentBudget { overview(currentBudget, destination: destination) } else { setup }
      }
      .frame(maxWidth: dashboardWidth, alignment: .leading)
      .padding()
      .frame(maxWidth: .infinity, alignment: .top)
    }
    #if os(iOS)
      .safeAreaInset(edge: .top, spacing: 0) { monthSwitcher.background(.bar) }
    #endif
  }

  private var usesWideCategories: Bool {
    #if os(macOS)
      !dynamicTypeSize.isAccessibilitySize
    #else
      horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize
    #endif
  }

  private var dashboardWidth: CGFloat {
    #if os(macOS)
      1000
    #else
      horizontalSizeClass == .regular ? 1000 : 620
    #endif
  }

  #if os(iOS)
    private var settingsSheetPresented: Binding<Bool> {
      Binding(
        get: { showingSettings && horizontalSizeClass != .regular },
        set: { if !$0 { showingSettings = false } })
    }

    private var settingsFullScreenPresented: Binding<Bool> {
      Binding(
        get: { showingSettings && horizontalSizeClass == .regular },
        set: { if !$0 { showingSettings = false } })
    }

    private var settingsScreen: some View {
      NavigationStack {
        PennySettingsView()
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button { showingSettings = false } label: {
                Image(systemName: "xmark").foregroundStyle(.primary)
              }
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
              .accessibilityLabel("Close settings")
              .accessibilityIdentifier("settingsDoneButton")
            }
          }
      }
    }
  #endif

  private var monthSidebar: some View {
    List(selection: Binding(
      get: {
        Calendar.current.date(
          from: DateComponents(
            year: currentComponents.year, month: currentComponents.month, day: 1)) ?? selectedMonth
      }, set: { month in
        if let month { selectedMonth = month }
      })) {
      #if os(macOS)
        Section("Penny") {
          ForEach(DashboardSection.allCases) { destination in
            Button(destination.rawValue, systemImage: destination.systemImage) {
              section = destination
            }
            .buttonStyle(.plain)
            .padding(.vertical, 6)
            .accessibilityValue(section == destination ? "Selected" : "")
            .listRowBackground(section == destination ? Color.accentColor.opacity(0.15) : Color.clear)
          }
        }
      #endif
      Section("Months") {
      ForEach(months.reversed(), id: \.id) { month in
        if let date = Calendar.current.date(
          from: DateComponents(year: month.year, month: month.month, day: 1))
        {
          NavigationLink(value: date) {
            Text(
              Calendar.current.date(from: DateComponents(year: month.year, month: month.month))?
                .formatted(.dateTime.month(.wide).year()) ?? "\(month.year)-\(month.month)")
              .foregroundStyle(.primary)
          }
        }
      }
      }
    }
    .listStyle(.sidebar)
    .tint(.accentColor)
    .navigationTitle("Penny")
  }

  private var monthSwitcher: some View {
    HStack {
      Button("Previous month", systemImage: "chevron.left") { moveMonth(by: -1) }
        .labelStyle(.iconOnly)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
      Spacer()
      Text(selectedMonth.formatted(.dateTime.month(.abbreviated).year()))
        .font(.headline)
        .accessibilityHint(selectedMonth.formatted(.dateTime.month(.wide).year()))
        .accessibilityIdentifier("monthHeading")
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
        TextField("Income (\(currency))", text: $incomeText)
        .focused($incomeFieldFocused)
        #if os(iOS)
          .keyboardType(.decimalPad)
          .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
              Spacer()
              Button("Done") { incomeFieldFocused = false }
                .accessibilityIdentifier("dismissIncomeKeyboardButton")
              Button("Create budget", action: saveBudget)
                .disabled(minorIncome == nil)
                .accessibilityIdentifier("createBudgetButton")
            }
          }
        #endif
        .accessibilityHint("Enter income after taxes")
        .accessibilityIdentifier("incomeField")
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(cardBackground, in: RoundedRectangle(cornerRadius: 20))
      #if !os(iOS)
        Button("Create my budget", action: saveBudget)
          .buttonStyle(.borderedProminent)
          .tint(.primary)
          .disabled(minorIncome == nil)
          .accessibilityIdentifier("createBudgetButton")
      #endif
    }
  }

  private func overview(_ budget: BudgetMonth, destination: DashboardSection) -> some View {
    let mode = BudgetMode(rawValue: budget.mode) ?? .balanced
    let monthEntries = entries.filter {
      $0.dateComponents?.year == budget.year && $0.dateComponents?.month == budget.month
    }
    let report = try? BudgetReporting.make(
      entries: monthEntries, currencyCode: budget.currencyCode, fractionDigits: fractionDigits,
      mode: mode)
    return VStack(alignment: .leading, spacing: 18) {
      if destination == .budget {
        if let report,
          let spent = try? BudgetReporting.overallSpent(from: report),
          let remaining = try? BudgetReporting.overallRemaining(from: report)
        {
          BudgetOverviewHeader(
            income: amount(report.income.minorUnits), spent: amount(spent.minorUnits),
            remaining: amount(remaining.minorUnits), isOverspent: remaining.minorUnits < 0)
        }
        HStack {
          Label(mode == .balanced ? "Balanced" : "Housing First", systemImage: "circle.grid.2x2")
            .foregroundStyle(.primary)
          Spacer(minLength: 12)
          Button("Change budget style", systemImage: "slider.horizontal.3") {
            showingModeChange = true
          }
          .labelStyle(.iconOnly)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
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
        }
        Text("Your monthly budget")
          .font(.title2.bold())
        let categories = report?.categories ?? []
        if usesWideCategories {
          Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: categories.count, by: 2)), id: \.self) { index in
              GridRow {
                categoryLink(categories[index], entries: monthEntries, mode: mode)
                if index + 1 < categories.count {
                  categoryLink(categories[index + 1], entries: monthEntries, mode: mode)
                }
              }
            }
          }
        } else {
          VStack(spacing: 0) {
            ForEach(categories, id: \.category) { item in categoryLink(item, entries: monthEntries, mode: mode) }
          }
        }
      }
      if destination == .activity {
        Text("Recent activity").font(.title2.bold())
        #if os(macOS)
          Table(of: LedgerEntry.self) {
            TableColumn("Date") { entry in activityDate(entry) }
            TableColumn("Type") { entry in Text(entry.kind.capitalized) }
            TableColumn("Category") { entry in Text(entry.category.capitalized) }
            TableColumn("Description") { entry in Text(entry.note ?? entry.kind.capitalized) }
            TableColumn("Amount") { entry in
              Text(amount(entry.amountMinor)).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          } rows: {
            ForEach(monthEntries.reversed()) { entry in
              TableRow(entry)
                .contextMenu {
                  Button {
                    entryPresentation = .edit(entry)
                  } label: {
                    Label("Edit", systemImage: "pencil")
                  }
                  Button(role: .destructive) {
                    pendingDelete = entry
                    showingDeleteConfirmation = true
                  } label: {
                    Label("Delete", systemImage: "trash")
                  }
                }
            }
          }
          .frame(minHeight: 360, idealHeight: 520, maxHeight: 640)
          .accessibilityIdentifier("transactionTable")
        #else
          ForEach(monthEntries.reversed(), id: \.id) { entry in
            activityRow(entry)
          }
        #endif
      }
      if destination == .reports {
        if let report { plannedVsActual(report) }
        if let report {
          spendingTrend(report: report, budget: budget, entries: monthEntries)
        }
        Text("Monthly spending")
          .font(.title2.bold())
        let history = spendingHistory(currencyCode: budget.currencyCode)
        if history.count > 1 {
          if dynamicTypeSize.isAccessibilitySize {
            Text(
              history.map {
                "\($0.date.formatted(.dateTime.month(.wide).year())): \($0.spent.formatted(.currency(code: currency)))"
              }.joined(separator: "\n"))
          }
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
              AxisGridLine()
              AxisTick()
              if !dynamicTypeSize.isAccessibilitySize {
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                  .font(.body)
                  .foregroundStyle(.primary)
              }
            }
          }
          .chartYAxis {
            AxisMarks { _ in
              AxisGridLine()
              AxisTick()
              if !dynamicTypeSize.isAccessibilitySize {
                AxisValueLabel(format: .currency(code: currency))
                  .font(.body)
                  .foregroundStyle(.primary)
              }
            }
          }
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

  private func categoryColor(_ category: BudgetCategory) -> Color {
    switch category {
    case .needs: Color(red: 0.02, green: 0.40, blue: 0.80)
    case .wants: Color(red: 0.15, green: 0.47, blue: 0.23)
    case .giving: Color(red: 0.68, green: 0.28, blue: 0.00)
    case .debt: Color(red: 0.52, green: 0.32, blue: 0.67)
    case .savings: Color(red: 0.74, green: 0.22, blue: 0.22)
    case .housing: Color(red: 0.52, green: 0.38, blue: 0.24)
    case .income: Color(red: 0.40, green: 0.45, blue: 0.50)
    }
  }

  private func allocationLegend(_ categories: [CategoryResult]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(categories, id: \.category) { item in
        HStack(spacing: 8) {
          Circle().fill(categoryColor(item.category)).frame(width: 10, height: 10)
            .accessibilityHidden(true)
          Text(item.category.rawValue.capitalized).font(.title3).foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }

  @ViewBuilder private func plannedVsActual(_ report: MonthlyReport) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Planned versus actual").font(.title2.bold())
      Text(dynamicTypeSize.isAccessibilitySize ? "Actual and planned amounts by category." : "Bars show actual use; square marks show each plan.")
        .font(.caption)
        .foregroundStyle(.primary)
      if dynamicTypeSize.isAccessibilitySize {
        ForEach(report.categories, id: \.category) { item in
          let actual =
            item.category == .debt || item.category == .savings
            ? item.contributed.minorUnits : item.spent.minorUnits
          VStack(alignment: .leading, spacing: 2) {
            Text(item.category.rawValue.capitalized).font(.headline)
            Text("Actual \(amount(actual))")
            Text("Planned \(amount(item.allocated.minorUnits))")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(cardBackground, in: RoundedRectangle(cornerRadius: 14))
          .accessibilityElement(children: .combine)
        }
      } else {
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
        .chartXAxis {
          AxisMarks { _ in
            AxisGridLine()
            AxisTick()
            AxisValueLabel(format: .currency(code: currency))
              .font(.body)
              .foregroundStyle(.primary)
          }
        }
        .chartYAxis {
          AxisMarks { _ in
            AxisGridLine()
            AxisTick()
            AxisValueLabel().font(.body).foregroundStyle(.primary)
          }
        }
        .frame(height: CGFloat(report.categories.count * 34))
        .accessibilityLabel("Planned versus actual")
        .accessibilityValue(
          report.categories.map {
            let actual =
              $0.category == .debt || $0.category == .savings
              ? $0.contributed.minorUnits : $0.spent.minorUnits
            return
              "\($0.category.rawValue.capitalized): actual \(amount(actual)), planned \(amount($0.allocated.minorUnits))"
          }.joined(separator: ". "))
      }
    }
  }

  private func categoryLink(_ item: CategoryResult, entries: [LedgerEntry], mode: BudgetMode) -> some View {
    NavigationLink {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(selectedMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
          Text("Remaining").font(.headline)
          Text(amount(item.remaining.minorUnits)).font(.largeTitle.bold()).monospacedDigit()
          let used = item.category == .debt || item.category == .savings ? item.contributed : item.spent
          Text("\(amount(used.minorUnits)) used of \(amount(item.allocated.minorUnits)) planned")
            .font(.body).monospacedDigit()
          Text("Transactions").font(.title2.bold())
          let matching = entries.filter {
            $0.category == item.category.rawValue
              || (mode == .balanced && item.category == .needs && $0.category == "housing")
          }
          if matching.isEmpty {
            ContentUnavailableView("No transactions", systemImage: "list.bullet.rectangle",
              description: Text("Entries assigned to this category will appear here."))
          } else {
            ForEach(matching.reversed()) { entry in
              activityRow(entry)
              Divider()
            }
          }
        }
        .padding(20)
        .frame(maxWidth: 900, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle(item.category.rawValue.capitalized)
    } label: {
      HStack(spacing: 12) {
        BudgetCategoryRow(item: item)
        Image(systemName: "chevron.right").font(.footnote.bold()).accessibilityHidden(true)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityHint("View category transactions")
    .accessibilityIdentifier("categoryDetailLink-\(item.category.rawValue)")
  }

  @ViewBuilder private func activityRow(_ entry: LedgerEntry) -> some View {
    if dynamicTypeSize.isAccessibilitySize || horizontalSizeClass != .regular {
      VStack(alignment: .leading, spacing: 6) {
        Text(activityTitle(entry)).font(.headline)
        Text(entry.note ?? entry.kind.capitalized).font(.subheadline).foregroundStyle(.primary)
        activityDate(entry)
        HStack(spacing: 12) {
          Text(amount(entry.amountMinor)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
          Spacer()
          activityButtons(entry)
        }
      }
      .padding(.vertical, 8)
    } else {
      HStack(spacing: 12) {
        VStack(alignment: .leading) {
          Text(activityTitle(entry)).font(.headline)
          Text(entry.note ?? entry.kind.capitalized).font(.subheadline).foregroundStyle(.primary)
          activityDate(entry)
        }
        Spacer()
        Text(amount(entry.amountMinor)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        activityButtons(entry)
      }
      .padding(.vertical, 8)
    }
  }

  private func activityTitle(_ entry: LedgerEntry) -> String {
    switch entry.kind {
    case "income": return "Income"
    case "savings": return "Savings contribution"
    case "debt": return "Debt payment"
    default: return "\(entry.kind.capitalized) · \(entry.category.capitalized)"
    }
  }

  private func activityDate(_ entry: LedgerEntry) -> some View {
    Text(entry.transactionDate.formatted(date: .abbreviated, time: .omitted))
      .font(.footnote)
      .foregroundStyle(.primary)
      .accessibilityIdentifier("activityEntryDate")
  }

  private func activityButtons(_ entry: LedgerEntry) -> some View {
    HStack(spacing: 12) {
      Button {
        entryPresentation = .edit(entry)
      } label: {
        Image(systemName: "pencil")
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
      .accessibilityLabel("Edit \(entry.note ?? entry.kind)")
      Button(role: .destructive) {
        pendingDelete = entry
        showingDeleteConfirmation = true
      } label: {
        Image(systemName: "trash")
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
      .accessibilityLabel("Delete \(entry.note ?? entry.kind)")
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
        if dynamicTypeSize.isAccessibilitySize {
          Text(actualSummary)
            .accessibilityIdentifier("Spending against monthly plan")
        }
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
        .chartXAxis {
          AxisMarks(values: .stride(by: 5)) { _ in
            AxisGridLine()
            AxisTick()
            if !dynamicTypeSize.isAccessibilitySize {
              AxisValueLabel().font(.body).foregroundStyle(.primary)
            }
          }
        }
        .chartYAxis {
          AxisMarks { _ in
            AxisGridLine()
            AxisTick()
            if !dynamicTypeSize.isAccessibilitySize {
              AxisValueLabel(format: .currency(code: budget.currencyCode))
                .font(.body)
                .foregroundStyle(.primary)
            }
          }
        }
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

  private var addEntryToolbarPlacement: ToolbarItemPlacement {
    #if os(macOS)
      .primaryAction
    #else
      .topBarTrailing
    #endif
  }

  private var fractionDigits: Int {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    return formatter.maximumFractionDigits
  }

  private var minorIncome: Int64? {
    guard let income = Decimal(string: incomeText, locale: Locale.current), income > 0,
      let value = try? Money.minorUnits(for: income, fractionDigits: fractionDigits), value > 0
    else { return nil }
    return value
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
    incomeFieldFocused = false
    let budget = BudgetMonth(
      year: year, month: month, mode: selectedMode.rawValue, currencyCode: currency)
    let initialIncome = LedgerEntry(
      amountMinor: minorIncome, currencyCode: currency, fractionDigits: fractionDigits,
      kind: "income", category: "income", occurredAt: selectedMonth)
    do {
      try BudgetStore(context: context).createBudget(budget, income: initialIncome)
      section = .budget
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

#Preview("Budget setup") {
  ContentView()
    .modelContainer(
      for: [BudgetMonth.self, LedgerEntry.self, CloudTombstone.self], inMemory: true)
}

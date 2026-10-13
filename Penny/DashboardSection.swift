enum DashboardSection: String, CaseIterable, Identifiable {
  case budget = "Budget"
  case activity = "Activity"
  case reports = "Reports"

  var id: Self { self }

  var systemImage: String {
    switch self {
    case .budget: "chart.pie"
    case .activity: "list.bullet.rectangle"
    case .reports: "chart.bar.xaxis"
    }
  }
}

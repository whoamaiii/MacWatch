import SwiftUI
import ClarityShared

/// Apps view showing usage breakdown by application
struct AppsView: View {
    @StateObject private var viewModel = AppsViewModel()
    @State private var selectedPeriod: TimePeriod = .today
    @State private var sortBy: SortOption = .time
    @State private var selectedApp: DataService.AppUsageDisplay?
    @State private var searchText = ""

    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    enum SortOption: String, CaseIterable {
        case time = "Time"
        case keystrokes = "Keystrokes"
        case name = "Name"
    }

    private var filteredApps: [DataService.AppUsageDisplay] {
        viewModel.apps.filter { app in
            searchText.isEmpty || app.name.localizedCaseInsensitiveContains(searchText)
        }.sorted { a, b in
            switch sortBy {
            case .time: return a.durationSeconds > b.durationSeconds
            case .keystrokes: return a.keystrokes > b.keystrokes
            case .name: return a.name < b.name
            }
        }
    }

    private var totalTime: Int {
        viewModel.apps.reduce(0) { $0 + $1.durationSeconds }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Filters
                filtersRow

                // Overview cards
                overviewCards

                // Category breakdown
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("By Category")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.apps.isEmpty {
                            Text("No activity recorded yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            categoryChart
                        }
                    }
                }

                // App list
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack {
                            Text("Applications")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)

                            Spacer()

                            // Search
                            HStack(spacing: ClaritySpacing.xs) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(ClarityColors.textTertiary)
                                TextField("Search apps...", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(ClarityTypography.body)
                            }
                            .padding(.horizontal, ClaritySpacing.sm)
                            .padding(.vertical, ClaritySpacing.xs)
                            .background(ClarityColors.backgroundSecondary)
                            .clipShape(Capsule())
                            .frame(width: 200)
                        }

                        appList
                    }
                }
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .task {
            await viewModel.load(period: selectedPeriod)
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task {
                await viewModel.load(period: newPeriod)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Applications")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Usage breakdown by app")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Filters

    private var filtersRow: some View {
        HStack(spacing: ClaritySpacing.md) {
            // Period picker
            HStack(spacing: ClaritySpacing.xs) {
                ForEach(TimePeriod.allCases, id: \.self) { period in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedPeriod = period
                        }
                    }) {
                        Text(period.rawValue)
                            .font(ClarityTypography.captionMedium)
                            .foregroundColor(selectedPeriod == period ? .white : ClarityColors.textSecondary)
                            .padding(.horizontal, ClaritySpacing.sm)
                            .padding(.vertical, ClaritySpacing.xs)
                            .background(
                                selectedPeriod == period
                                    ? ClarityColors.accentPrimary
                                    : ClarityColors.backgroundSecondary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Sort picker
            HStack(spacing: ClaritySpacing.xs) {
                Text("Sort by:")
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)

                Picker("", selection: $sortBy) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
    }

    // MARK: - Overview Cards

    private var overviewCards: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                title: "Total Active",
                value: formatDuration(totalTime),
                icon: ClarityIcons.time,
                color: ClarityColors.accentPrimary
            )

            StatCard(
                title: "Apps Used",
                value: "\(viewModel.apps.count)",
                icon: "app.badge",
                color: ClarityColors.deepFocus
            )

            StatCard(
                title: "Most Used",
                value: viewModel.apps.first?.name ?? "—",
                icon: "star.fill",
                color: ClarityColors.productivity
            )

            StatCard(
                title: "Top Category",
                value: viewModel.topCategory?.rawValue.capitalized ?? "—",
                icon: "folder.fill",
                color: ClarityColors.communication
            )
        }
    }

    // MARK: - Category Chart

    private var categoryChart: some View {
        HStack(spacing: ClaritySpacing.lg) {
            // Pie chart placeholder
            ZStack {
                ForEach(Array(viewModel.categoryData.enumerated()), id: \.offset) { index, data in
                    Circle()
                        .trim(from: data.startAngle, to: data.endAngle)
                        .stroke(data.color, lineWidth: 30)
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 150, height: 150)

            // Legend
            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                ForEach(viewModel.categoryData, id: \.name) { data in
                    HStack(spacing: ClaritySpacing.sm) {
                        Circle()
                            .fill(data.color)
                            .frame(width: 10, height: 10)

                        Text(data.name)
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)

                        Spacer()

                        Text(data.duration)
                            .font(ClarityTypography.mono)
                            .foregroundColor(ClarityColors.textSecondary)

                        Text("\(Int(data.percentage * 100))%")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, ClaritySpacing.sm)
    }

    // MARK: - App List

    private var appList: some View {
        VStack(spacing: ClaritySpacing.xs) {
            if filteredApps.isEmpty {
                Text("No activity recorded yet")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Header row
                HStack {
                    Text("App")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Time")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(width: 80, alignment: .trailing)

                    Text("Keys")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(width: 80, alignment: .trailing)

                    Text("Clicks")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(width: 60, alignment: .trailing)

                    Text("")
                        .frame(width: 150)
                }
                .padding(.horizontal, ClaritySpacing.sm)
                .padding(.bottom, ClaritySpacing.xs)

                Divider()

                ForEach(filteredApps) { app in
                    AppRowItem(app: app, totalTime: totalTime, isSelected: selectedApp?.id == app.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedApp = selectedApp?.id == app.id ? nil : app
                            }
                        }
                }
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - App Row Item

struct AppRowItem: View {
    let app: DataService.AppUsageDisplay
    let totalTime: Int
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // App icon
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(app.category.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 14))
                                .foregroundColor(app.category.color)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text(app.category.rawValue.capitalized)
                        .font(.system(size: 11))
                        .foregroundColor(ClarityColors.textTertiary)
                }

                Spacer()

                Text(app.duration)
                    .font(ClarityTypography.mono)
                    .foregroundColor(ClarityColors.textPrimary)
                    .frame(width: 80, alignment: .trailing)

                Text(formatNumber(app.keystrokes))
                    .font(ClarityTypography.mono)
                    .foregroundColor(ClarityColors.textSecondary)
                    .frame(width: 80, alignment: .trailing)

                Text("\(app.clicks)")
                    .font(ClarityTypography.mono)
                    .foregroundColor(ClarityColors.textSecondary)
                    .frame(width: 60, alignment: .trailing)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ClarityColors.backgroundSecondary)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(app.category.color)
                            .frame(width: geo.size.width * (Double(app.durationSeconds) / Double(max(totalTime, 1))))
                    }
                }
                .frame(width: 150, height: 6)
            }
            .padding(.horizontal, ClaritySpacing.sm)
            .padding(.vertical, ClaritySpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? ClarityColors.backgroundSecondary : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - ViewModel

@MainActor
class AppsViewModel: ObservableObject {
    @Published var apps: [DataService.AppUsageDisplay] = []
    @Published var categoryData: [CategoryDisplayData] = []
    @Published var topCategory: AppCategory?
    @Published var isLoading = true

    private let dataService = DataService.shared

    struct CategoryDisplayData: Identifiable {
        let id = UUID()
        let name: String
        let duration: String
        let percentage: Double
        let color: Color
        let startAngle: Double
        let endAngle: Double
    }

    func load(period: AppsView.TimePeriod) async {
        isLoading = true
        defer { isLoading = false }

        let (startDate, endDate) = getDateRange(for: period)

        // Get all apps for the date range
        apps = await dataService.getTopApps(for: startDate, limit: 100)

        // Calculate category breakdown
        calculateCategoryData()
    }

    private func getDateRange(for period: AppsView.TimePeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return (weekAgo, now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return (monthAgo, now)
        }
    }

    private func calculateCategoryData() {
        // Group by category
        var categoryTotals: [AppCategory: Int] = [:]
        for app in apps {
            categoryTotals[app.category, default: 0] += app.durationSeconds
        }

        let totalSeconds = categoryTotals.values.reduce(0, +)
        guard totalSeconds > 0 else {
            categoryData = []
            topCategory = nil
            return
        }

        // Sort by time and take top 5
        let sorted = categoryTotals.sorted { $0.value > $1.value }
        topCategory = sorted.first?.key

        var runningAngle: Double = 0
        categoryData = sorted.prefix(5).map { category, seconds in
            let percentage = Double(seconds) / Double(totalSeconds)
            let startAngle = runningAngle
            let endAngle = startAngle + percentage
            runningAngle = endAngle

            return CategoryDisplayData(
                name: category.rawValue.capitalized,
                duration: formatDuration(seconds),
                percentage: percentage,
                color: category.color,
                startAngle: startAngle,
                endAngle: endAngle
            )
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    AppsView()
        .frame(width: 900, height: 800)
}

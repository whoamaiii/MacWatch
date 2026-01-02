import SwiftUI
import ClarityShared

/// Weekly summary view showing stats, trends, heatmap, and top apps
struct WeeklySummaryView: View {
    @StateObject private var viewModel = WeeklySummaryViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header with week selector
                header

                if viewModel.isLoading {
                    loadingView
                } else {
                    // Hero stats with trends
                    heroStats

                    // Daily breakdown chart
                    dailyBreakdownCard

                    // Productivity heatmap
                    heatmapCard

                    // Top apps for the week
                    topAppsCard

                    // Week-over-week insights
                    insightsCard
                }

                Spacer(minLength: ClaritySpacing.xxl)
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Weekly Summary")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text(viewModel.weekRangeString)
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textTertiary)
            }

            Spacer()

            // Week navigation
            HStack(spacing: ClaritySpacing.sm) {
                Button {
                    Task { await viewModel.previousWeek() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(ClarityColors.textSecondary)

                Button {
                    Task { await viewModel.currentWeek() }
                } label: {
                    Text("This Week")
                        .font(ClarityTypography.captionMedium)
                }
                .buttonStyle(.plain)
                .foregroundColor(ClarityColors.accentPrimary)

                Button {
                    Task { await viewModel.nextWeek() }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundColor(ClarityColors.textSecondary)
                .disabled(viewModel.isCurrentWeek)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ClaritySpacing.lg) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonView(height: 120)
                    .cornerRadius(ClarityRadius.md)
            }
        }
    }

    // MARK: - Hero Stats

    private var heroStats: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                icon: ClarityIcons.time,
                value: viewModel.summary?.formattedActiveTime ?? "0m",
                label: "Total Active",
                comparison: viewModel.activeTimeTrend
            )

            StatCard(
                icon: ClarityIcons.keystrokes,
                value: formatNumber(viewModel.summary?.totalKeystrokes ?? 0),
                label: "Keystrokes",
                comparison: viewModel.keystrokesTrend
            )

            StatCard(
                icon: "target",
                value: "\(viewModel.summary?.averageFocusScore ?? 0)%",
                label: "Avg Focus",
                comparison: viewModel.focusTrend
            )

            StatCard(
                icon: "app.badge",
                value: "\(viewModel.comparison.current.uniqueApps)",
                label: "Apps Used",
                comparison: viewModel.appsTrend
            )
        }
    }

    // MARK: - Daily Breakdown

    private var dailyBreakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                HStack {
                    Text("Daily Breakdown")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    Text("Avg: \(viewModel.summary?.averageDailyActiveTime ?? "0m")/day")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                if let summary = viewModel.summary {
                    DailyBarChart(data: summary.dailyBreakdown)
                } else {
                    Text("No data available")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                HStack {
                    Text("Productivity Patterns")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    Text("Last 4 weeks")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                ProductivityHeatmap(data: viewModel.heatmapData)
            }
        }
    }

    // MARK: - Top Apps

    private var topAppsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                Text("Top Apps This Week")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                if let summary = viewModel.summary, !summary.topApps.isEmpty {
                    VStack(spacing: ClaritySpacing.xs) {
                        ForEach(summary.topApps) { app in
                            AppRowView(
                                name: app.name,
                                icon: app.icon,
                                duration: app.duration,
                                progress: app.percentage,
                                color: app.color
                            )

                            if app.id != summary.topApps.last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                } else {
                    Text("No apps tracked this week")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundColor(ClarityColors.warning)

                    Text("Week-over-Week")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                    ForEach(viewModel.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: ClaritySpacing.sm) {
                            Image(systemName: insight.icon)
                                .font(.caption)
                                .foregroundColor(insight.color)
                                .frame(width: 16)

                            Text(insight.text)
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Daily Bar Chart

struct DailyBarChart: View {
    let data: [DataService.WeeklySummary.DailyData]

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var maxSeconds: Int {
        data.map { $0.activeSeconds }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: ClaritySpacing.sm) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, dayData in
                VStack(spacing: ClaritySpacing.xs) {
                    // Bar
                    let height = maxSeconds > 0
                        ? CGFloat(dayData.activeSeconds) / CGFloat(maxSeconds) * 100
                        : 0

                    VStack(spacing: 2) {
                        if dayData.activeSeconds > 0 {
                            Text(formatDuration(dayData.activeSeconds))
                                .font(.system(size: 9))
                                .foregroundColor(ClarityColors.textTertiary)
                        }

                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(for: dayData))
                            .frame(height: max(4, height))
                    }

                    // Day label
                    Text(dayLabels[index])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isToday(dayData.date) ? ClarityColors.accentPrimary : ClarityColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 140)
    }

    private func barColor(for dayData: DataService.WeeklySummary.DailyData) -> Color {
        if isToday(dayData.date) {
            return ClarityColors.accentPrimary
        }
        if dayData.activeSeconds == 0 {
            return ClarityColors.backgroundSecondary
        }
        return ClarityColors.accentPrimary.opacity(0.6)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Insight Model

struct WeeklyInsight: Hashable {
    let text: String
    let icon: String
    let color: Color
}

// MARK: - ViewModel

@MainActor
class WeeklySummaryViewModel: ObservableObject {
    @Published var summary: DataService.WeeklySummary?
    @Published var comparison: DataService.TrendComparison = DataService.TrendComparison(
        current: .init(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0),
        previous: .init(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0)
    )
    @Published var heatmapData: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    @Published var isLoading = true
    @Published var selectedWeekStart: Date?

    private let dataService = DataService.shared
    private let calendar = Calendar.current

    var weekRangeString: String {
        guard let summary = summary else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: summary.weekStart)
        guard let endDate = calendar.date(byAdding: .day, value: -1, to: summary.weekEnd) else {
            return start
        }
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }

    var isCurrentWeek: Bool {
        guard let selectedWeekStart = selectedWeekStart else { return true }
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
            return true
        }
        return selectedWeekStart >= currentWeekStart
    }

    // MARK: - Trend Comparisons

    var activeTimeTrend: StatCard.Comparison? {
        guard let trend = comparison.trendString(for: \.activeSeconds) else { return nil }
        let change = comparison.percentChange(for: \.activeSeconds) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    var keystrokesTrend: StatCard.Comparison? {
        guard let trend = comparison.trendString(for: \.keystrokes) else { return nil }
        let change = comparison.percentChange(for: \.keystrokes) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    var focusTrend: StatCard.Comparison? {
        guard let trend = comparison.trendString(for: \.focusScore) else { return nil }
        let change = comparison.percentChange(for: \.focusScore) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    var appsTrend: StatCard.Comparison? {
        guard let trend = comparison.trendString(for: \.uniqueApps) else { return nil }
        let change = comparison.percentChange(for: \.uniqueApps) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    // MARK: - Insights

    var insights: [WeeklyInsight] {
        var result: [WeeklyInsight] = []

        // Active time insight
        if let change = comparison.percentChange(for: \.activeSeconds) {
            if change > 10 {
                result.append(WeeklyInsight(
                    text: "You were \(Int(change))% more active this week compared to last week.",
                    icon: "arrow.up.circle.fill",
                    color: ClarityColors.success
                ))
            } else if change < -10 {
                result.append(WeeklyInsight(
                    text: "Activity decreased by \(Int(abs(change)))% compared to last week.",
                    icon: "arrow.down.circle.fill",
                    color: ClarityColors.warning
                ))
            } else {
                result.append(WeeklyInsight(
                    text: "Your activity level is consistent with last week.",
                    icon: "equal.circle.fill",
                    color: ClarityColors.textTertiary
                ))
            }
        }

        // Focus score insight
        if let change = comparison.percentChange(for: \.focusScore) {
            if change > 5 {
                result.append(WeeklyInsight(
                    text: "Focus improved by \(Int(change))% - great concentration!",
                    icon: "target",
                    color: ClarityColors.success
                ))
            } else if change < -5 {
                result.append(WeeklyInsight(
                    text: "Focus dropped by \(Int(abs(change)))%. Try reducing context switches.",
                    icon: "exclamationmark.triangle.fill",
                    color: ClarityColors.warning
                ))
            }
        }

        // Peak productivity insight
        if let summary = summary {
            let peakDay = summary.dailyBreakdown.max { $0.activeSeconds < $1.activeSeconds }
            if let peak = peakDay, peak.activeSeconds > 0 {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEEE"
                let dayName = dayFormatter.string(from: peak.date)
                result.append(WeeklyInsight(
                    text: "\(dayName) was your most productive day this week.",
                    icon: "star.fill",
                    color: ClarityColors.accentPrimary
                ))
            }
        }

        if result.isEmpty {
            result.append(WeeklyInsight(
                text: "Keep tracking to generate personalized insights!",
                icon: "sparkles",
                color: ClarityColors.textTertiary
            ))
        }

        return result
    }

    // MARK: - Actions

    func load() async {
        isLoading = true
        defer { isLoading = false }

        summary = await dataService.getWeeklySummary(for: selectedWeekStart)
        if let summary = summary {
            comparison = summary.comparison
        }
        heatmapData = await dataService.getProductivityHeatmap(weeks: 4)
    }

    func previousWeek() async {
        let current = selectedWeekStart ?? calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        selectedWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: current)
        await load()
    }

    func nextWeek() async {
        guard !isCurrentWeek else { return }
        if let current = selectedWeekStart {
            selectedWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: current)
        }
        await load()
    }

    func currentWeek() async {
        selectedWeekStart = nil
        await load()
    }
}

#Preview {
    WeeklySummaryView()
        .frame(width: 900, height: 900)
}

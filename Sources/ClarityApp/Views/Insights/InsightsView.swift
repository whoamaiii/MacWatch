import SwiftUI
import ClarityShared

/// Insights view showing patterns and recommendations
struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @ObservedObject private var recommendationEngine = RecommendationEngine.shared  // Singleton - use @ObservedObject
    @ObservedObject private var permissionManager = PermissionManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Stats summary
                statsSummary

                // Smart Recommendations
                smartRecommendationsCard

                // Current status
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Current Status")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.totalActiveSeconds == 0 {
                            Text("Start using Clarity to generate insights about your work patterns.")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            currentStatus
                        }
                    }
                }

                // Top apps
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Most Used Apps Today")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.topApps.isEmpty {
                            Text("No apps tracked yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            topAppsList
                        }
                    }
                }

                // Productivity Trends
                GlassCard {
                    ProductivityTrendsView()
                }

                // Weekly Report
                GlassCard {
                    WeeklyReportView()
                }

                // Activity Heatmap
                GlassCard {
                    ActivityHeatmapSection()
                }

                // Window Insights
                GlassCard {
                    WindowInsights()
                }

                // Getting started guide
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Getting Started")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        gettingStartedGuide
                    }
                }

                // Privacy note
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack(spacing: ClaritySpacing.sm) {
                            Image(systemName: "lock.shield.fill")
                                .font(.title2)
                                .foregroundColor(ClarityColors.success)

                            Text("Your Privacy")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)
                        }

                        Text("All your data stays on this device. Clarity never sends any information to external servers. Your usage data is 100% local and private.")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textSecondary)
                    }
                }
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .task {
            await viewModel.load()
            await recommendationEngine.generateRecommendations()
        }
    }

    // MARK: - Smart Recommendations

    private var smartRecommendationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(ClarityColors.warning)

                    Text("Smart Insights")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    Button {
                        Task {
                            await recommendationEngine.generateRecommendations()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                if recommendationEngine.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Analyzing your patterns...")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                    .padding()
                } else if recommendationEngine.recommendations.isEmpty {
                    Text("Keep tracking to receive personalized insights")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(spacing: ClaritySpacing.sm) {
                        ForEach(recommendationEngine.recommendations) { rec in
                            RecommendationRow(recommendation: rec)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Insights")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Patterns and recommendations based on your activity")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Stats Summary

    private var statsSummary: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                title: "Active Time",
                value: viewModel.formattedActiveTime,
                icon: ClarityIcons.time,
                color: ClarityColors.accentPrimary
            )

            StatCard(
                title: "Focus Score",
                value: "\(viewModel.focusScore)%",
                icon: "target",
                color: ClarityColors.deepFocus
            )

            StatCard(
                title: "Keystrokes",
                value: formatNumber(viewModel.totalKeystrokes),
                icon: ClarityIcons.keystrokes,
                color: ClarityColors.productivity
            )

            StatCard(
                title: "Apps Used",
                value: "\(viewModel.appsUsed)",
                icon: "app.badge",
                color: ClarityColors.communication
            )
        }
    }

    // MARK: - Current Status

    private var currentStatus: some View {
        VStack(spacing: ClaritySpacing.md) {
            HStack(spacing: ClaritySpacing.xl) {
                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Today's Active Time")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text(viewModel.formattedActiveTime)
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Focus Score")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text("\(viewModel.focusScore)%")
                        .font(ClarityTypography.title1)
                        .foregroundColor(viewModel.focusScore >= 70 ? ClarityColors.success : ClarityColors.warning)
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Total Input")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text("\(formatNumber(viewModel.totalKeystrokes + viewModel.totalClicks)) actions")
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                Spacer()
            }

            if viewModel.focusScore > 0 {
                Divider()

                HStack {
                    Image(systemName: viewModel.focusScore >= 70 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.focusScore >= 70 ? ClarityColors.success : ClarityColors.warning)

                    Text(viewModel.focusScore >= 70
                         ? "Great focus today! You're maintaining good concentration."
                         : "Consider reducing context switches to improve your focus score.")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Top Apps List

    private var topAppsList: some View {
        VStack(spacing: ClaritySpacing.sm) {
            ForEach(viewModel.topApps) { app in
                HStack(spacing: ClaritySpacing.md) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 32, height: 32)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(app.color.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(app.color)
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

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(app.duration)
                            .font(ClarityTypography.mono)
                            .foregroundColor(ClarityColors.textPrimary)

                        Text("\(Int(app.percentage * 100))%")
                            .font(.system(size: 11))
                            .foregroundColor(ClarityColors.textTertiary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ClarityColors.backgroundSecondary)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(app.color)
                                .frame(width: geo.size.width * app.percentage)
                        }
                    }
                    .frame(width: 80, height: 6)
                }
            }
        }
    }

    // MARK: - Getting Started Guide

    private var gettingStartedGuide: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            guideRow(
                number: 1,
                title: "Run the Daemon",
                description: "Start ClarityDaemon to begin tracking your activity",
                isComplete: viewModel.totalActiveSeconds > 0
            )

            guideRow(
                number: 2,
                title: "Grant Permissions",
                description: "Allow Accessibility access for window and input tracking",
                isComplete: permissionManager.hasAccessibilityPermission
            )

            guideRow(
                number: 3,
                title: "Use Your Mac Normally",
                description: "Clarity tracks your activity in the background automatically",
                isComplete: viewModel.totalActiveSeconds > 0
            )

            guideRow(
                number: 4,
                title: "Check Your Stats",
                description: "Come back to see your productivity insights",
                isComplete: viewModel.totalActiveSeconds > 0
            )
        }
    }

    private func guideRow(number: Int, title: String, description: String, isComplete: Bool) -> some View {
        HStack(spacing: ClaritySpacing.md) {
            ZStack {
                Circle()
                    .fill(isComplete ? ClarityColors.success : ClarityColors.backgroundSecondary)
                    .frame(width: 28, height: 28)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(isComplete ? ClarityColors.textPrimary : ClarityColors.textSecondary)

                Text(description)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
            }

            Spacer()
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
class InsightsViewModel: ObservableObject {
    @Published var totalActiveSeconds: Int = 0
    @Published var totalKeystrokes: Int = 0
    @Published var totalClicks: Int = 0
    @Published var focusScore: Int = 0
    @Published var appsUsed: Int = 0
    @Published var topApps: [DataService.AppUsageDisplay] = []
    @Published var isLoading = true

    private let dataService = DataService.shared

    var formattedActiveTime: String {
        let hours = totalActiveSeconds / 3600
        let minutes = (totalActiveSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let stats = await dataService.getStats(for: Date())
        totalActiveSeconds = stats.activeTimeSeconds
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks
        focusScore = stats.focusScore

        topApps = await dataService.getTopApps(for: Date(), limit: 5)
        appsUsed = await dataService.getUniqueAppCount(for: Date())
    }
}

// MARK: - Recommendation Row

struct RecommendationRow: View {
    let recommendation: RecommendationEngine.Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: ClaritySpacing.md) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(recommendation.color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: recommendation.icon)
                    .font(.system(size: 14))
                    .foregroundColor(recommendation.color)
            }

            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text(recommendation.title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text(recommendation.message)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(ClaritySpacing.sm)
        .background(recommendation.color.opacity(0.05))
        .cornerRadius(ClarityRadius.md)
    }
}

// MARK: - Activity Heatmap Section

struct ActivityHeatmapSection: View {
    @StateObject private var viewModel = CalendarHeatmapViewModel()
    @State private var selectedMetric: CalendarHeatmap.HeatmapMetric = .activeTime

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            HStack {
                Text("Activity History")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                // Metric picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(CalendarHeatmap.HeatmapMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else {
                CalendarHeatmap(
                    data: dataForMetric(selectedMetric),
                    weeks: 12,
                    metric: selectedMetric
                )
            }
        }
        .task {
            await viewModel.load(weeks: 12)
        }
    }

    private func dataForMetric(_ metric: CalendarHeatmap.HeatmapMetric) -> [Date: Int] {
        switch metric {
        case .activeTime:
            return viewModel.activeTimeData
        case .focusScore:
            return viewModel.focusScoreData
        case .keystrokes:
            return viewModel.keystrokesData
        }
    }
}

#Preview {
    InsightsView()
        .frame(width: 900, height: 800)
}

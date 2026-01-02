import SwiftUI
import ClarityShared

/// Main dashboard view showing today's overview
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var streak: DataService.StreakData?

    var body: some View {
        ScrollView {
            VStack(spacing: ClaritySpacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                        Text("Today")
                            .font(ClarityTypography.displayMedium)
                            .foregroundColor(ClarityColors.textPrimary)

                        Text(Date(), style: .date)
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textTertiary)
                    }

                    Spacer()

                    // Streak indicator
                    if let streak = streak, streak.currentStreak > 0 {
                        HStack(spacing: ClaritySpacing.xs) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(ClarityColors.warning)

                            Text("\(streak.currentStreak) day streak")
                                .font(ClarityTypography.bodyMedium)
                                .foregroundColor(ClarityColors.textPrimary)
                        }
                        .padding(.horizontal, ClaritySpacing.md)
                        .padding(.vertical, ClaritySpacing.sm)
                        .background(ClarityColors.warning.opacity(0.1))
                        .cornerRadius(ClarityRadius.md)
                    }

                    // Refresh button
                    Button {
                        Task {
                            await viewModel.refresh()
                            streak = await DataService.shared.getStreak()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(ClarityColors.textTertiary)
                }
                .padding(.horizontal, ClaritySpacing.lg)
                .padding(.top, ClaritySpacing.lg)

                // Hero Stats with trend comparisons
                HeroStatsView(
                    activeTime: viewModel.activeTime,
                    keystrokes: viewModel.keystrokes,
                    clicks: viewModel.clicks,
                    focusScore: viewModel.focusScore,
                    activeTimeTrend: viewModel.activeTimeTrend,
                    keystrokesTrend: viewModel.keystrokesTrend,
                    clicksTrend: viewModel.clicksTrend,
                    focusTrend: viewModel.focusTrend
                )
                .padding(.horizontal, ClaritySpacing.lg)

                // Timeline
                VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                    Text("Today's Rhythm")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    GlassCard(padding: ClaritySpacing.md) {
                        if viewModel.timelineSegments.isEmpty {
                            Text("No activity recorded yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            TimelineRibbon(segments: viewModel.timelineSegments)
                        }
                    }
                }
                .padding(.horizontal, ClaritySpacing.lg)

                // Top Apps
                VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                    HStack {
                        Text("Top Apps")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        Spacer()
                    }

                    GlassCard {
                        VStack(spacing: ClaritySpacing.xs) {
                            if viewModel.isLoading {
                                ForEach(0..<5, id: \.self) { _ in
                                    HStack {
                                        SkeletonView(height: 32)
                                            .frame(width: 32)
                                            .cornerRadius(8)
                                        SkeletonView(height: 16)
                                        Spacer()
                                        SkeletonView(height: 16)
                                            .frame(width: 60)
                                    }
                                    .padding(.vertical, 4)
                                }
                            } else if viewModel.topApps.isEmpty {
                                Text("No activity recorded yet")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(viewModel.topApps) { app in
                                    AppRowView(
                                        name: app.name,
                                        icon: app.icon,
                                        duration: app.duration,
                                        progress: app.percentage,
                                        color: app.color
                                    )

                                    if app.id != viewModel.topApps.last?.id {
                                        Divider()
                                            .opacity(0.5)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, ClaritySpacing.lg)

                // Daily Goals Progress
                DailyGoalsCard(
                    activeTimeSeconds: viewModel.activeTimeSeconds,
                    keystrokes: viewModel.keystrokes,
                    focusScore: viewModel.focusScore
                )
                .padding(.horizontal, ClaritySpacing.lg)

                // Goal Streaks
                GlassCard {
                    GoalStreakCard()
                }
                .padding(.horizontal, ClaritySpacing.lg)

                // Focus Score Breakdown
                GlassCard {
                    FocusScoreBreakdown(
                        focusScore: viewModel.focusScore,
                        activeTimeSeconds: viewModel.activeTimeSeconds,
                        contextSwitches: viewModel.contextSwitches,
                        deepWorkMinutes: viewModel.deepWorkMinutes,
                        distractionMinutes: viewModel.distractionMinutes
                    )
                }
                .padding(.horizontal, ClaritySpacing.lg)

                // Hourly Breakdown
                VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                    Text("Hourly Activity")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    GlassCard {
                        HourlyBarChart(data: viewModel.hourlyData)
                    }
                }
                .padding(.horizontal, ClaritySpacing.lg)

                Spacer(minLength: ClaritySpacing.xxl)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await viewModel.load()
            streak = await DataService.shared.getStreak()
        }
    }
}

// MARK: - Hero Stats

struct HeroStatsView: View {
    let activeTime: String
    let keystrokes: Int
    let clicks: Int
    let focusScore: Int
    var activeTimeTrend: StatCard.Comparison? = nil
    var keystrokesTrend: StatCard.Comparison? = nil
    var clicksTrend: StatCard.Comparison? = nil
    var focusTrend: StatCard.Comparison? = nil

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                icon: ClarityIcons.time,
                value: activeTime,
                label: "Active Time",
                comparison: activeTimeTrend
            )

            StatCard(
                icon: ClarityIcons.keystrokes,
                value: formatNumber(keystrokes),
                label: "Keystrokes",
                comparison: keystrokesTrend
            )

            StatCard(
                icon: ClarityIcons.clicks,
                value: formatNumber(clicks),
                label: "Clicks",
                comparison: clicksTrend
            )

            StatCard(
                icon: ClarityIcons.focusScore,
                value: "\(focusScore)%",
                label: "Focus Score",
                comparison: focusTrend
            )
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
class DashboardViewModel: ObservableObject {
    @Published var activeTime: String = "0h 0m"
    @Published var activeTimeSeconds: Int = 0
    @Published var keystrokes: Int = 0
    @Published var clicks: Int = 0
    @Published var focusScore: Int = 0
    @Published var topApps: [DataService.AppUsageDisplay] = []
    @Published var timelineSegments: [TimelineSegment] = []
    @Published var hourlyData: [Int: Int] = [:]
    @Published var isLoading = true

    // Focus score breakdown data
    @Published var contextSwitches: Int = 0
    @Published var deepWorkMinutes: Int = 0
    @Published var distractionMinutes: Int = 0

    // Trend comparisons (today vs yesterday)
    @Published var comparison: DataService.TrendComparison?

    private let dataService = DataService.shared

    // MARK: - Computed Trends

    var activeTimeTrend: StatCard.Comparison? {
        guard let comparison = comparison,
              let trend = comparison.trendString(for: \.activeSeconds) else { return nil }
        let change = comparison.percentChange(for: \.activeSeconds) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    var keystrokesTrend: StatCard.Comparison? {
        guard let comparison = comparison,
              let trend = comparison.trendString(for: \.keystrokes) else { return nil }
        let change = comparison.percentChange(for: \.keystrokes) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    var clicksTrend: StatCard.Comparison? {
        guard let comparison = comparison,
              let trend = comparison.trendString(for: \.clicks) else { return nil }
        let change = comparison.percentChange(for: \.clicks) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    var focusTrend: StatCard.Comparison? {
        guard let comparison = comparison,
              let trend = comparison.trendString(for: \.focusScore) else { return nil }
        let change = comparison.percentChange(for: \.focusScore) ?? 0
        if change > 0 { return .up(trend) }
        if change < 0 { return .down(trend) }
        return .neutral(trend)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await dataService.loadTodayData()

        // Update from data service
        activeTime = dataService.todayStats.formattedActiveTime
        activeTimeSeconds = dataService.todayStats.activeTimeSeconds
        keystrokes = dataService.todayStats.keystrokes
        clicks = dataService.todayStats.clicks
        focusScore = dataService.todayStats.focusScore
        topApps = dataService.topApps
        hourlyData = dataService.hourlyBreakdown

        // Focus score breakdown data
        contextSwitches = dataService.todayStats.contextSwitches
        deepWorkMinutes = dataService.todayStats.deepWorkMinutes
        distractionMinutes = dataService.todayStats.distractionMinutes

        // Fetch today vs yesterday comparison
        comparison = await dataService.getTodayVsYesterday()

        // Convert timeline segments
        let segments = await dataService.getTimelineSegments(for: Date())
        timelineSegments = segments.map { segment in
            TimelineSegment(
                appName: segment.appName,
                startTime: segment.startTime,
                durationSeconds: segment.durationSeconds,
                color: segment.color,
                keystrokes: segment.keystrokes,
                clicks: segment.clicks
            )
        }
    }

    func refresh() async {
        await load()
    }
}

// MARK: - Daily Goals Card

struct DailyGoalsCard: View {
    let activeTimeSeconds: Int
    let keystrokes: Int
    let focusScore: Int

    // Configurable daily goals (loaded from UserDefaults)
    private var activeTimeGoal: Int {
        let hours = UserDefaults.standard.object(forKey: "activeTimeGoalHours") as? Int ?? 6
        return hours * 3600
    }
    private var keystrokesGoal: Int {
        UserDefaults.standard.object(forKey: "keystrokesGoal") as? Int ?? 5000
    }
    private var focusScoreGoal: Int {
        UserDefaults.standard.object(forKey: "focusScoreGoal") as? Int ?? 70
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                HStack {
                    Text("Daily Goals")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    // Overall progress
                    let overallProgress = (activeTimeProgress + keystrokesProgress + focusProgress) / 3
                    Text("\(Int(overallProgress * 100))% complete")
                        .font(ClarityTypography.caption)
                        .foregroundColor(overallProgress >= 1 ? ClarityColors.success : ClarityColors.textTertiary)
                }

                HStack(spacing: ClaritySpacing.xl) {
                    // Active Time Goal
                    GoalRing(
                        progress: activeTimeProgress,
                        icon: ClarityIcons.time,
                        label: "Active Time",
                        current: formatTime(activeTimeSeconds),
                        goal: formatTime(activeTimeGoal),
                        color: ClarityColors.accentPrimary
                    )

                    // Keystrokes Goal
                    GoalRing(
                        progress: keystrokesProgress,
                        icon: ClarityIcons.keystrokes,
                        label: "Keystrokes",
                        current: formatNumber(keystrokes),
                        goal: formatNumber(keystrokesGoal),
                        color: ClarityColors.productivity
                    )

                    // Focus Score Goal
                    GoalRing(
                        progress: focusProgress,
                        icon: "target",
                        label: "Focus Score",
                        current: "\(focusScore)%",
                        goal: "\(focusScoreGoal)%",
                        color: ClarityColors.deepFocus
                    )
                }
            }
        }
    }

    private var activeTimeProgress: Double {
        min(1.0, Double(activeTimeSeconds) / Double(activeTimeGoal))
    }

    private var keystrokesProgress: Double {
        min(1.0, Double(keystrokes) / Double(keystrokesGoal))
    }

    private var focusProgress: Double {
        min(1.0, Double(focusScore) / Double(focusScoreGoal))
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Goal Ring

struct GoalRing: View {
    let progress: Double
    let icon: String
    let label: String
    let current: String
    let goal: String
    let color: Color

    @State private var animatedProgress: Double = 0

    private var isComplete: Bool {
        progress >= 1.0
    }

    var body: some View {
        VStack(spacing: ClaritySpacing.sm) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        isComplete ? ClarityColors.success : color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Image(systemName: isComplete ? "checkmark" : icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isComplete ? ClarityColors.success : color)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(ClarityColors.textSecondary)
                }
            }
            .frame(width: 70, height: 70)

            VStack(spacing: 2) {
                Text(label)
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("\(current) / \(goal)")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    DashboardView()
        .frame(width: 900, height: 800)
}

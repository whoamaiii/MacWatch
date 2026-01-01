import SwiftUI
import ClarityShared

/// Main dashboard view showing today's overview
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

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

                    // Refresh button
                    Button {
                        Task {
                            await viewModel.refresh()
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

                // Hero Stats
                HeroStatsView(
                    activeTime: viewModel.activeTime,
                    keystrokes: viewModel.keystrokes,
                    clicks: viewModel.clicks,
                    focusScore: viewModel.focusScore
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
        }
    }
}

// MARK: - Hero Stats

struct HeroStatsView: View {
    let activeTime: String
    let keystrokes: Int
    let clicks: Int
    let focusScore: Int

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                icon: ClarityIcons.time,
                value: activeTime,
                label: "Active Time",
                comparison: nil
            )

            StatCard(
                icon: ClarityIcons.keystrokes,
                value: formatNumber(keystrokes),
                label: "Keystrokes",
                comparison: nil
            )

            StatCard(
                icon: ClarityIcons.clicks,
                value: formatNumber(clicks),
                label: "Clicks",
                comparison: nil
            )

            StatCard(
                icon: ClarityIcons.focusScore,
                value: "\(focusScore)%",
                label: "Focus Score",
                comparison: nil
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
    @Published var keystrokes: Int = 0
    @Published var clicks: Int = 0
    @Published var focusScore: Int = 0
    @Published var topApps: [DataService.AppUsageDisplay] = []
    @Published var timelineSegments: [TimelineSegment] = []
    @Published var hourlyData: [Int: Int] = [:]
    @Published var isLoading = true

    private let dataService = DataService.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }

        await dataService.loadTodayData()

        // Update from data service
        activeTime = dataService.todayStats.formattedActiveTime
        keystrokes = dataService.todayStats.keystrokes
        clicks = dataService.todayStats.clicks
        focusScore = dataService.todayStats.focusScore
        topApps = dataService.topApps
        hourlyData = dataService.hourlyBreakdown

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

#Preview {
    DashboardView()
        .frame(width: 900, height: 800)
}

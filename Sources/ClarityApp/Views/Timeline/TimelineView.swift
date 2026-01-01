import SwiftUI
import ClarityShared

/// Timeline view showing activity over time
struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedDate = Date()
    @State private var zoomLevel: ZoomLevel = .day
    @State private var hoveredBlock: ActivityBlock?

    enum ZoomLevel: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Date navigation
                dateNavigation

                // Zoom controls
                zoomControls

                // Main timeline
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Activity Timeline")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        // Timeline grid
                        if viewModel.activityBlocks.isEmpty {
                            Text("No activity recorded for this day")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            timelineGrid
                        }
                    }
                }

                // Activity breakdown
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Activity Breakdown")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.categoryBreakdown.isEmpty {
                            Text("No activity recorded")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            activityBreakdown
                        }
                    }
                }

                // Stats for the day
                HStack(spacing: ClaritySpacing.md) {
                    StatCard(
                        title: "Active Time",
                        value: viewModel.formattedActiveTime,
                        icon: ClarityIcons.time,
                        color: ClarityColors.accentPrimary
                    )

                    StatCard(
                        title: "Keystrokes",
                        value: formatNumber(viewModel.totalKeystrokes),
                        icon: ClarityIcons.keystrokes,
                        color: ClarityColors.deepFocus
                    )

                    StatCard(
                        title: "Clicks",
                        value: formatNumber(viewModel.totalClicks),
                        icon: ClarityIcons.clicks,
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
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .task {
            await viewModel.load(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await viewModel.load(for: newDate)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Timeline")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Your activity over time")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Date Navigation

    private var dateNavigation: some View {
        HStack {
            Button(action: { navigateDate(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ClarityColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(ClarityColors.backgroundSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(formattedDate)
                .font(ClarityTypography.title2)
                .foregroundColor(ClarityColors.textPrimary)

            Spacer()

            Button(action: { navigateDate(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ClarityColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(ClarityColors.backgroundSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .padding(.horizontal, ClaritySpacing.md)
    }

    private var formattedDate: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    private func navigateDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = newDate
            }
        }
    }

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: ClaritySpacing.xs) {
            ForEach(ZoomLevel.allCases, id: \.self) { level in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        zoomLevel = level
                    }
                }) {
                    Text(level.rawValue)
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(zoomLevel == level ? .white : ClarityColors.textSecondary)
                        .padding(.horizontal, ClaritySpacing.sm)
                        .padding(.vertical, ClaritySpacing.xs)
                        .background(
                            zoomLevel == level
                                ? ClarityColors.accentPrimary
                                : ClarityColors.backgroundSecondary
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    // MARK: - Timeline Grid

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            // Hour labels
            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                    Text(hour == 0 ? "12a" : hour == 12 ? "12p" : hour == 24 ? "12a" : "\(hour % 12)\(hour < 12 ? "a" : "p")")
                        .font(.system(size: 10))
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: hour == 24 ? .trailing : .leading)
                }
            }
            .padding(.bottom, ClaritySpacing.xxs)

            // Timeline blocks
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background grid
                    HStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Rectangle()
                                .fill(hour % 2 == 0 ? ClarityColors.backgroundSecondary : ClarityColors.backgroundTertiary)
                                .frame(width: geometry.size.width / 24)
                        }
                    }

                    // Activity blocks
                    ForEach(viewModel.activityBlocks) { block in
                        activityBlockView(block: block, totalWidth: geometry.size.width)
                    }
                }
            }
            .frame(height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func activityBlockView(block: ActivityBlock, totalWidth: CGFloat) -> some View {
        let startOffset = (block.startHour / 24.0) * totalWidth
        let width = (block.duration / 24.0) * totalWidth

        return Rectangle()
            .fill(block.color)
            .frame(width: max(width, 2))
            .offset(x: startOffset)
            .opacity(hoveredBlock?.id == block.id ? 1.0 : 0.8)
            .onHover { isHovered in
                hoveredBlock = isHovered ? block : nil
            }
    }

    // MARK: - Activity Breakdown

    private var activityBreakdown: some View {
        VStack(spacing: ClaritySpacing.sm) {
            ForEach(viewModel.categoryBreakdown) { category in
                HStack(spacing: ClaritySpacing.sm) {
                    Circle()
                        .fill(category.color)
                        .frame(width: 10, height: 10)

                    Text(category.name)
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    Text(category.formattedDuration)
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textSecondary)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ClarityColors.backgroundSecondary)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(category.color)
                                .frame(width: geo.size.width * category.percentage)
                        }
                    }
                    .frame(width: 100, height: 6)
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

// MARK: - Supporting Types

struct ActivityBlock: Identifiable {
    let id = UUID()
    let startHour: Double
    let duration: Double
    let appName: String
    let category: AppCategory
    let keystrokes: Int
    let clicks: Int

    var color: Color { category.color }
}

struct CategoryBreakdown: Identifiable {
    let id = UUID()
    let name: String
    let durationSeconds: Int
    let percentage: Double
    let color: Color

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - ViewModel

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var activityBlocks: [ActivityBlock] = []
    @Published var categoryBreakdown: [CategoryBreakdown] = []
    @Published var totalActiveSeconds: Int = 0
    @Published var totalKeystrokes: Int = 0
    @Published var totalClicks: Int = 0
    @Published var appsUsed: Int = 0
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

    func load(for date: Date) async {
        isLoading = true
        defer { isLoading = false }

        // Get stats for the date
        let stats = await dataService.getStats(for: date)
        totalActiveSeconds = stats.activeTimeSeconds
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks

        // Get timeline segments
        let segments = await dataService.getTimelineSegments(for: date)
        appsUsed = Set(segments.map { $0.bundleId }).count

        // Convert to activity blocks
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        activityBlocks = segments.map { segment in
            let startHour = segment.startTime.timeIntervalSince(startOfDay) / 3600.0
            let durationHours = Double(segment.durationSeconds) / 3600.0

            return ActivityBlock(
                startHour: startHour,
                duration: durationHours,
                appName: segment.appName,
                category: AppCategory.from(bundleId: segment.bundleId),
                keystrokes: segment.keystrokes,
                clicks: segment.clicks
            )
        }

        // Calculate category breakdown
        var categoryTotals: [AppCategory: Int] = [:]
        for segment in segments {
            let category = AppCategory.from(bundleId: segment.bundleId)
            categoryTotals[category, default: 0] += segment.durationSeconds
        }

        let totalSeconds = categoryTotals.values.reduce(0, +)
        categoryBreakdown = categoryTotals.sorted { $0.value > $1.value }.map { category, seconds in
            CategoryBreakdown(
                name: category.rawValue.capitalized,
                durationSeconds: seconds,
                percentage: totalSeconds > 0 ? Double(seconds) / Double(totalSeconds) : 0,
                color: category.color
            )
        }
    }
}

#Preview {
    TimelineView()
        .frame(width: 900, height: 800)
}

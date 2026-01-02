import SwiftUI
import ClarityShared

/// Timeline view showing activity over time
struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedDate = Date()
    @State private var zoomLevel: ZoomLevel = .day
    @State private var hoveredBlock: ActivityBlock?
    @State private var hoveredDayIndex: Int?

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

                        // Timeline grid based on zoom level
                        if viewModel.activityBlocks.isEmpty && viewModel.dailyBreakdown.isEmpty {
                            Text(emptyStateMessage)
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            switch zoomLevel {
                            case .day:
                                timelineGrid
                            case .week:
                                weekTimelineGrid
                            case .month:
                                monthTimelineGrid
                            }
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

                // Stats for the period
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
            await viewModel.load(for: selectedDate, zoomLevel: zoomLevel)
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await viewModel.load(for: newDate, zoomLevel: zoomLevel)
            }
        }
        .onChange(of: zoomLevel) { _, newLevel in
            Task {
                await viewModel.load(for: selectedDate, zoomLevel: newLevel)
            }
        }
    }

    private var emptyStateMessage: String {
        switch zoomLevel {
        case .day:
            return "No activity recorded for this day"
        case .week:
            return "No activity recorded for this week"
        case .month:
            return "No activity recorded for this month"
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
            Button(action: { navigatePeriod(by: -1) }) {
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

            Button(action: { navigatePeriod(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ClarityColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(ClarityColors.backgroundSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isAtCurrentPeriod)
        }
        .padding(.horizontal, ClaritySpacing.md)
    }

    private var isAtCurrentPeriod: Bool {
        let calendar = Calendar.current
        switch zoomLevel {
        case .day:
            return calendar.isDateInToday(selectedDate)
        case .week:
            return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
        case .month:
            return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
        }
    }

    private var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        switch zoomLevel {
        case .day:
            if calendar.isDateInToday(selectedDate) {
                return "Today"
            } else if calendar.isDateInYesterday(selectedDate) {
                return "Yesterday"
            } else {
                formatter.dateFormat = "EEEE, MMM d"
                return formatter.string(from: selectedDate)
            }
        case .week:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? selectedDate

            if calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else {
                formatter.dateFormat = "MMM d"
                let startStr = formatter.string(from: weekStart)
                let endStr = formatter.string(from: weekEnd)
                return "\(startStr) - \(endStr)"
            }
        case .month:
            if calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month) {
                return "This Month"
            } else {
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: selectedDate)
            }
        }
    }

    private func navigatePeriod(by offset: Int) {
        let calendar = Calendar.current
        var newDate: Date?

        switch zoomLevel {
        case .day:
            newDate = calendar.date(byAdding: .day, value: offset, to: selectedDate)
        case .week:
            newDate = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedDate)
        case .month:
            newDate = calendar.date(byAdding: .month, value: offset, to: selectedDate)
        }

        if let date = newDate {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = date
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

    // MARK: - Week Timeline Grid

    private var weekTimelineGrid: some View {
        VStack(spacing: ClaritySpacing.sm) {
            // Day labels
            HStack(spacing: 0) {
                ForEach(viewModel.dailyBreakdown) { day in
                    Text(day.dayLabel)
                        .font(.system(size: 11))
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day bars
            GeometryReader { geometry in
                let barWidth = (geometry.size.width - CGFloat(viewModel.dailyBreakdown.count - 1) * 4) / CGFloat(max(viewModel.dailyBreakdown.count, 1))
                let maxSeconds = viewModel.dailyBreakdown.map { $0.activeSeconds }.max() ?? 1

                HStack(spacing: 4) {
                    ForEach(Array(viewModel.dailyBreakdown.enumerated()), id: \.element.id) { index, day in
                        VStack(spacing: 0) {
                            Spacer()

                            // Stacked category bars
                            VStack(spacing: 0) {
                                ForEach(day.categoryBreakdown.reversed()) { category in
                                    Rectangle()
                                        .fill(category.color)
                                        .frame(height: max(0, (CGFloat(category.seconds) / CGFloat(max(maxSeconds, 1))) * (geometry.size.height - 20)))
                                }
                            }
                            .frame(width: barWidth)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .opacity(hoveredDayIndex == index ? 1.0 : 0.85)
                            .onHover { isHovered in
                                hoveredDayIndex = isHovered ? index : nil
                            }
                        }
                    }
                }
            }
            .frame(height: 120)

            // Active time labels
            HStack(spacing: 0) {
                ForEach(viewModel.dailyBreakdown) { day in
                    Text(day.formattedDuration)
                        .font(.system(size: 10))
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Month Timeline Grid

    private var monthTimelineGrid: some View {
        VStack(spacing: ClaritySpacing.sm) {
            let calendar = Calendar.current
            let weeks = groupDaysIntoWeeks(viewModel.dailyBreakdown)
            let maxSeconds = viewModel.dailyBreakdown.map { $0.activeSeconds }.max() ?? 1

            // Weekday headers
            HStack(spacing: 2) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            VStack(spacing: 2) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { weekIndex, week in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let day = week.first(where: { calendar.component(.weekday, from: $0.date) == dayIndex + 1 }) {
                                let intensity = Double(day.activeSeconds) / Double(max(maxSeconds, 1))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(activityColor(intensity: intensity))
                                    .frame(height: 24)
                                    .overlay {
                                        Text("\(calendar.component(.day, from: day.date))")
                                            .font(.system(size: 9))
                                            .foregroundColor(intensity > 0.5 ? .white : ClarityColors.textTertiary)
                                    }
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ClarityColors.backgroundSecondary.opacity(0.3))
                                    .frame(height: 24)
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: ClaritySpacing.md) {
                Text("Less")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)

                HStack(spacing: 2) {
                    ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(activityColor(intensity: intensity))
                            .frame(width: 12, height: 12)
                    }
                }

                Text("More")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)

                Spacer()
            }
            .padding(.top, ClaritySpacing.xs)
        }
    }

    private func activityColor(intensity: Double) -> Color {
        if intensity == 0 {
            return ClarityColors.backgroundSecondary
        }
        return ClarityColors.accentPrimary.opacity(0.3 + (intensity * 0.7))
    }

    private func groupDaysIntoWeeks(_ days: [DailyBreakdown]) -> [[DailyBreakdown]] {
        let calendar = Calendar.current
        var weeks: [[DailyBreakdown]] = []
        var currentWeek: [DailyBreakdown] = []
        var currentWeekOfYear: Int?

        for day in days.sorted(by: { $0.date < $1.date }) {
            let weekOfYear = calendar.component(.weekOfYear, from: day.date)

            if let current = currentWeekOfYear, current != weekOfYear {
                if !currentWeek.isEmpty {
                    weeks.append(currentWeek)
                }
                currentWeek = []
            }

            currentWeek.append(day)
            currentWeekOfYear = weekOfYear
        }

        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
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

struct DailyBreakdown: Identifiable {
    let id = UUID()
    let date: Date
    let activeSeconds: Int
    let keystrokes: Int
    let clicks: Int
    let categoryBreakdown: [DayCategoryBreakdown]

    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var formattedDuration: String {
        let hours = activeSeconds / 3600
        let minutes = (activeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

struct DayCategoryBreakdown: Identifiable {
    let id = UUID()
    let category: AppCategory
    let seconds: Int
    var color: Color { category.color }
}

// MARK: - ViewModel

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var activityBlocks: [ActivityBlock] = []
    @Published var categoryBreakdown: [CategoryBreakdown] = []
    @Published var dailyBreakdown: [DailyBreakdown] = []
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

    func load(for date: Date, zoomLevel: TimelineView.ZoomLevel) async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current

        switch zoomLevel {
        case .day:
            await loadDayData(for: date)
        case .week:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? date
            await loadRangeData(from: weekStart, to: weekEnd, granularity: .day)
        case .month:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? date
            await loadRangeData(from: monthStart, to: monthEnd, granularity: .day)
        }
    }

    private func loadDayData(for date: Date) async {
        // Clear multi-day data
        dailyBreakdown = []

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
                category: segment.category,
                keystrokes: segment.keystrokes,
                clicks: segment.clicks
            )
        }

        // Calculate category breakdown
        var categoryTotals: [AppCategory: Int] = [:]
        for segment in segments {
            categoryTotals[segment.category, default: 0] += segment.durationSeconds
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

    private func loadRangeData(from startDate: Date, to endDate: Date, granularity: Calendar.Component) async {
        // Clear single-day data
        activityBlocks = []

        let calendar = Calendar.current

        // Get overall stats for the range
        let stats = await dataService.getStats(from: startDate, to: endDate)
        totalActiveSeconds = stats.activeTimeSeconds
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks

        // Get apps used count
        appsUsed = await dataService.getUniqueAppCount(from: startDate, to: endDate)

        // Build daily breakdown
        var days: [DailyBreakdown] = []
        var currentDate = startDate

        while currentDate < endDate {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate

            // Get segments for this day to calculate category breakdown
            let segments = await dataService.getTimelineSegments(for: currentDate)

            var categoryTotals: [AppCategory: Int] = [:]
            var dayActive = 0
            var dayKeystrokes = 0
            var dayClicks = 0

            for segment in segments {
                categoryTotals[segment.category, default: 0] += segment.durationSeconds
                dayActive += segment.durationSeconds
                dayKeystrokes += segment.keystrokes
                dayClicks += segment.clicks
            }

            let dayCategoryBreakdown = categoryTotals.map { category, seconds in
                DayCategoryBreakdown(category: category, seconds: seconds)
            }.sorted { $0.seconds > $1.seconds }

            days.append(DailyBreakdown(
                date: currentDate,
                activeSeconds: dayActive,
                keystrokes: dayKeystrokes,
                clicks: dayClicks,
                categoryBreakdown: dayCategoryBreakdown
            ))

            currentDate = dayEnd
        }

        dailyBreakdown = days

        // Calculate overall category breakdown
        var overallCategoryTotals: [AppCategory: Int] = [:]
        for day in days {
            for cat in day.categoryBreakdown {
                overallCategoryTotals[cat.category, default: 0] += cat.seconds
            }
        }

        let totalSeconds = overallCategoryTotals.values.reduce(0, +)
        categoryBreakdown = overallCategoryTotals.sorted { $0.value > $1.value }.map { category, seconds in
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

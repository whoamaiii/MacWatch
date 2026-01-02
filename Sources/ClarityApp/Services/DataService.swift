import Foundation
import SwiftUI
import ClarityShared
import AppKit

/// Central data service for the Clarity app
/// Connects to the shared database and provides real data to views
@MainActor
public final class DataService: ObservableObject {
    public static let shared = DataService()

    private let appRepository: AppRepository
    private let statsRepository: StatsRepository

    // Cached data
    @Published public var todayStats: TodayStats = TodayStats()
    @Published public var topApps: [AppUsageDisplay] = []
    @Published public var hourlyBreakdown: [Int: Int] = [:]
    @Published public var isLoading = false

    private init() {
        self.appRepository = AppRepository()
        self.statsRepository = StatsRepository()
    }

    // MARK: - Today's Stats

    public struct TodayStats {
        public var activeTimeSeconds: Int = 0
        public var keystrokes: Int = 0
        public var clicks: Int = 0
        public var focusScore: Int = 0
        public var scrollDistance: Int = 0
        public var mouseDistance: Int = 0

        // Focus score breakdown
        public var contextSwitches: Int = 0
        public var deepWorkMinutes: Int = 0
        public var distractionMinutes: Int = 0

        public var formattedActiveTime: String {
            let hours = activeTimeSeconds / 3600
            let minutes = (activeTimeSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - App Usage Display

    public struct AppUsageDisplay: Identifiable {
        public let id: Int64
        public let name: String
        public let bundleId: String
        public let icon: NSImage?
        public let duration: String
        public let durationSeconds: Int
        public let percentage: Double
        public let keystrokes: Int
        public let clicks: Int
        public let category: AppCategory

        public var color: Color {
            category.color
        }
    }

    // MARK: - Load Data

    public func loadTodayData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load today's stats
            let activeTime = try statsRepository.getTodayActiveTime()
            let keystrokes = try statsRepository.getTodayKeystrokes()

            // Get clicks from minute stats
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let minuteStats = try statsRepository.getMinuteStats(from: startOfDay, to: Date())

            let totalClicks = minuteStats.reduce(0) { $0 + $1.clicks }
            let totalScroll = minuteStats.reduce(0) { $0 + $1.scrollDistance }
            let totalMouse = minuteStats.reduce(0) { $0 + $1.mouseDistance }

            // Calculate focus score (based on longest continuous session)
            let focusScore = calculateFocusScore(from: minuteStats, totalActive: activeTime)

            // Calculate focus breakdown
            let breakdown = calculateFocusBreakdown(from: minuteStats)

            todayStats = TodayStats(
                activeTimeSeconds: activeTime,
                keystrokes: keystrokes,
                clicks: totalClicks,
                focusScore: focusScore,
                scrollDistance: totalScroll,
                mouseDistance: totalMouse,
                contextSwitches: breakdown.contextSwitches,
                deepWorkMinutes: breakdown.deepWorkMinutes,
                distractionMinutes: breakdown.distractionMinutes
            )

            // Load top apps
            let appUsages = try appRepository.getTopApps(for: Date(), limit: 10)
            let totalSeconds = appUsages.reduce(0) { $0 + $1.totalSeconds }

            topApps = appUsages.map { usage in
                let icon = getAppIcon(bundleId: usage.bundleId)
                let percentage = totalSeconds > 0 ? Double(usage.totalSeconds) / Double(totalSeconds) : 0

                return AppUsageDisplay(
                    id: usage.id,
                    name: usage.name,
                    bundleId: usage.bundleId,
                    icon: icon,
                    duration: usage.formattedDuration,
                    durationSeconds: usage.totalSeconds,
                    percentage: percentage,
                    keystrokes: usage.keystrokes,
                    clicks: usage.clicks,
                    category: usage.category
                )
            }

            // Load hourly breakdown
            hourlyBreakdown = try statsRepository.getHourlyBreakdown(for: Date())

        } catch {
            print("Error loading today's data: \(error)")
        }
    }

    // MARK: - Get Data for Dates

    public func getStats(for date: Date) async -> TodayStats {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

            let minuteStats = try statsRepository.getMinuteStats(from: startOfDay, to: endOfDay)

            let activeTime = minuteStats.reduce(0) { $0 + $1.activeSeconds }
            let keystrokes = minuteStats.reduce(0) { $0 + $1.keystrokes }
            let clicks = minuteStats.reduce(0) { $0 + $1.clicks }
            let scroll = minuteStats.reduce(0) { $0 + $1.scrollDistance }
            let mouse = minuteStats.reduce(0) { $0 + $1.mouseDistance }
            let focusScore = calculateFocusScore(from: minuteStats, totalActive: activeTime)
            let breakdown = calculateFocusBreakdown(from: minuteStats)

            return TodayStats(
                activeTimeSeconds: activeTime,
                keystrokes: keystrokes,
                clicks: clicks,
                focusScore: focusScore,
                scrollDistance: scroll,
                mouseDistance: mouse,
                contextSwitches: breakdown.contextSwitches,
                deepWorkMinutes: breakdown.deepWorkMinutes,
                distractionMinutes: breakdown.distractionMinutes
            )
        } catch {
            print("Error getting stats for date: \(error)")
            return TodayStats()
        }
    }

    public func getStats(from startDate: Date, to endDate: Date) async -> TodayStats {
        do {
            let minuteStats = try statsRepository.getMinuteStats(from: startDate, to: endDate)

            let activeTime = minuteStats.reduce(0) { $0 + $1.activeSeconds }
            let keystrokes = minuteStats.reduce(0) { $0 + $1.keystrokes }
            let clicks = minuteStats.reduce(0) { $0 + $1.clicks }
            let scroll = minuteStats.reduce(0) { $0 + $1.scrollDistance }
            let mouse = minuteStats.reduce(0) { $0 + $1.mouseDistance }
            let focusScore = calculateFocusScore(from: minuteStats, totalActive: activeTime)
            let breakdown = calculateFocusBreakdown(from: minuteStats)

            return TodayStats(
                activeTimeSeconds: activeTime,
                keystrokes: keystrokes,
                clicks: clicks,
                focusScore: focusScore,
                scrollDistance: scroll,
                mouseDistance: mouse,
                contextSwitches: breakdown.contextSwitches,
                deepWorkMinutes: breakdown.deepWorkMinutes,
                distractionMinutes: breakdown.distractionMinutes
            )
        } catch {
            print("Error getting stats for range: \(error)")
            return TodayStats()
        }
    }

    public func getTopApps(for date: Date, limit: Int = 10) async -> [AppUsageDisplay] {
        do {
            let appUsages = try appRepository.getTopApps(for: date, limit: limit)
            let totalSeconds = appUsages.reduce(0) { $0 + $1.totalSeconds }

            return appUsages.map { usage in
                let icon = getAppIcon(bundleId: usage.bundleId)
                let percentage = totalSeconds > 0 ? Double(usage.totalSeconds) / Double(totalSeconds) : 0

                return AppUsageDisplay(
                    id: usage.id,
                    name: usage.name,
                    bundleId: usage.bundleId,
                    icon: icon,
                    duration: usage.formattedDuration,
                    durationSeconds: usage.totalSeconds,
                    percentage: percentage,
                    keystrokes: usage.keystrokes,
                    clicks: usage.clicks,
                    category: usage.category
                )
            }
        } catch {
            print("Error getting top apps: \(error)")
            return []
        }
    }

    public func getTopApps(from startDate: Date, to endDate: Date, limit: Int = 10) async -> [AppUsageDisplay] {
        do {
            let appUsages = try appRepository.getTopApps(from: startDate, to: endDate, limit: limit)
            let totalSeconds = appUsages.reduce(0) { $0 + $1.totalSeconds }

            return appUsages.map { usage in
                let icon = getAppIcon(bundleId: usage.bundleId)
                let percentage = totalSeconds > 0 ? Double(usage.totalSeconds) / Double(totalSeconds) : 0

                return AppUsageDisplay(
                    id: usage.id,
                    name: usage.name,
                    bundleId: usage.bundleId,
                    icon: icon,
                    duration: usage.formattedDuration,
                    durationSeconds: usage.totalSeconds,
                    percentage: percentage,
                    keystrokes: usage.keystrokes,
                    clicks: usage.clicks,
                    category: usage.category
                )
            }
        } catch {
            print("Error getting top apps for range: \(error)")
            return []
        }
    }

    public func getUniqueAppCount(for date: Date) async -> Int {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return try statsRepository.getUniqueAppCount(from: startOfDay, to: endOfDay)
        } catch {
            print("Error getting unique app count: \(error)")
            return 0
        }
    }

    public func getUniqueAppCount(from startDate: Date, to endDate: Date) async -> Int {
        do {
            return try statsRepository.getUniqueAppCount(from: startDate, to: endDate)
        } catch {
            print("Error getting unique app count for range: \(error)")
            return 0
        }
    }

    public func getFirstActivityDate(from startDate: Date, to endDate: Date) async -> Date? {
        do {
            return try statsRepository.getFirstActivityDate(from: startDate, to: endDate)
        } catch {
            print("Error getting first activity date: \(error)")
            return nil
        }
    }

    public func getAppUsage(bundleId: String, from startDate: Date, to endDate: Date) async -> AppUsageDisplay? {
        do {
            guard let app = try appRepository.get(bundleId: bundleId),
                  let appId = app.id else {
                return nil
            }

            let totals = try statsRepository.getAppUsageTotals(appId: appId, from: startDate, to: endDate)
            let icon = getAppIcon(bundleId: bundleId)

            return AppUsageDisplay(
                id: appId,
                name: app.name,
                bundleId: app.bundleId,
                icon: icon,
                duration: totals.activeSeconds.formattedDuration,
                durationSeconds: totals.activeSeconds,
                percentage: 0,
                keystrokes: totals.keystrokes,
                clicks: totals.clicks,
                category: app.category
            )
        } catch {
            print("Error getting app usage: \(error)")
            return nil
        }
    }

    public func getHourlyBreakdown(for date: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyBreakdown(for: date)
        } catch {
            print("Error getting hourly breakdown: \(error)")
            return [:]
        }
    }

    public func getHourlyBreakdown(from startDate: Date, to endDate: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyBreakdown(from: startDate, to: endDate)
        } catch {
            print("Error getting hourly breakdown for range: \(error)")
            return [:]
        }
    }

    public func getHourlyKeystrokeBreakdown(for date: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyKeystrokeBreakdown(for: date)
        } catch {
            print("Error getting hourly keystroke breakdown: \(error)")
            return [:]
        }
    }

    public func getHourlyKeystrokeBreakdown(from startDate: Date, to endDate: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyKeystrokeBreakdown(from: startDate, to: endDate)
        } catch {
            print("Error getting hourly keystroke breakdown for range: \(error)")
            return [:]
        }
    }

    public func getHourlyClickBreakdown(for date: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyClickBreakdown(for: date)
        } catch {
            print("Error getting hourly click breakdown: \(error)")
            return [:]
        }
    }

    public func getHourlyClickBreakdown(from startDate: Date, to endDate: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyClickBreakdown(from: startDate, to: endDate)
        } catch {
            print("Error getting hourly click breakdown for range: \(error)")
            return [:]
        }
    }

    // MARK: - Timeline Segments

    public struct TimelineSegmentData: Identifiable {
        public let id = UUID()
        public let appName: String
        public let bundleId: String
        public let startTime: Date
        public let durationSeconds: Int
        public let category: AppCategory
        public let color: Color
        public let keystrokes: Int
        public let clicks: Int
    }

    public func getTimelineSegments(for date: Date) async -> [TimelineSegmentData] {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

            let minuteStats = try statsRepository.getMinuteStats(from: startOfDay, to: endOfDay)

            // Group consecutive minute stats by app
            var segments: [TimelineSegmentData] = []
            var currentAppId: Int64? = nil
            var segmentStart: Date? = nil
            var segmentStats: [MinuteStat] = []

            for stat in minuteStats {
                if stat.appId != currentAppId {
                    // Save previous segment
                    if let appId = currentAppId, let start = segmentStart, !segmentStats.isEmpty {
                        if let segment = await createSegment(appId: appId, start: start, stats: segmentStats) {
                            segments.append(segment)
                        }
                    }

                    // Start new segment
                    currentAppId = stat.appId
                    segmentStart = Date(timeIntervalSince1970: TimeInterval(stat.timestamp))
                    segmentStats = [stat]
                } else {
                    segmentStats.append(stat)
                }
            }

            // Save last segment
            if let appId = currentAppId, let start = segmentStart, !segmentStats.isEmpty {
                if let segment = await createSegment(appId: appId, start: start, stats: segmentStats) {
                    segments.append(segment)
                }
            }

            return segments
        } catch {
            print("Error getting timeline segments: \(error)")
            return []
        }
    }

    private func createSegment(appId: Int64, start: Date, stats: [MinuteStat]) async -> TimelineSegmentData? {
        do {
            guard let app = try appRepository.get(id: appId) else { return nil }

            let duration = stats.reduce(0) { $0 + $1.activeSeconds }
            let keystrokes = stats.reduce(0) { $0 + $1.keystrokes }
            let clicks = stats.reduce(0) { $0 + $1.clicks }

            return TimelineSegmentData(
                appName: app.name,
                bundleId: app.bundleId,
                startTime: start,
                durationSeconds: duration,
                category: app.category,
                color: app.category.color,
                keystrokes: keystrokes,
                clicks: clicks
            )
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func getAppIcon(bundleId: String) -> NSImage? {
        guard let appPath = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appPath.path)
    }

    private func calculateFocusScore(from stats: [MinuteStat], totalActive: Int) -> Int {
        guard totalActive > 0 else { return 0 }

        // Focus score based on:
        // 1. Longest continuous session (less context switching = better)
        // 2. Ratio of active time to total time

        var maxContinuousMinutes = 0
        var currentContinuous = 0
        var lastTimestamp: Int64 = 0

        for stat in stats {
            if stat.activeSeconds > 0 {
                if lastTimestamp > 0 && (stat.timestamp - lastTimestamp) <= 120 { // Within 2 minutes
                    currentContinuous += 1
                } else {
                    currentContinuous = 1
                }
                maxContinuousMinutes = max(maxContinuousMinutes, currentContinuous)
                lastTimestamp = stat.timestamp
            }
        }

        // Score: 50% based on longest session, 50% based on consistency
        let sessionScore = min(100, maxContinuousMinutes * 2) // 50 continuous minutes = 100%
        let consistencyScore = min(100, (totalActive * 100) / max(1, stats.count * 60))

        return (sessionScore + consistencyScore) / 2
    }

    /// Calculate focus score breakdown data
    private func calculateFocusBreakdown(from stats: [MinuteStat]) -> (contextSwitches: Int, deepWorkMinutes: Int, distractionMinutes: Int) {
        guard !stats.isEmpty else { return (0, 0, 0) }

        var contextSwitches = 0
        var deepWorkMinutes = 0

        var lastAppId: Int64?
        var currentSessionMinutes = 0

        for stat in stats {
            // Count context switches (app changes)
            if let lastApp = lastAppId, lastApp != stat.appId {
                contextSwitches += 1
                // Check if previous session was deep work (25+ minutes)
                if currentSessionMinutes >= 25 {
                    deepWorkMinutes += currentSessionMinutes
                }
                currentSessionMinutes = 0
            }

            currentSessionMinutes += 1
            lastAppId = stat.appId
        }

        // Check final session
        if currentSessionMinutes >= 25 {
            deepWorkMinutes += currentSessionMinutes
        }

        // Calculate distraction time from distracting app categories
        // Distracting categories: entertainment, social, gaming
        var distractionMinutes = 0
        let distractingCategories: Set<AppCategory> = [.entertainment, .social, .gaming]

        do {
            let allApps = try appRepository.getAll()
            let distractingAppIds = Set(allApps.filter { distractingCategories.contains($0.category) }.map { $0.id })

            for stat in stats {
                if distractingAppIds.contains(stat.appId) {
                    distractionMinutes += 1
                }
            }
        } catch {
            // If we can't get apps, estimate from stats
            distractionMinutes = 0
        }

        return (contextSwitches, deepWorkMinutes, distractionMinutes)
    }

    // MARK: - Keycode Frequency

    /// Get aggregated keycode frequency for a date
    public func getKeycodeFrequency(for date: Date) async -> [Int: Int] {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return try statsRepository.getKeycodeFrequency(from: startOfDay, to: endOfDay)
        } catch {
            print("Error getting keycode frequency: \(error)")
            return [:]
        }
    }

    public func getKeycodeFrequency(from startDate: Date, to endDate: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getKeycodeFrequency(from: startDate, to: endDate)
        } catch {
            print("Error getting keycode frequency for range: \(error)")
            return [:]
        }
    }

    // MARK: - Click Positions

    /// Get click positions for a date
    public func getClickPositions(for date: Date) async -> [[Int]] {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            return try statsRepository.getClickPositions(from: startOfDay, to: endOfDay)
        } catch {
            print("Error getting click positions: \(error)")
            return []
        }
    }

    public func getClickPositions(from startDate: Date, to endDate: Date) async -> [[Int]] {
        do {
            return try statsRepository.getClickPositions(from: startDate, to: endDate)
        } catch {
            print("Error getting click positions for range: \(error)")
            return []
        }
    }

    // MARK: - Trend Comparisons

    /// Trend comparison data between two periods
    public struct TrendComparison {
        public let current: PeriodData
        public let previous: PeriodData

        public struct PeriodData {
            public let activeSeconds: Int
            public let keystrokes: Int
            public let clicks: Int
            public let focusScore: Int
            public let uniqueApps: Int
        }

        /// Calculate percentage change (returns nil if previous was 0)
        public func percentChange(for keyPath: KeyPath<PeriodData, Int>) -> Double? {
            let prev = previous[keyPath: keyPath]
            let curr = current[keyPath: keyPath]
            guard prev > 0 else { return curr > 0 ? 100.0 : nil }
            return Double(curr - prev) / Double(prev) * 100.0
        }

        /// Calculate absolute change
        public func absoluteChange(for keyPath: KeyPath<PeriodData, Int>) -> Int {
            current[keyPath: keyPath] - previous[keyPath: keyPath]
        }

        /// Format a percentage change as a trend string
        public func trendString(for keyPath: KeyPath<PeriodData, Int>) -> String? {
            guard let change = percentChange(for: keyPath) else { return nil }
            let sign = change >= 0 ? "+" : ""
            return "\(sign)\(Int(change))%"
        }
    }

    /// Get today vs yesterday comparison
    public func getTodayVsYesterday() async -> TrendComparison {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return TrendComparison(
                current: TrendComparison.PeriodData(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0),
                previous: TrendComparison.PeriodData(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0)
            )
        }

        return await getComparison(
            currentStart: todayStart, currentEnd: tomorrowStart,
            previousStart: yesterdayStart, previousEnd: todayStart
        )
    }

    /// Get this week vs last week comparison
    public func getThisWeekVsLastWeek() async -> TrendComparison {
        let calendar = Calendar.current
        let now = Date()

        guard let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart),
              let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeekStart) else {
            return TrendComparison(
                current: TrendComparison.PeriodData(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0),
                previous: TrendComparison.PeriodData(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0)
            )
        }

        return await getComparison(
            currentStart: thisWeekStart, currentEnd: nextWeekStart,
            previousStart: lastWeekStart, previousEnd: thisWeekStart
        )
    }

    /// Get comparison between two arbitrary periods
    public func getComparison(
        currentStart: Date, currentEnd: Date,
        previousStart: Date, previousEnd: Date
    ) async -> TrendComparison {
        do {
            let currentPeriod = try statsRepository.getPeriodStats(from: currentStart, to: currentEnd)
            let previousPeriod = try statsRepository.getPeriodStats(from: previousStart, to: previousEnd)

            // Calculate focus scores
            let currentFocus = await getStats(from: currentStart, to: currentEnd)
            let previousFocus = await getStats(from: previousStart, to: previousEnd)

            return TrendComparison(
                current: TrendComparison.PeriodData(
                    activeSeconds: currentPeriod.activeSeconds,
                    keystrokes: currentPeriod.keystrokes,
                    clicks: currentPeriod.clicks,
                    focusScore: currentFocus.focusScore,
                    uniqueApps: currentPeriod.uniqueApps
                ),
                previous: TrendComparison.PeriodData(
                    activeSeconds: previousPeriod.activeSeconds,
                    keystrokes: previousPeriod.keystrokes,
                    clicks: previousPeriod.clicks,
                    focusScore: previousFocus.focusScore,
                    uniqueApps: previousPeriod.uniqueApps
                )
            )
        } catch {
            print("Error getting comparison: \(error)")
            return TrendComparison(
                current: TrendComparison.PeriodData(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0),
                previous: TrendComparison.PeriodData(activeSeconds: 0, keystrokes: 0, clicks: 0, focusScore: 0, uniqueApps: 0)
            )
        }
    }

    // MARK: - Productivity Heatmap

    /// Get productivity heatmap data - active seconds by hour (0-23) and day of week (0-6, Sunday=0)
    public func getProductivityHeatmap(from startDate: Date, to endDate: Date) async -> [[Int]] {
        do {
            return try statsRepository.getProductivityHeatmap(from: startDate, to: endDate)
        } catch {
            print("Error getting productivity heatmap: \(error)")
            return Array(repeating: Array(repeating: 0, count: 24), count: 7)
        }
    }

    /// Get productivity heatmap for the last N weeks
    public func getProductivityHeatmap(weeks: Int = 4) async -> [[Int]] {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: todayStart),
              let startDate = calendar.date(byAdding: .weekOfYear, value: -weeks, to: endDate) else {
            return Array(repeating: Array(repeating: 0, count: 24), count: 7)
        }
        return await getProductivityHeatmap(from: startDate, to: endDate)
    }

    // MARK: - Weekly Summary

    /// Weekly summary data structure
    public struct WeeklySummary {
        public let weekStart: Date
        public let weekEnd: Date
        public let totalActiveSeconds: Int
        public let totalKeystrokes: Int
        public let totalClicks: Int
        public let focusSessions: Int
        public let averageFocusScore: Int
        public let topApps: [AppUsageDisplay]
        public let dailyBreakdown: [DailyData]
        public let comparison: TrendComparison

        public struct DailyData: Identifiable {
            public let id = UUID()
            public let date: Date
            public let activeSeconds: Int
            public let keystrokes: Int
            public let focusScore: Int
        }

        public var formattedActiveTime: String {
            let hours = totalActiveSeconds / 3600
            let minutes = (totalActiveSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }

        public var averageDailyActiveTime: String {
            let daysWithData = max(1, dailyBreakdown.filter { $0.activeSeconds > 0 }.count)
            let avgSeconds = totalActiveSeconds / daysWithData
            let hours = avgSeconds / 3600
            let minutes = (avgSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - Activity Streak

    /// Streak data showing consecutive days of activity
    public struct StreakData {
        public let currentStreak: Int
        public let longestStreak: Int
        public let lastActiveDate: Date?

        public var isActiveToday: Bool {
            guard let lastActive = lastActiveDate else { return false }
            return Calendar.current.isDateInToday(lastActive)
        }
    }

    /// Calculate the user's activity streak (consecutive days with activity)
    public func getStreak() async -> StreakData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var currentStreak = 0
        var longestStreak = 0
        var lastActiveDate: Date? = nil

        // Look back up to 365 days
        for dayOffset in 0..<365 {
            guard let checkDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                break
            }
            let stats = await getStats(for: checkDate)

            if stats.activeTimeSeconds > 60 { // At least 1 minute of activity
                if lastActiveDate == nil {
                    lastActiveDate = checkDate
                }

                if dayOffset == currentStreak {
                    currentStreak += 1
                }
                longestStreak = max(longestStreak, currentStreak)
            } else if dayOffset > 0 {
                // Gap in activity - stop counting current streak
                break
            }
        }

        return StreakData(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastActiveDate: lastActiveDate
        )
    }

    // MARK: - Recent Focus Sessions

    /// Display data for a focus session
    public struct FocusSessionDisplay: Identifiable {
        public let id: Int64
        public let startTime: Date
        public let endTime: Date?
        public let duration: String
        public let dateString: String
        public let timeRange: String
        public let isDeepWork: Bool
    }

    /// Get recent focus sessions
    public func getRecentFocusSessions(limit: Int = 10) async -> [FocusSessionDisplay] {
        do {
            let sessions = try statsRepository.getRecentFocusSessions(limit: limit)
            return sessions.compactMap { session -> FocusSessionDisplay? in
                guard let id = session.id else { return nil }

                let duration: String
                if let end = session.endTime {
                    let seconds = Int(end.timeIntervalSince(session.startTime))
                    let hours = seconds / 3600
                    let minutes = (seconds % 3600) / 60
                    duration = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
                } else {
                    duration = "In progress"
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none

                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"

                let startTimeStr = timeFormatter.string(from: session.startTime)
                let endTimeStr = session.endTime.map { timeFormatter.string(from: $0) } ?? "now"

                return FocusSessionDisplay(
                    id: id,
                    startTime: session.startTime,
                    endTime: session.endTime,
                    duration: duration,
                    dateString: dateFormatter.string(from: session.startTime),
                    timeRange: "\(startTimeStr) - \(endTimeStr)",
                    isDeepWork: session.isDeepWork
                )
            }
        } catch {
            print("Error getting recent focus sessions: \(error)")
            return []
        }
    }

    // MARK: - Trend Data

    /// Get trend data points for the last N days
    public func getTrendData(days: Int = 7) async -> (
        activeTime: [TrendDataPoint],
        focusScore: [TrendDataPoint],
        keystrokes: [TrendDataPoint]
    ) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var activeTimePoints: [TrendDataPoint] = []
        var focusScorePoints: [TrendDataPoint] = []
        var keystrokesPoints: [TrendDataPoint] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let stats = await getStats(for: date)
            let label = dateFormatter.string(from: date)

            activeTimePoints.append(TrendDataPoint(
                date: date,
                value: Double(stats.activeTimeSeconds),
                label: label
            ))

            focusScorePoints.append(TrendDataPoint(
                date: date,
                value: Double(stats.focusScore),
                label: label
            ))

            keystrokesPoints.append(TrendDataPoint(
                date: date,
                value: Double(stats.keystrokes),
                label: label
            ))
        }

        return (activeTimePoints, focusScorePoints, keystrokesPoints)
    }

    public struct TrendDataPoint: Identifiable {
        public let id = UUID()
        public let date: Date
        public let value: Double
        public let label: String
    }

    /// Get weekly summary for the current or specified week
    public func getWeeklySummary(for weekStart: Date? = nil) async -> WeeklySummary {
        let calendar = Calendar.current
        let now = Date()
        let start = weekStart ?? calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)

        // Get comparison with previous week
        let comparison = await getThisWeekVsLastWeek()

        // Get daily breakdown
        var dailyData: [WeeklySummary.DailyData] = []
        var totalActive = 0
        var totalKeystrokes = 0
        var totalClicks = 0
        var focusScoreSum = 0
        var daysWithData = 0

        for dayOffset in 0..<7 {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: start) else {
                continue
            }
            let stats = await getStats(for: dayStart)

            dailyData.append(WeeklySummary.DailyData(
                date: dayStart,
                activeSeconds: stats.activeTimeSeconds,
                keystrokes: stats.keystrokes,
                focusScore: stats.focusScore
            ))

            totalActive += stats.activeTimeSeconds
            totalKeystrokes += stats.keystrokes
            totalClicks += stats.clicks

            if stats.activeTimeSeconds > 0 {
                focusScoreSum += stats.focusScore
                daysWithData += 1
            }
        }

        // Get top apps for the week
        let topApps = await getTopApps(from: start, to: end, limit: 5)

        // Get focus session count
        var focusSessions = 0
        do {
            let sessions = try statsRepository.getPeriodStats(from: start, to: end)
            focusSessions = sessions.focusSessions
        } catch {
            print("Error getting focus sessions: \(error)")
        }

        return WeeklySummary(
            weekStart: start,
            weekEnd: end,
            totalActiveSeconds: totalActive,
            totalKeystrokes: totalKeystrokes,
            totalClicks: totalClicks,
            focusSessions: focusSessions,
            averageFocusScore: daysWithData > 0 ? focusScoreSum / daysWithData : 0,
            topApps: topApps,
            dailyBreakdown: dailyData,
            comparison: comparison
        )
    }
}

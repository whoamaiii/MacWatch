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

            todayStats = TodayStats(
                activeTimeSeconds: activeTime,
                keystrokes: keystrokes,
                clicks: totalClicks,
                focusScore: focusScore,
                scrollDistance: totalScroll,
                mouseDistance: totalMouse
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

    // MARK: - Get Data for Date Range

    public func getStats(for date: Date) async -> TodayStats {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            let minuteStats = try statsRepository.getMinuteStats(from: startOfDay, to: endOfDay)

            let activeTime = minuteStats.reduce(0) { $0 + $1.activeSeconds }
            let keystrokes = minuteStats.reduce(0) { $0 + $1.keystrokes }
            let clicks = minuteStats.reduce(0) { $0 + $1.clicks }
            let scroll = minuteStats.reduce(0) { $0 + $1.scrollDistance }
            let mouse = minuteStats.reduce(0) { $0 + $1.mouseDistance }
            let focusScore = calculateFocusScore(from: minuteStats, totalActive: activeTime)

            return TodayStats(
                activeTimeSeconds: activeTime,
                keystrokes: keystrokes,
                clicks: clicks,
                focusScore: focusScore,
                scrollDistance: scroll,
                mouseDistance: mouse
            )
        } catch {
            print("Error getting stats for date: \(error)")
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

    public func getHourlyBreakdown(for date: Date) async -> [Int: Int] {
        do {
            return try statsRepository.getHourlyBreakdown(for: date)
        } catch {
            print("Error getting hourly breakdown: \(error)")
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
        public let color: Color
        public let keystrokes: Int
        public let clicks: Int
    }

    public func getTimelineSegments(for date: Date) async -> [TimelineSegmentData] {
        do {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

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
}


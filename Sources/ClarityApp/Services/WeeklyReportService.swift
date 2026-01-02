import Foundation
import SwiftUI
import ClarityShared

/// Service for generating weekly productivity reports
@MainActor
public final class WeeklyReportService: ObservableObject {
    public static let shared = WeeklyReportService()

    // MARK: - Published Properties

    @Published public var currentReport: WeeklyReport?
    @Published public var isGenerating = false

    // MARK: - Types

    public struct WeeklyReport: Identifiable {
        public let id = UUID()
        public let weekStartDate: Date
        public let weekEndDate: Date
        public let generatedAt: Date

        // Summary stats
        public let totalActiveSeconds: Int
        public let totalKeystrokes: Int
        public let totalClicks: Int
        public let avgFocusScore: Int
        public let daysActive: Int

        // Comparisons
        public let activeTimeChange: Double?
        public let focusScoreChange: Double?

        // Top apps
        public let topApps: [(name: String, seconds: Int, percentage: Double)]

        // Daily breakdown
        public let dailyStats: [(date: Date, activeSeconds: Int, focusScore: Int)]

        // Insights
        public let mostProductiveDay: (date: Date, seconds: Int)?
        public let leastProductiveDay: (date: Date, seconds: Int)?
        public let peakHours: [Int]
        public let focusSessions: Int

        // Recommendations
        public let recommendations: [String]

        public var formattedTotalTime: String {
            let hours = totalActiveSeconds / 3600
            let minutes = (totalActiveSeconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }

        public var formattedAvgDailyTime: String {
            guard daysActive > 0 else { return "0m" }
            let avgSeconds = totalActiveSeconds / daysActive
            let hours = avgSeconds / 3600
            let minutes = (avgSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - Private

    private let dataService = DataService.shared

    private init() {}

    // MARK: - Public Methods

    public func generateReport(for weekStartDate: Date? = nil) async -> WeeklyReport {
        isGenerating = true
        defer { isGenerating = false }

        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = weekStartDate ?? calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? calendar.startOfDay(for: now)
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek.addingTimeInterval(6 * 24 * 60 * 60)

        var totalActiveSeconds = 0
        var totalKeystrokes = 0
        var totalClicks = 0
        var totalFocusScore = 0
        var daysActive = 0
        var dailyStats: [(Date, Int, Int)] = []
        var hourlyActivity: [Int: Int] = [:]
        var appUsage: [String: Int] = [:]

        var mostProductive: (Date, Int)?
        var leastProductive: (Date, Int)?

        // Collect data for each day
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else { continue }

            let stats = await dataService.getStats(for: date)

            if stats.activeTimeSeconds > 0 {
                totalActiveSeconds += stats.activeTimeSeconds
                totalKeystrokes += stats.keystrokes
                totalClicks += stats.clicks
                totalFocusScore += stats.focusScore
                daysActive += 1

                if let current = mostProductive {
                    if stats.activeTimeSeconds > current.1 {
                        mostProductive = (date, stats.activeTimeSeconds)
                    }
                } else {
                    mostProductive = (date, stats.activeTimeSeconds)
                }

                if let current = leastProductive {
                    if stats.activeTimeSeconds < current.1 {
                        leastProductive = (date, stats.activeTimeSeconds)
                    }
                } else {
                    leastProductive = (date, stats.activeTimeSeconds)
                }
            }

            dailyStats.append((date, stats.activeTimeSeconds, stats.focusScore))

            // Collect app usage
            let topApps = await dataService.getTopApps(for: date, limit: 20)
            for app in topApps {
                appUsage[app.name, default: 0] += app.durationSeconds
            }

            // Collect hourly data
            let hourly = dataService.hourlyBreakdown
            for (hour, seconds) in hourly {
                hourlyActivity[hour, default: 0] += seconds
            }
        }

        // Calculate averages
        let avgFocusScore = daysActive > 0 ? totalFocusScore / daysActive : 0

        // Get previous week for comparison
        let prevWeekStart = calendar.date(byAdding: .day, value: -7, to: startOfWeek) ?? startOfWeek.addingTimeInterval(-7 * 24 * 60 * 60)
        var prevTotalActive = 0
        var prevTotalFocus = 0
        var prevDaysActive = 0

        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: prevWeekStart) else { continue }
            let stats = await dataService.getStats(for: date)
            if stats.activeTimeSeconds > 0 {
                prevTotalActive += stats.activeTimeSeconds
                prevTotalFocus += stats.focusScore
                prevDaysActive += 1
            }
        }

        let activeTimeChange: Double? = prevTotalActive > 0
            ? Double(totalActiveSeconds - prevTotalActive) / Double(prevTotalActive) * 100
            : nil

        let prevAvgFocus = prevDaysActive > 0 ? prevTotalFocus / prevDaysActive : 0
        let focusScoreChange: Double? = prevAvgFocus > 0
            ? Double(avgFocusScore - prevAvgFocus) / Double(prevAvgFocus) * 100
            : nil

        // Sort apps by usage
        let sortedApps = appUsage.sorted { $0.value > $1.value }
        let topApps = sortedApps.prefix(5).map { app -> (String, Int, Double) in
            let percentage = totalActiveSeconds > 0 ? Double(app.value) / Double(totalActiveSeconds) : 0
            return (app.key, app.value, percentage)
        }

        // Find peak hours (top 3)
        let sortedHours = hourlyActivity.sorted { $0.value > $1.value }
        let peakHours = Array(sortedHours.prefix(3).map { $0.key })

        // Get focus sessions count
        let sessions = await dataService.getFocusSessions(for: startOfWeek, to: endOfWeek)

        // Generate recommendations
        let recommendations = generateRecommendations(
            avgFocusScore: avgFocusScore,
            daysActive: daysActive,
            totalActiveSeconds: totalActiveSeconds,
            peakHours: peakHours,
            activeTimeChange: activeTimeChange
        )

        let report = WeeklyReport(
            weekStartDate: startOfWeek,
            weekEndDate: endOfWeek,
            generatedAt: Date(),
            totalActiveSeconds: totalActiveSeconds,
            totalKeystrokes: totalKeystrokes,
            totalClicks: totalClicks,
            avgFocusScore: avgFocusScore,
            daysActive: daysActive,
            activeTimeChange: activeTimeChange,
            focusScoreChange: focusScoreChange,
            topApps: topApps,
            dailyStats: dailyStats,
            mostProductiveDay: mostProductive,
            leastProductiveDay: leastProductive,
            peakHours: peakHours,
            focusSessions: sessions.count,
            recommendations: recommendations
        )

        currentReport = report
        return report
    }

    public func exportReportAsText(_ report: WeeklyReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var text = """
        ═══════════════════════════════════════
        CLARITY WEEKLY PRODUCTIVITY REPORT
        ═══════════════════════════════════════

        Week: \(dateFormatter.string(from: report.weekStartDate)) - \(dateFormatter.string(from: report.weekEndDate))
        Generated: \(dateFormatter.string(from: report.generatedAt))

        ─────────────────────────────────────────
        SUMMARY
        ─────────────────────────────────────────

        Total Active Time: \(report.formattedTotalTime)
        Average Daily Time: \(report.formattedAvgDailyTime)
        Days Active: \(report.daysActive)/7
        Average Focus Score: \(report.avgFocusScore)%
        Total Keystrokes: \(formatNumber(report.totalKeystrokes))
        Total Clicks: \(formatNumber(report.totalClicks))
        Focus Sessions: \(report.focusSessions)

        """

        if let change = report.activeTimeChange {
            text += "vs Last Week: \(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%\n"
        }

        text += """

        ─────────────────────────────────────────
        TOP APPS
        ─────────────────────────────────────────

        """

        for (index, app) in report.topApps.enumerated() {
            let hours = app.1 / 3600
            let minutes = (app.1 % 3600) / 60
            let duration = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            text += "\(index + 1). \(app.0) - \(duration) (\(String(format: "%.0f", app.2 * 100))%)\n"
        }

        text += """

        ─────────────────────────────────────────
        DAILY BREAKDOWN
        ─────────────────────────────────────────

        """

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"

        for day in report.dailyStats {
            let hours = day.1 / 3600
            let minutes = (day.1 % 3600) / 60
            let duration = day.1 > 0 ? (hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m") : "No activity"
            let focus = day.1 > 0 ? "\(day.2)%" : "-"
            text += "\(dayFormatter.string(from: day.0)): \(duration) | Focus: \(focus)\n"
        }

        if !report.peakHours.isEmpty {
            text += """

            ─────────────────────────────────────────
            PEAK PRODUCTIVITY HOURS
            ─────────────────────────────────────────

            """
            for hour in report.peakHours {
                let hourStr = hour < 12 ? "\(hour)AM" : (hour == 12 ? "12PM" : "\(hour - 12)PM")
                text += "• \(hourStr)\n"
            }
        }

        if !report.recommendations.isEmpty {
            text += """

            ─────────────────────────────────────────
            RECOMMENDATIONS
            ─────────────────────────────────────────

            """
            for rec in report.recommendations {
                text += "• \(rec)\n"
            }
        }

        text += """

        ═══════════════════════════════════════
        Generated by Clarity for macOS
        ═══════════════════════════════════════
        """

        return text
    }

    // MARK: - Private Methods

    private func generateRecommendations(
        avgFocusScore: Int,
        daysActive: Int,
        totalActiveSeconds: Int,
        peakHours: [Int],
        activeTimeChange: Double?
    ) -> [String] {
        var recommendations: [String] = []

        if avgFocusScore < 50 {
            recommendations.append("Your focus score is below average. Try using the Pomodoro timer for structured work sessions.")
        } else if avgFocusScore >= 80 {
            recommendations.append("Excellent focus this week! Keep up the great work.")
        }

        if daysActive < 5 {
            recommendations.append("You were active only \(daysActive) days. Consistency helps build productive habits.")
        }

        if let change = activeTimeChange, change < -20 {
            recommendations.append("Your active time decreased significantly. Check if external factors are affecting your productivity.")
        }

        if !peakHours.isEmpty {
            let peakStr = peakHours.map { h in h < 12 ? "\(h)AM" : (h == 12 ? "12PM" : "\(h - 12)PM") }.joined(separator: ", ")
            recommendations.append("Your peak hours are around \(peakStr). Schedule important work during these times.")
        }

        if totalActiveSeconds > 8 * 3600 * 5 { // More than 8h/day on average for 5 days
            recommendations.append("You're putting in long hours. Remember to take breaks to avoid burnout.")
        }

        return recommendations
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - DataService Extension

extension DataService {
    func getFocusSessions(for startDate: Date, to endDate: Date) async -> [FocusSession] {
        // Return focus sessions in date range
        var allSessions: [FocusSession] = []
        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            do {
                let statsRepo = StatsRepository()
                let dailySessions = try statsRepo.getFocusSessions(for: currentDate)
                allSessions.append(contentsOf: dailySessions)
            } catch {
                // Continue to next day
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(1)
        }

        return allSessions
    }
}

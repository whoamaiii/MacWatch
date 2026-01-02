import Foundation
import SwiftUI
import ClarityShared

/// Smart recommendation engine that generates personalized insights
@MainActor
public final class RecommendationEngine: ObservableObject {
    public static let shared = RecommendationEngine()

    @Published public var recommendations: [Recommendation] = []
    @Published public var isLoading = false

    private let dataService = DataService.shared
    private let statsRepository = StatsRepository()

    public struct Recommendation: Identifiable {
        public let id = UUID()
        public let icon: String
        public let title: String
        public let message: String
        public let type: RecommendationType
        public let priority: Priority

        public enum RecommendationType {
            case positive   // Something good
            case warning    // Something to improve
            case insight    // Neutral observation
            case tip        // Actionable suggestion
        }

        public enum Priority: Int, Comparable {
            case high = 3
            case medium = 2
            case low = 1

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        public var color: Color {
            switch type {
            case .positive: return ClarityColors.success
            case .warning: return ClarityColors.warning
            case .insight: return ClarityColors.accentPrimary
            case .tip: return ClarityColors.deepFocus
            }
        }
    }

    private init() {}

    /// Generate recommendations based on user's data
    public func generateRecommendations() async {
        isLoading = true
        defer { isLoading = false }

        var newRecommendations: [Recommendation] = []

        // Get today's stats
        let todayStats = await dataService.getStats(for: Date())
        let comparison = await dataService.getTodayVsYesterday()

        // Get hourly breakdown
        let hourlyBreakdown = await dataService.getHourlyBreakdown(for: Date())

        // Get top apps
        let topApps = await dataService.getTopApps(for: Date(), limit: 10)

        // 1. Productivity Time Analysis
        if let peakHour = findPeakProductivityHour(hourlyBreakdown) {
            newRecommendations.append(Recommendation(
                icon: "sun.max.fill",
                title: "Peak Productivity",
                message: "You're most active around \(formatHour(peakHour)). Schedule important work during this time.",
                type: .insight,
                priority: .medium
            ))
        }

        // 2. Focus Score Feedback
        if todayStats.focusScore >= 80 {
            newRecommendations.append(Recommendation(
                icon: "star.fill",
                title: "Excellent Focus",
                message: "Your focus score is \(todayStats.focusScore)%! You're maintaining great concentration today.",
                type: .positive,
                priority: .high
            ))
        } else if todayStats.focusScore < 50 && todayStats.activeTimeSeconds > 1800 {
            newRecommendations.append(Recommendation(
                icon: "exclamationmark.triangle.fill",
                title: "Focus Needs Attention",
                message: "Your focus score is \(todayStats.focusScore)%. Try longer uninterrupted work sessions.",
                type: .warning,
                priority: .high
            ))
        }

        // 3. Trend Analysis
        if let activeChange = comparison.percentChange(for: \.activeSeconds) {
            if activeChange > 20 {
                newRecommendations.append(Recommendation(
                    icon: "arrow.up.circle.fill",
                    title: "More Active Today",
                    message: "You're \(Int(activeChange))% more active than yesterday. Great momentum!",
                    type: .positive,
                    priority: .medium
                ))
            } else if activeChange < -30 {
                newRecommendations.append(Recommendation(
                    icon: "arrow.down.circle.fill",
                    title: "Slower Day",
                    message: "Activity is \(Int(abs(activeChange)))% lower than yesterday. That's okay—rest is important too.",
                    type: .insight,
                    priority: .low
                ))
            }
        }

        // 4. App Usage Insights
        let distractionApps = topApps.filter { $0.category == .entertainment || $0.category == .social }
        let distractionTime = distractionApps.reduce(0) { $0 + $1.durationSeconds }
        let totalTime = topApps.reduce(0) { $0 + $1.durationSeconds }

        if totalTime > 0 {
            let distractionPercent = Double(distractionTime) / Double(totalTime) * 100
            if distractionPercent > 30 {
                let topDistraction = distractionApps.first?.name ?? "entertainment apps"
                newRecommendations.append(Recommendation(
                    icon: "tv.fill",
                    title: "High Entertainment Time",
                    message: "\(Int(distractionPercent))% of your time is on entertainment. \(topDistraction) is your top distraction.",
                    type: .warning,
                    priority: .medium
                ))
            }
        }

        // 5. Keystroke Intensity
        if todayStats.activeTimeSeconds > 0 {
            let keystrokesPerMinute = todayStats.keystrokes / max(1, todayStats.activeTimeSeconds / 60)
            if keystrokesPerMinute > 60 {
                newRecommendations.append(Recommendation(
                    icon: "keyboard.fill",
                    title: "High Typing Speed",
                    message: "You're averaging \(keystrokesPerMinute) keys/minute. Great productivity!",
                    type: .positive,
                    priority: .low
                ))
            }
        }

        // 6. Work Session Tips
        if hourlyBreakdown.count >= 4 {
            let gaps = findWorkGaps(hourlyBreakdown)
            if gaps.count >= 3 {
                newRecommendations.append(Recommendation(
                    icon: "clock.badge.exclamationmark.fill",
                    title: "Fragmented Work",
                    message: "You have \(gaps.count) gaps in your work today. Try the Pomodoro technique for focused blocks.",
                    type: .tip,
                    priority: .medium
                ))
            }
        }

        // 7. Top App Recognition
        if let topApp = topApps.first, topApp.durationSeconds > 3600 {
            newRecommendations.append(Recommendation(
                icon: "app.badge.checkmark.fill",
                title: "Most Used App",
                message: "\(topApp.name) is your top app with \(topApp.duration). Make sure it aligns with your goals.",
                type: .insight,
                priority: .low
            ))
        }

        // 8. Evening Wind-Down
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentHour >= 20 && todayStats.activeTimeSeconds > 0 {
            newRecommendations.append(Recommendation(
                icon: "moon.stars.fill",
                title: "Wind Down Time",
                message: "It's getting late. Consider wrapping up to maintain a healthy work-life balance.",
                type: .tip,
                priority: .low
            ))
        }

        // Sort by priority and limit
        recommendations = newRecommendations
            .sorted { $0.priority > $1.priority }
            .prefix(5)
            .map { $0 }

        // Add a default if no recommendations
        if recommendations.isEmpty {
            recommendations.append(Recommendation(
                icon: "sparkles",
                title: "Keep Going",
                message: "Continue tracking your activity to receive personalized insights and recommendations.",
                type: .insight,
                priority: .low
            ))
        }
    }

    private func findPeakProductivityHour(_ breakdown: [Int: Int]) -> Int? {
        guard !breakdown.isEmpty else { return nil }
        return breakdown.max(by: { $0.value < $1.value })?.key
    }

    private func findWorkGaps(_ breakdown: [Int: Int]) -> [Int] {
        let workHours = breakdown.keys.sorted()
        guard let firstHour = workHours.first, let lastHour = workHours.last else { return [] }

        var gaps: [Int] = []
        for hour in firstHour...lastHour {
            if breakdown[hour] == nil || breakdown[hour] == 0 {
                gaps.append(hour)
            }
        }
        return gaps
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour):00"
        }
        return formatter.string(from: date)
    }
}

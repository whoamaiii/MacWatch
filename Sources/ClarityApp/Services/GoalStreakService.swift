import Foundation
import SwiftUI
import ClarityShared

/// Tracks goal streaks - consecutive days of meeting daily goals
@MainActor
public final class GoalStreakService: ObservableObject {
    public static let shared = GoalStreakService()

    /// Streak data for a specific goal
    public struct GoalStreak: Codable, Identifiable {
        public var id: String { goalType.rawValue }
        public let goalType: GoalType
        public var currentStreak: Int
        public var longestStreak: Int
        public var lastMetDate: Date?
        public var streakHistory: [Date] // Days the goal was met

        public init(goalType: GoalType) {
            self.goalType = goalType
            self.currentStreak = 0
            self.longestStreak = 0
            self.lastMetDate = nil
            self.streakHistory = []
        }
    }

    public enum GoalType: String, Codable, CaseIterable {
        case activeTime = "Active Time"
        case keystrokes = "Keystrokes"
        case focusScore = "Focus Score"

        public var icon: String {
            switch self {
            case .activeTime: return "clock.fill"
            case .keystrokes: return "keyboard"
            case .focusScore: return "target"
            }
        }

        public var color: Color {
            switch self {
            case .activeTime: return ClarityColors.accentPrimary
            case .keystrokes: return ClarityColors.productivity
            case .focusScore: return ClarityColors.deepFocus
            }
        }
    }

    @Published public var streaks: [GoalType: GoalStreak] = [:]
    @Published public var overallStreak: Int = 0 // Days where ALL goals were met

    private let streaksKey = "goalStreaks"
    private let dataService = DataService.shared
    private let calendar = Calendar.current

    private init() {
        loadStreaks()
    }

    // MARK: - Public API

    /// Check and update all goal streaks
    public func checkStreaks() async {
        let today = calendar.startOfDay(for: Date())

        // Get today's stats
        let stats = await dataService.getStats(for: Date())

        // Get goal thresholds
        let activeTimeGoalHours = UserDefaults.standard.object(forKey: "activeTimeGoalHours") as? Int ?? 6
        let keystrokesGoal = UserDefaults.standard.object(forKey: "keystrokesGoal") as? Int ?? 5000
        let focusScoreGoal = UserDefaults.standard.object(forKey: "focusScoreGoal") as? Int ?? 70

        // Check each goal
        let activeTimeMet = stats.activeTimeSeconds >= (activeTimeGoalHours * 3600)
        let keystrokesMet = stats.keystrokes >= keystrokesGoal
        let focusScoreMet = stats.focusScore >= focusScoreGoal

        // Update streaks
        updateStreak(for: .activeTime, metToday: activeTimeMet, date: today)
        updateStreak(for: .keystrokes, metToday: keystrokesMet, date: today)
        updateStreak(for: .focusScore, metToday: focusScoreMet, date: today)

        // Calculate overall streak (all goals met)
        calculateOverallStreak()

        // Play sound if any goal was just met
        if activeTimeMet || keystrokesMet || focusScoreMet {
            if anyGoalNewlyMet(activeTimeMet: activeTimeMet, keystrokesMet: keystrokesMet, focusScoreMet: focusScoreMet) {
                SoundEffectsService.shared.play(.goalReached)
            }
        }

        saveStreaks()
    }

    /// Get streak for a specific goal
    public func getStreak(for goalType: GoalType) -> GoalStreak {
        streaks[goalType] ?? GoalStreak(goalType: goalType)
    }

    /// Check if a goal was met on a specific date
    public func wasGoalMet(_ goalType: GoalType, on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return streaks[goalType]?.streakHistory.contains { calendar.isDate($0, inSameDayAs: dayStart) } ?? false
    }

    // MARK: - Private

    private func updateStreak(for goalType: GoalType, metToday: Bool, date: Date) {
        var streak = streaks[goalType] ?? GoalStreak(goalType: goalType)

        let dayStart = calendar.startOfDay(for: date)

        // Already recorded today
        if streak.streakHistory.contains(where: { calendar.isDate($0, inSameDayAs: dayStart) }) {
            return
        }

        if metToday {
            // Check if yesterday was met (for streak continuity)
            if let lastMet = streak.lastMetDate {
                let daysSinceLastMet = calendar.dateComponents([.day], from: lastMet, to: dayStart).day ?? 0

                if daysSinceLastMet == 1 {
                    // Continuing streak
                    streak.currentStreak += 1
                } else if daysSinceLastMet > 1 {
                    // Streak broken, start new
                    streak.currentStreak = 1
                }
                // daysSinceLastMet == 0 means same day, don't increment
            } else {
                // First time meeting goal
                streak.currentStreak = 1
            }

            streak.lastMetDate = dayStart
            streak.streakHistory.append(dayStart)

            // Update longest streak
            if streak.currentStreak > streak.longestStreak {
                streak.longestStreak = streak.currentStreak
            }
        } else {
            // Goal not met today - check if streak should be reset
            if let lastMet = streak.lastMetDate {
                let daysSinceLastMet = calendar.dateComponents([.day], from: lastMet, to: dayStart).day ?? 0
                if daysSinceLastMet > 1 {
                    streak.currentStreak = 0
                }
            }
        }

        // Keep only last 365 days of history
        streak.streakHistory = streak.streakHistory.filter { date in
            let daysSinceDate = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            return daysSinceDate <= 365
        }

        streaks[goalType] = streak
    }

    private func calculateOverallStreak() {
        // Find longest consecutive run where all goals were met on the same days
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        while true {
            let allMet = GoalType.allCases.allSatisfy { goalType in
                wasGoalMet(goalType, on: currentDate)
            }

            if allMet {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        overallStreak = streak
    }

    private func anyGoalNewlyMet(activeTimeMet: Bool, keystrokesMet: Bool, focusScoreMet: Bool) -> Bool {
        let today = calendar.startOfDay(for: Date())

        if activeTimeMet && !wasGoalMet(.activeTime, on: today) { return true }
        if keystrokesMet && !wasGoalMet(.keystrokes, on: today) { return true }
        if focusScoreMet && !wasGoalMet(.focusScore, on: today) { return true }

        return false
    }

    // MARK: - Persistence

    private func loadStreaks() {
        guard let data = UserDefaults.standard.data(forKey: streaksKey),
              let decoded = try? JSONDecoder().decode([String: GoalStreak].self, from: data) else {
            // Initialize default streaks
            for goalType in GoalType.allCases {
                streaks[goalType] = GoalStreak(goalType: goalType)
            }
            return
        }

        for (key, streak) in decoded {
            if let goalType = GoalType(rawValue: key) {
                streaks[goalType] = streak
            }
        }
    }

    private func saveStreaks() {
        let encoded = Dictionary(uniqueKeysWithValues: streaks.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: streaksKey)
        }
    }
}

// MARK: - Goal Streak Card View

struct GoalStreakCard: View {
    @ObservedObject private var streakService = GoalStreakService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            HStack {
                Text("Goal Streaks")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                // Overall streak badge
                if streakService.overallStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(ClarityColors.warning)
                        Text("\(streakService.overallStreak)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(ClarityColors.warning)
                        Text("day streak")
                            .font(.system(size: 12))
                            .foregroundColor(ClarityColors.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ClarityColors.warning.opacity(0.1))
                    .cornerRadius(ClarityRadius.md)
                }
            }

            // Individual goal streaks
            HStack(spacing: ClaritySpacing.lg) {
                ForEach(GoalStreakService.GoalType.allCases, id: \.self) { goalType in
                    GoalStreakRing(
                        goalType: goalType,
                        streak: streakService.getStreak(for: goalType)
                    )
                }
            }
        }
        .task {
            await streakService.checkStreaks()
        }
    }
}

// MARK: - Goal Streak Ring

struct GoalStreakRing: View {
    let goalType: GoalStreakService.GoalType
    let streak: GoalStreakService.GoalStreak

    @State private var animatedStreak: Int = 0

    var body: some View {
        VStack(spacing: ClaritySpacing.sm) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(goalType.color.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)

                // Progress indicator (based on current streak towards record)
                Circle()
                    .trim(from: 0, to: progressToRecord)
                    .stroke(
                        goalType.color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                // Streak count
                VStack(spacing: 0) {
                    Text("\(animatedStreak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(ClarityColors.textPrimary)
                    Image(systemName: goalType.icon)
                        .font(.system(size: 10))
                        .foregroundColor(goalType.color)
                }
            }

            VStack(spacing: 2) {
                Text(goalType.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ClarityColors.textPrimary)

                if streak.longestStreak > 0 {
                    Text("Best: \(streak.longestStreak)")
                        .font(.system(size: 9))
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedStreak = streak.currentStreak
            }
        }
        .onChange(of: streak.currentStreak) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedStreak = newValue
            }
        }
    }

    private var progressToRecord: Double {
        guard streak.longestStreak > 0 else { return 0 }
        return min(1.0, Double(streak.currentStreak) / Double(streak.longestStreak))
    }
}

// MARK: - Preview

#Preview {
    GlassCard {
        GoalStreakCard()
    }
    .padding()
    .frame(width: 500)
}

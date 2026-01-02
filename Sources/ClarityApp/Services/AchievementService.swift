import Foundation
import ClarityShared

/// Service for tracking and awarding achievements
@MainActor
public class AchievementService: ObservableObject {
    public static let shared = AchievementService()

    @Published public private(set) var earnedAchievements: [EarnedAchievement] = []
    @Published public private(set) var newlyEarned: Achievement?

    private let statsRepo = StatsRepository()
    private let db = DatabaseManager.shared

    private init() {
        loadEarnedAchievements()
    }

    // MARK: - Public API

    /// Check all achievements and award any newly earned ones
    public func checkAchievements() async {
        do {
            _ = try statsRepo.aggregateDaily(for: Date())
        } catch {
            // Continue even if daily aggregation fails
        }
        for achievement in Achievements.all {
            if !hasEarned(achievement.id) {
                if await checkRequirement(achievement.requirement) {
                    award(achievement)
                }
            }
        }
    }

    /// Check if an achievement has been earned
    public func hasEarned(_ achievementId: String) -> Bool {
        earnedAchievements.contains { $0.achievementId == achievementId }
    }

    /// Get all achievements with their earned status
    public func getAllWithStatus() -> [(achievement: Achievement, earned: Bool, earnedAt: Date?)] {
        Achievements.all.map { achievement in
            let earned = earnedAchievements.first { $0.achievementId == achievement.id }
            return (achievement, earned != nil, earned?.earnedAt)
        }
    }

    /// Get count of earned achievements
    public var earnedCount: Int {
        earnedAchievements.count
    }

    /// Get total achievement count
    public var totalCount: Int {
        Achievements.all.count
    }

    /// Clear the new achievement notification
    public func clearNewAchievement() {
        newlyEarned = nil
    }

    // MARK: - Private

    private func loadEarnedAchievements() {
        do {
            earnedAchievements = try db.read { db in
                try EarnedAchievement
                    .order(EarnedAchievement.Columns.earnedAt.desc)
                    .fetchAll(db)
            }
        } catch {
            print("Error loading earned achievements: \(error)")
        }
    }

    private func award(_ achievement: Achievement) {
        do {
            let earned = EarnedAchievement(achievementId: achievement.id)
            try db.write { db in
                try earned.insert(db)
            }
            earnedAchievements.insert(earned, at: 0)
            newlyEarned = achievement

            // Play celebration sound
            SoundEffectsService.shared.playAchievementSound()
        } catch {
            print("Error awarding achievement '\(achievement.id)': \(error)")
        }
    }

    private func checkRequirement(_ requirement: AchievementRequirement) async -> Bool {
        switch requirement {
        case .focusSessions(let count):
            return await getFocusSessionCount() >= count

        case .focusMinutes(let minutes):
            return await getLongestFocusSession() >= minutes

        case .deepWorkSessions(let count):
            return await getDeepWorkSessionCount() >= count

        case .activeMinutes(let minutes):
            return await getTodayActiveMinutes() >= minutes

        case .keystrokes(let count):
            return await getTodayKeystrokes() >= count

        case .clicks(let count):
            return await getTodayClicks() >= count

        case .consecutiveDays(let days):
            return await getConsecutiveDays() >= days

        case .earlyStart(let hour, let count):
            return await getEarlyStartCount(beforeHour: hour) >= count

        case .lateNight(let hour, let count):
            return await getLateNightCount(afterHour: hour) >= count
        }
    }

    // MARK: - Data Queries

    private func getFocusSessionCount() async -> Int {
        do {
            return try db.read { db in
                try FocusSession.fetchCount(db)
            }
        } catch {
            return 0
        }
    }

    private func getLongestFocusSession() async -> Int {
        do {
            return try db.read { db in
                let sessions = try FocusSession.fetchAll(db, sql: """
                    SELECT * FROM focus_sessions WHERE endTime IS NOT NULL
                """)

                let maxDuration = sessions.compactMap { $0.durationSeconds }.max() ?? 0
                return maxDuration / 60  // Convert to minutes
            }
        } catch {
            return 0
        }
    }

    private func getDeepWorkSessionCount() async -> Int {
        do {
            return try db.read { db in
                let sessions = try FocusSession.fetchAll(db, sql: """
                    SELECT * FROM focus_sessions WHERE endTime IS NOT NULL
                """)

                return sessions.filter { $0.isDeepWork }.count
            }
        } catch {
            return 0
        }
    }

    private func getTodayActiveMinutes() async -> Int {
        do {
            let seconds = try statsRepo.getTodayActiveTime()
            return seconds / 60
        } catch {
            return 0
        }
    }

    private func getTodayKeystrokes() async -> Int {
        do {
            return try statsRepo.getTodayKeystrokes()
        } catch {
            return 0
        }
    }

    private func getTodayClicks() async -> Int {
        // Get today's stats
        let stats = await DataService.shared.getStats(for: Date())
        return stats.clicks
    }

    private func getConsecutiveDays() async -> Int {
        do {
            // Check how many consecutive days have activity
            let calendar = Calendar.current
            var currentDate = Date()
            var consecutiveDays = 0

            for _ in 0..<365 {  // Check up to a year back
                let stats = try statsRepo.getDailyStats(from: currentDate, to: currentDate)
                let hasDailyActivity = stats.first.map { $0.totalActiveSeconds > 0 } ?? false
                let activityFromMinuteStats = try statsRepo.hasActivity(on: currentDate)
                let hasActivity = hasDailyActivity || activityFromMinuteStats
                if !hasActivity { break }

                consecutiveDays += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                    break
                }
                currentDate = previousDay
            }

            return consecutiveDays
        } catch {
            return 0
        }
    }

    private func getEarlyStartCount(beforeHour: Int) async -> Int {
        do {
            return try db.read { db in
                let stats = try DailyStat.fetchAll(db)
                return stats.filter { stat in
                    guard let firstActivity = stat.firstActivity else { return false }
                    let hour = Calendar.current.component(.hour, from: firstActivity)
                    return hour < beforeHour
                }.count
            }
        } catch {
            return 0
        }
    }

    private func getLateNightCount(afterHour: Int) async -> Int {
        do {
            return try db.read { db in
                let stats = try DailyStat.fetchAll(db)
                return stats.filter { stat in
                    guard let lastActivity = stat.lastActivity else { return false }
                    let hour = Calendar.current.component(.hour, from: lastActivity)
                    return hour >= afterHour
                }.count
            }
        } catch {
            return 0
        }
    }
}

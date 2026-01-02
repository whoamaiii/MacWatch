import Foundation
import GRDB

/// Achievement definition
public struct Achievement: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let category: AchievementCategory
    public let requirement: AchievementRequirement

    public init(id: String, name: String, description: String, icon: String, category: AchievementCategory, requirement: AchievementRequirement) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.requirement = requirement
    }
}

/// Achievement categories
public enum AchievementCategory: String, Codable, CaseIterable {
    case focus = "Focus"
    case productivity = "Productivity"
    case consistency = "Consistency"
    case input = "Input"
}

/// Achievement requirement types
public enum AchievementRequirement: Codable {
    case focusMinutes(Int)
    case focusSessions(Int)
    case deepWorkSessions(Int)
    case activeMinutes(Int)
    case keystrokes(Int)
    case clicks(Int)
    case consecutiveDays(Int)
    case earlyStart(hour: Int, count: Int)
    case lateNight(hour: Int, count: Int)
}

/// User's earned achievement
public struct EarnedAchievement: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public var id: Int64?
    public var achievementId: String
    public var earnedAt: Date
    public var notified: Bool

    public static var databaseTableName: String { "earned_achievements" }

    public init(id: Int64? = nil, achievementId: String, earnedAt: Date = Date(), notified: Bool = false) {
        self.id = id
        self.achievementId = achievementId
        self.earnedAt = earnedAt
        self.notified = notified
    }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let achievementId = Column(CodingKeys.achievementId)
        public static let earnedAt = Column(CodingKeys.earnedAt)
        public static let notified = Column(CodingKeys.notified)
    }
}

/// All available achievements
public struct Achievements {
    public static let all: [Achievement] = [
        // Focus achievements
        Achievement(
            id: "first_focus",
            name: "First Focus",
            description: "Complete your first focus session",
            icon: "target",
            category: .focus,
            requirement: .focusSessions(1)
        ),
        Achievement(
            id: "flow_state",
            name: "Flow State",
            description: "Complete a 25+ minute focus session",
            icon: "flame.fill",
            category: .focus,
            requirement: .focusMinutes(25)
        ),
        Achievement(
            id: "deep_diver",
            name: "Deep Diver",
            description: "Complete 5 deep work sessions",
            icon: "water.waves",
            category: .focus,
            requirement: .deepWorkSessions(5)
        ),
        Achievement(
            id: "marathon",
            name: "Marathon",
            description: "Complete a 2-hour focus session",
            icon: "figure.run",
            category: .focus,
            requirement: .focusMinutes(120)
        ),

        // Productivity achievements
        Achievement(
            id: "early_bird",
            name: "Early Bird",
            description: "Start working before 7 AM (5 times)",
            icon: "sunrise.fill",
            category: .productivity,
            requirement: .earlyStart(hour: 7, count: 5)
        ),
        Achievement(
            id: "night_owl",
            name: "Night Owl",
            description: "Work past 10 PM (5 times)",
            icon: "moon.stars.fill",
            category: .productivity,
            requirement: .lateNight(hour: 22, count: 5)
        ),
        Achievement(
            id: "productive_day",
            name: "Productive Day",
            description: "Log 4+ hours of active time in a day",
            icon: "chart.bar.fill",
            category: .productivity,
            requirement: .activeMinutes(240)
        ),

        // Input achievements
        Achievement(
            id: "keyboard_warrior",
            name: "Keyboard Warrior",
            description: "Type 10,000 keystrokes in a day",
            icon: "keyboard.fill",
            category: .input,
            requirement: .keystrokes(10000)
        ),
        Achievement(
            id: "click_master",
            name: "Click Master",
            description: "Click 5,000 times in a day",
            icon: "cursorarrow.click.2",
            category: .input,
            requirement: .clicks(5000)
        ),
        Achievement(
            id: "speed_typist",
            name: "Speed Typist",
            description: "Type 50,000 keystrokes in a day",
            icon: "bolt.fill",
            category: .input,
            requirement: .keystrokes(50000)
        ),

        // Consistency achievements
        Achievement(
            id: "streak_starter",
            name: "Streak Starter",
            description: "Use Clarity 3 days in a row",
            icon: "flame",
            category: .consistency,
            requirement: .consecutiveDays(3)
        ),
        Achievement(
            id: "committed",
            name: "Committed",
            description: "Use Clarity 7 days in a row",
            icon: "flame.fill",
            category: .consistency,
            requirement: .consecutiveDays(7)
        ),
        Achievement(
            id: "dedicated",
            name: "Dedicated",
            description: "Use Clarity 30 days in a row",
            icon: "star.fill",
            category: .consistency,
            requirement: .consecutiveDays(30)
        ),
    ]

    public static func get(id: String) -> Achievement? {
        all.first { $0.id == id }
    }
}

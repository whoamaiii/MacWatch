import Foundation
import GRDB

/// Daily summary statistics
public struct DailyStat: Codable, Identifiable {
    public var id: String { date }  // Date string is the ID
    public var date: String  // YYYY-MM-DD format

    // Time metrics
    public var totalActiveSeconds: Int
    public var totalFocusSeconds: Int
    public var firstActivity: Date?
    public var lastActivity: Date?

    // Input metrics
    public var totalKeystrokes: Int
    public var totalClicks: Int
    public var totalScroll: Int

    // Scores (0-100)
    public var focusScore: Double
    public var productivityScore: Double

    // JSON-encoded detailed data
    public var topAppsJson: String?
    public var hourlyBreakdownJson: String?

    public init(
        date: String,
        totalActiveSeconds: Int = 0,
        totalFocusSeconds: Int = 0,
        firstActivity: Date? = nil,
        lastActivity: Date? = nil,
        totalKeystrokes: Int = 0,
        totalClicks: Int = 0,
        totalScroll: Int = 0,
        focusScore: Double = 0,
        productivityScore: Double = 0,
        topAppsJson: String? = nil,
        hourlyBreakdownJson: String? = nil
    ) {
        self.date = date
        self.totalActiveSeconds = totalActiveSeconds
        self.totalFocusSeconds = totalFocusSeconds
        self.firstActivity = firstActivity
        self.lastActivity = lastActivity
        self.totalKeystrokes = totalKeystrokes
        self.totalClicks = totalClicks
        self.totalScroll = totalScroll
        self.focusScore = focusScore
        self.productivityScore = productivityScore
        self.topAppsJson = topAppsJson
        self.hourlyBreakdownJson = hourlyBreakdownJson
    }

    /// Formatted active time
    public var formattedActiveTime: String {
        let hours = totalActiveSeconds / 3600
        let minutes = (totalActiveSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Formatted focus time
    public var formattedFocusTime: String {
        let hours = totalFocusSeconds / 3600
        let minutes = (totalFocusSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Parse top apps from JSON
    public var topApps: [AppUsageSummary] {
        guard let json = topAppsJson,
              let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AppUsageSummary].self, from: data)) ?? []
    }

    /// Parse hourly breakdown from JSON
    public var hourlyBreakdown: [Int: Int] {
        guard let json = hourlyBreakdownJson,
              let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([Int: Int].self, from: data)) ?? [:]
    }
}

/// Summary of app usage for daily stats
public struct AppUsageSummary: Codable {
    public var appId: Int64
    public var name: String
    public var seconds: Int
    public var keystrokes: Int

    public init(appId: Int64, name: String, seconds: Int, keystrokes: Int) {
        self.appId = appId
        self.name = name
        self.seconds = seconds
        self.keystrokes = keystrokes
    }
}

// MARK: - GRDB Conformance

extension DailyStat: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "daily_stats" }

    public static var persistenceConflictPolicy: PersistenceConflictPolicy {
        .init(insert: .replace, update: .replace)
    }

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let totalActiveSeconds = Column(CodingKeys.totalActiveSeconds)
        static let totalFocusSeconds = Column(CodingKeys.totalFocusSeconds)
        static let firstActivity = Column(CodingKeys.firstActivity)
        static let lastActivity = Column(CodingKeys.lastActivity)
        static let totalKeystrokes = Column(CodingKeys.totalKeystrokes)
        static let totalClicks = Column(CodingKeys.totalClicks)
        static let totalScroll = Column(CodingKeys.totalScroll)
        static let focusScore = Column(CodingKeys.focusScore)
        static let productivityScore = Column(CodingKeys.productivityScore)
        static let topAppsJson = Column(CodingKeys.topAppsJson)
        static let hourlyBreakdownJson = Column(CodingKeys.hourlyBreakdownJson)
    }
}

import Foundation
import GRDB

/// Repository for App-related database operations
public final class AppRepository {
    private let db: DatabaseManager

    public init(db: DatabaseManager = .shared) {
        self.db = db
    }

    // MARK: - CRUD Operations

    /// Find or create an app by bundle ID (handles concurrent inserts safely)
    public func findOrCreate(bundleId: String, name: String) throws -> App {
        try db.write { db in
            // First try to find existing
            let request = App.filter(App.Columns.bundleId == bundleId)
            if let existing = try request.fetchOne(db) {
                return existing
            }

            // Try to insert - use INSERT OR IGNORE to handle race conditions
            let app = App(
                bundleId: bundleId,
                name: name,
                category: AppCategory.from(bundleId: bundleId)
            )

            do {
                try app.insert(db)
                if let inserted = try request.fetchOne(db) {
                    return inserted
                }
                return app
            } catch {
                // Insert failed (likely unique constraint) - fetch the existing one
                if let existing = try request.fetchOne(db) {
                    return existing
                }
                // Re-throw if we still can't find it
                throw error
            }
        }
    }

    /// Get app by ID
    public func get(id: Int64) throws -> App? {
        try db.read { db in
            try App.fetchOne(db, key: id)
        }
    }

    /// Get app by bundle ID
    public func get(bundleId: String) throws -> App? {
        try db.read { db in
            try App
                .filter(App.Columns.bundleId == bundleId)
                .fetchOne(db)
        }
    }

    /// Get all apps
    public func getAll() throws -> [App] {
        try db.read { db in
            try App
                .order(App.Columns.name)
                .fetchAll(db)
        }
    }

    /// Update app category by ID
    public func updateCategory(appId: Int64, category: AppCategory) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE apps SET category = ? WHERE id = ?",
                arguments: [category.rawValue, appId]
            )
        }
    }

    /// Update app category by bundle ID
    public func updateCategory(bundleId: String, category: AppCategory) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE apps SET category = ? WHERE bundleId = ?",
                arguments: [category.rawValue, bundleId]
            )
        }
    }

    /// Mark app as distraction
    public func setDistraction(appId: Int64, isDistraction: Bool) throws {
        try db.write { db in
            try db.execute(
                sql: "UPDATE apps SET isDistraction = ? WHERE id = ?",
                arguments: [isDistraction, appId]
            )
        }
    }

    // MARK: - Queries

    /// Get top apps by usage for a date
    public func getTopApps(for date: Date, limit: Int = 10) throws -> [AppUsage] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int64(endOfDay.timeIntervalSince1970)

        return try db.read { db in
            let sql = """
                SELECT
                    a.id,
                    a.bundleId,
                    a.name,
                    a.category,
                    SUM(m.activeSeconds) as totalSeconds,
                    SUM(m.keystrokes) as keystrokes,
                    SUM(m.clicks) as clicks
                FROM apps a
                JOIN minute_stats m ON a.id = m.appId
                WHERE m.timestamp >= ? AND m.timestamp < ?
                GROUP BY a.id
                ORDER BY totalSeconds DESC
                LIMIT ?
            """

            return try AppUsage.fetchAll(db, sql: sql, arguments: [
                startTimestamp, endTimestamp, limit
            ])
        }
    }

    /// Get top apps by usage for a date range
    public func getTopApps(from startDate: Date, to endDate: Date, limit: Int = 10) throws -> [AppUsage] {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            let sql = """
                SELECT
                    a.id,
                    a.bundleId,
                    a.name,
                    a.category,
                    SUM(m.activeSeconds) as totalSeconds,
                    SUM(m.keystrokes) as keystrokes,
                    SUM(m.clicks) as clicks
                FROM apps a
                JOIN minute_stats m ON a.id = m.appId
                WHERE m.timestamp >= ? AND m.timestamp < ?
                GROUP BY a.id
                ORDER BY totalSeconds DESC
                LIMIT ?
            """

            return try AppUsage.fetchAll(db, sql: sql, arguments: [
                startTimestamp, endTimestamp, limit
            ])
        }
    }

    /// Get app usage for a date range
    public func getUsage(appId: Int64, from startDate: Date, to endDate: Date) throws -> [MinuteStat] {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            try MinuteStat
                .filter(MinuteStat.Columns.appId == appId)
                .filter(MinuteStat.Columns.timestamp >= startTimestamp)
                .filter(MinuteStat.Columns.timestamp < endTimestamp)
                .order(MinuteStat.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Get distraction apps
    public func getDistractionApps() throws -> [App] {
        try db.read { db in
            try App
                .filter(App.Columns.isDistraction == true)
                .fetchAll(db)
        }
    }
}

// MARK: - App Usage Query Result

public struct AppUsage: Codable, FetchableRecord, Identifiable {
    public var id: Int64
    public var bundleId: String
    public var name: String
    public var category: AppCategory
    public var totalSeconds: Int
    public var keystrokes: Int
    public var clicks: Int

    /// Formatted duration
    public var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Percentage of total (set externally)
    public var percentage: Double = 0
}

import Foundation
import GRDB

/// Repository for statistics-related database operations
public final class StatsRepository {
    private let db: DatabaseManager

    public init(db: DatabaseManager = .shared) {
        self.db = db
    }

    // MARK: - Minute Stats

    /// Record or update minute stats
    public func recordMinuteStat(
        timestamp: Int64,
        appId: Int64,
        keystrokes: Int = 0,
        clicks: Int = 0,
        scrollDistance: Int = 0,
        mouseDistance: Int = 0,
        activeSeconds: Int = 0
    ) throws {
        try db.write { db in
            // Try to update existing record
            try db.execute(
                sql: """
                    UPDATE minute_stats SET
                        keystrokes = keystrokes + ?,
                        clicks = clicks + ?,
                        scrollDistance = scrollDistance + ?,
                        mouseDistance = mouseDistance + ?,
                        activeSeconds = activeSeconds + ?
                    WHERE timestamp = ? AND appId = ?
                """,
                arguments: [keystrokes, clicks, scrollDistance, mouseDistance, activeSeconds, timestamp, appId]
            )

            // If no rows updated, insert new record
            if db.changesCount == 0 {
                var stat = MinuteStat(
                    timestamp: timestamp,
                    appId: appId,
                    keystrokes: keystrokes,
                    clicks: clicks,
                    scrollDistance: scrollDistance,
                    mouseDistance: mouseDistance,
                    activeSeconds: activeSeconds
                )
                try stat.insert(db)
            }
        }
    }

    /// Get minute stats for a time range
    public func getMinuteStats(from start: Date, to end: Date) throws -> [MinuteStat] {
        let startTimestamp = Int64(start.timeIntervalSince1970)
        let endTimestamp = Int64(end.timeIntervalSince1970)

        return try db.read { db in
            try MinuteStat
                .filter(MinuteStat.Columns.timestamp >= startTimestamp)
                .filter(MinuteStat.Columns.timestamp < endTimestamp)
                .order(MinuteStat.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Get total keystrokes for today
    public func getTodayKeystrokes() throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)

        return try db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COALESCE(SUM(keystrokes), 0) FROM minute_stats
                WHERE timestamp >= ?
            """, arguments: [startTimestamp]) ?? 0
        }
    }

    /// Get total active time for today (in seconds)
    public func getTodayActiveTime() throws -> Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)

        return try db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COALESCE(SUM(activeSeconds), 0) FROM minute_stats
                WHERE timestamp >= ?
            """, arguments: [startTimestamp]) ?? 0
        }
    }

    // MARK: - Daily Stats

    /// Get or create daily stats for a date
    public func getDailyStat(for date: Date) throws -> DailyStat {
        let dateString = formatDate(date)

        return try db.write { db in
            if let existing = try DailyStat.fetchOne(db, key: dateString) {
                return existing
            }

            let stat = DailyStat(date: dateString)
            try stat.insert(db)
            return stat
        }
    }

    /// Update daily stats
    public func updateDailyStat(_ stat: DailyStat) throws {
        try db.write { db in
            try stat.update(db)
        }
    }

    /// Aggregate minute stats into daily stat
    public func aggregateDaily(for date: Date) throws -> DailyStat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int64(endOfDay.timeIntervalSince1970)

        return try db.write { db in
            // Aggregate from minute stats
            let row = try Row.fetchOne(db, sql: """
                SELECT
                    COALESCE(SUM(activeSeconds), 0) as totalActiveSeconds,
                    COALESCE(SUM(keystrokes), 0) as totalKeystrokes,
                    COALESCE(SUM(clicks), 0) as totalClicks,
                    COALESCE(SUM(scrollDistance), 0) as totalScroll,
                    MIN(timestamp) as firstTimestamp,
                    MAX(timestamp) as lastTimestamp
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
            """, arguments: [startTimestamp, endTimestamp])

            let dateString = formatDate(date)
            var stat = DailyStat(date: dateString)

            if let row = row {
                stat.totalActiveSeconds = row["totalActiveSeconds"] ?? 0
                stat.totalKeystrokes = row["totalKeystrokes"] ?? 0
                stat.totalClicks = row["totalClicks"] ?? 0
                stat.totalScroll = row["totalScroll"] ?? 0

                if let first: Int64 = row["firstTimestamp"] {
                    stat.firstActivity = Date(timeIntervalSince1970: TimeInterval(first))
                }
                if let last: Int64 = row["lastTimestamp"] {
                    stat.lastActivity = Date(timeIntervalSince1970: TimeInterval(last))
                }
            }

            // Get focus time from sessions
            let focusSeconds = try Int.fetchOne(db, sql: """
                SELECT COALESCE(SUM(
                    CAST((julianday(endTime) - julianday(startTime)) * 86400 AS INTEGER)
                ), 0)
                FROM focus_sessions
                WHERE startTime >= ? AND startTime < ? AND endTime IS NOT NULL
            """, arguments: [startOfDay, endOfDay]) ?? 0

            stat.totalFocusSeconds = focusSeconds

            // Calculate focus score
            if stat.totalActiveSeconds > 0 {
                stat.focusScore = Double(stat.totalFocusSeconds) / Double(stat.totalActiveSeconds) * 100
            }

            // Save or update
            try stat.save(db)
            return stat
        }
    }

    /// Get daily stats for a range
    public func getDailyStats(from startDate: Date, to endDate: Date) throws -> [DailyStat] {
        let startString = formatDate(startDate)
        let endString = formatDate(endDate)

        return try db.read { db in
            try DailyStat
                .filter(DailyStat.Columns.date >= startString)
                .filter(DailyStat.Columns.date <= endString)
                .order(DailyStat.Columns.date)
                .fetchAll(db)
        }
    }

    // MARK: - Hourly Breakdown

    /// Get hourly breakdown for a date
    public func getHourlyBreakdown(for date: Date) throws -> [Int: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    ((timestamp - ?) / 3600) as hour,
                    SUM(activeSeconds) as seconds
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ? + 86400
                GROUP BY hour
            """, arguments: [startTimestamp, startTimestamp, startTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let seconds: Int = row["seconds"] {
                    breakdown[hour] = seconds
                }
            }
            return breakdown
        }
    }

    // MARK: - Focus Sessions

    /// Start a new focus session
    public func startFocusSession() throws -> FocusSession {
        try db.write { db in
            var session = FocusSession(startTime: Date())
            try session.insert(db)
            return session
        }
    }

    /// End a focus session
    public func endFocusSession(id: Int64) throws -> FocusSession? {
        try db.write { db in
            guard var session = try FocusSession.fetchOne(db, key: id) else {
                return nil
            }

            session.endTime = Date()

            // Calculate metrics from minute_stats during session
            let startTimestamp = Int64(session.startTime.timeIntervalSince1970)
            let endTimestamp = Int64(Date().timeIntervalSince1970)

            let row = try Row.fetchOne(db, sql: """
                SELECT
                    COALESCE(SUM(keystrokes), 0) as keystrokes,
                    COALESCE(SUM(clicks), 0) as clicks
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp <= ?
            """, arguments: [startTimestamp, endTimestamp])

            if let row = row {
                session.keystrokes = row["keystrokes"] ?? 0
                session.clicks = row["clicks"] ?? 0
            }

            try session.update(db)
            return session
        }
    }

    /// Get focus sessions for a date
    public func getFocusSessions(for date: Date) throws -> [FocusSession] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try db.read { db in
            try FocusSession
                .filter(FocusSession.Columns.startTime >= startOfDay)
                .filter(FocusSession.Columns.startTime < endOfDay)
                .order(FocusSession.Columns.startTime.desc)
                .fetchAll(db)
        }
    }

    /// Get current active focus session (if any)
    public func getActiveFocusSession() throws -> FocusSession? {
        try db.read { db in
            try FocusSession
                .filter(FocusSession.Columns.endTime == nil)
                .order(FocusSession.Columns.startTime.desc)
                .fetchOne(db)
        }
    }

    /// Get total focus time for a date (in seconds)
    public func getTotalFocusTime(for date: Date) throws -> Int {
        let sessions = try getFocusSessions(for: date)
        return sessions.compactMap { $0.durationSeconds }.reduce(0, +)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

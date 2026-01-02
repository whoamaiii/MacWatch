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
    /// Uses UPSERT pattern to atomically insert or update, avoiding race conditions
    public func recordMinuteStat(
        timestamp: Int64,
        appId: Int64,
        keystrokes: Int = 0,
        clicks: Int = 0,
        scrollDistance: Int = 0,
        mouseDistance: Int = 0,
        activeSeconds: Int = 0,
        idleSeconds: Int = 0
    ) throws {
        try db.write { db in
            // Use UPSERT pattern for atomic insert-or-update
            // This avoids race conditions between UPDATE and INSERT
            try db.execute(
                sql: """
                    INSERT INTO minute_stats (timestamp, appId, keystrokes, clicks, scrollDistance, mouseDistance, activeSeconds, idleSeconds)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(timestamp, appId) DO UPDATE SET
                        keystrokes = keystrokes + excluded.keystrokes,
                        clicks = clicks + excluded.clicks,
                        scrollDistance = scrollDistance + excluded.scrollDistance,
                        mouseDistance = mouseDistance + excluded.mouseDistance,
                        activeSeconds = activeSeconds + excluded.activeSeconds,
                        idleSeconds = idleSeconds + excluded.idleSeconds
                """,
                arguments: [timestamp, appId, keystrokes, clicks, scrollDistance, mouseDistance, activeSeconds, idleSeconds]
            )
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

    /// Get app usage totals for a date range
    public func getAppUsageTotals(appId: Int64, from start: Date, to end: Date) throws -> (activeSeconds: Int, keystrokes: Int, clicks: Int) {
        let startTimestamp = Int64(start.timeIntervalSince1970)
        let endTimestamp = Int64(end.timeIntervalSince1970)

        return try db.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT
                    COALESCE(SUM(activeSeconds), 0) as activeSeconds,
                    COALESCE(SUM(keystrokes), 0) as keystrokes,
                    COALESCE(SUM(clicks), 0) as clicks
                FROM minute_stats
                WHERE appId = ? AND timestamp >= ? AND timestamp < ?
            """, arguments: [appId, startTimestamp, endTimestamp])

            let activeSeconds: Int = row?["activeSeconds"] ?? 0
            let keystrokes: Int = row?["keystrokes"] ?? 0
            let clicks: Int = row?["clicks"] ?? 0
            return (activeSeconds, keystrokes, clicks)
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
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

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

            // Get focus time from sessions (count overlapping sessions within the day)
            // Use >= for inclusive boundary to include sessions ending exactly at day start
            let sessions = try FocusSession
                .filter(FocusSession.Columns.startTime < endOfDay)
                .filter(FocusSession.Columns.endTime != nil)
                .filter(FocusSession.Columns.endTime >= startOfDay)
                .fetchAll(db)

            let focusSeconds = sessions.reduce(0) { total, session in
                guard let end = session.endTime else { return total }
                let overlapStart = max(session.startTime, startOfDay)
                let overlapEnd = min(end, endOfDay)
                let seconds = max(0, overlapEnd.timeIntervalSince(overlapStart))
                return total + Int(seconds)
            }

            stat.totalFocusSeconds = focusSeconds

            // Calculate focus score (capped at 100%)
            if stat.totalActiveSeconds > 0 {
                stat.focusScore = min(100.0, Double(stat.totalFocusSeconds) / Double(stat.totalActiveSeconds) * 100)
            }

            // Calculate productivity score from non-distraction time
            let productivityRow = try Row.fetchOne(db, sql: """
                SELECT
                    COALESCE(SUM(m.activeSeconds), 0) as totalSeconds,
                    COALESCE(SUM(CASE WHEN a.isDistraction = 0 THEN m.activeSeconds ELSE 0 END), 0) as productiveSeconds
                FROM minute_stats m
                JOIN apps a ON m.appId = a.id
                WHERE m.timestamp >= ? AND m.timestamp < ?
            """, arguments: [startTimestamp, endTimestamp])

            if let total: Int = productivityRow?["totalSeconds"], total > 0 {
                let productive: Int = productivityRow?["productiveSeconds"] ?? 0
                stat.productivityScore = min(100.0, Double(productive) / Double(total) * 100)
            }

            // Top apps summary
            let topAppRows = try Row.fetchAll(db, sql: """
                SELECT
                    a.id as appId,
                    a.name as name,
                    COALESCE(SUM(m.activeSeconds), 0) as seconds,
                    COALESCE(SUM(m.keystrokes), 0) as keystrokes
                FROM minute_stats m
                JOIN apps a ON m.appId = a.id
                WHERE m.timestamp >= ? AND m.timestamp < ?
                GROUP BY a.id
                ORDER BY seconds DESC
                LIMIT 5
            """, arguments: [startTimestamp, endTimestamp])

            let topApps = topAppRows.compactMap { row -> AppUsageSummary? in
                guard let appId: Int64 = row["appId"], let name: String = row["name"] else { return nil }
                let seconds: Int = row["seconds"] ?? 0
                let keystrokes: Int = row["keystrokes"] ?? 0
                return AppUsageSummary(appId: appId, name: name, seconds: seconds, keystrokes: keystrokes)
            }

            if !topApps.isEmpty {
                let jsonData = try JSONEncoder().encode(topApps)
                stat.topAppsJson = String(data: jsonData, encoding: .utf8)
            } else {
                stat.topAppsJson = nil
            }

            // Hourly breakdown summary
            let hourlyRows = try Row.fetchAll(db, sql: """
                SELECT
                    ((timestamp - ?) / 3600) as hour,
                    SUM(activeSeconds) as seconds
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in hourlyRows {
                if let hour: Int = row["hour"], let seconds: Int = row["seconds"] {
                    breakdown[hour] = seconds
                }
            }

            if !breakdown.isEmpty {
                let jsonData = try JSONEncoder().encode(breakdown)
                stat.hourlyBreakdownJson = String(data: jsonData, encoding: .utf8)
            } else {
                stat.hourlyBreakdownJson = nil
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

    /// Get distinct app count for a date range
    public func getUniqueAppCount(from startDate: Date, to endDate: Date) throws -> Int {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(DISTINCT appId) FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
            """, arguments: [startTimestamp, endTimestamp]) ?? 0
        }
    }

    /// Get minute stats row count for a date range
    public func getMinuteStatsCount(from startDate: Date, to endDate: Date) throws -> Int {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
            """, arguments: [startTimestamp, endTimestamp]) ?? 0
        }
    }

    /// Get first activity timestamp for a date range
    public func getFirstActivityDate(from startDate: Date, to endDate: Date) throws -> Date? {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            if let timestamp: Int64 = try Int64.fetchOne(db, sql: """
                SELECT MIN(timestamp) FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
            """, arguments: [startTimestamp, endTimestamp]) {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return nil
        }
    }

    /// Check if any activity exists for a given date
    public func hasActivity(on date: Date) throws -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int64(endOfDay.timeIntervalSince1970)

        return try db.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT 1 FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                LIMIT 1
            """, arguments: [startTimestamp, endTimestamp])
            return row != nil
        }
    }

    // MARK: - Hourly Breakdown

    /// Get hourly breakdown for a date (active seconds)
    public func getHourlyBreakdown(for date: Date) throws -> [Int: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int64(endOfDay.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    ((timestamp - ?) / 3600) as hour,
                    SUM(activeSeconds) as seconds
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let seconds: Int = row["seconds"] {
                    breakdown[hour] = seconds
                }
            }
            return breakdown
        }
    }

    /// Get hourly keystroke breakdown for a date
    public func getHourlyKeystrokeBreakdown(for date: Date) throws -> [Int: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int64(endOfDay.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    ((timestamp - ?) / 3600) as hour,
                    SUM(keystrokes) as total
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let total: Int = row["total"] {
                    breakdown[hour] = total
                }
            }
            return breakdown
        }
    }

    /// Get hourly click breakdown for a date
    public func getHourlyClickBreakdown(for date: Date) throws -> [Int: Int] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
        let endTimestamp = Int64(endOfDay.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    ((timestamp - ?) / 3600) as hour,
                    SUM(clicks) as total
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let total: Int = row["total"] {
                    breakdown[hour] = total
                }
            }
            return breakdown
        }
    }

    /// Get hourly breakdown across a date range (active seconds aggregated by hour-of-day)
    public func getHourlyBreakdown(from startDate: Date, to endDate: Date) throws -> [Int: Int] {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    CAST(strftime('%H', datetime(timestamp, 'unixepoch', 'localtime')) AS INTEGER) as hour,
                    SUM(activeSeconds) as seconds
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let seconds: Int = row["seconds"] {
                    breakdown[hour] = seconds
                }
            }
            return breakdown
        }
    }

    /// Get hourly keystroke breakdown across a date range
    public func getHourlyKeystrokeBreakdown(from startDate: Date, to endDate: Date) throws -> [Int: Int] {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    CAST(strftime('%H', datetime(timestamp, 'unixepoch', 'localtime')) AS INTEGER) as hour,
                    SUM(keystrokes) as total
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let total: Int = row["total"] {
                    breakdown[hour] = total
                }
            }
            return breakdown
        }
    }

    /// Get hourly click breakdown across a date range
    public func getHourlyClickBreakdown(from startDate: Date, to endDate: Date) throws -> [Int: Int] {
        let startTimestamp = Int64(startDate.timeIntervalSince1970)
        let endTimestamp = Int64(endDate.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    CAST(strftime('%H', datetime(timestamp, 'unixepoch', 'localtime')) AS INTEGER) as hour,
                    SUM(clicks) as total
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY hour
            """, arguments: [startTimestamp, endTimestamp])

            var breakdown: [Int: Int] = [:]
            for row in rows {
                if let hour: Int = row["hour"], let total: Int = row["total"] {
                    breakdown[hour] = total
                }
            }
            return breakdown
        }
    }

    // MARK: - Focus Sessions

    /// Start a new focus session
    public func startFocusSession(primaryAppId: Int64? = nil) throws -> FocusSession {
        try db.write { db in
            if let existing = try FocusSession
                .filter(FocusSession.Columns.endTime == nil)
                .order(FocusSession.Columns.startTime.desc)
                .fetchOne(db) {
                return existing
            }

            var session = FocusSession(startTime: Date(), primaryAppId: primaryAppId)
            try session.insert(db)
            session.id = db.lastInsertedRowID
            return session
        }
    }

    /// End a focus session
    public func endFocusSession(id: Int64) throws -> FocusSession? {
        try db.write { db -> FocusSession? in
            guard var session = try FocusSession.fetchOne(db, key: id) else {
                return nil
            }
            if session.endTime != nil {
                return session
            }

            let now = Date()
            session.endTime = now

            // Calculate metrics from minute_stats during session
            let startTimestamp = Int64(session.startTime.timeIntervalSince1970)
            let endTimestamp = Int64(now.timeIntervalSince1970)

            var sql = """
                SELECT
                    COALESCE(SUM(keystrokes), 0) as keystrokes,
                    COALESCE(SUM(clicks), 0) as clicks
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp <= ?
            """
            var arguments: [DatabaseValueConvertible?] = [startTimestamp, endTimestamp]
            if let primaryAppId = session.primaryAppId {
                sql += " AND appId = ?"
                arguments.append(primaryAppId)
            }

            let row = try Row.fetchOne(db, sql: sql, arguments: StatementArguments(arguments))

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
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

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

    /// Get recent focus sessions across all dates
    public func getRecentFocusSessions(limit: Int = 10) throws -> [FocusSession] {
        try db.read { db in
            try FocusSession
                .order(FocusSession.Columns.startTime.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Keycode Frequency

    /// Get aggregated keycode frequency for a date range
    public func getKeycodeFrequency(from startDate: Date, to endDate: Date) throws -> [Int: Int] {
        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT dataJson FROM raw_events
                WHERE eventType = 'keycodeFrequency'
                AND timestamp >= ? AND timestamp < ?
            """, arguments: [startDate, endDate])

            var aggregated: [Int: Int] = [:]

            for row in rows {
                guard let jsonString: String = row["dataJson"],
                      let jsonData = Data(base64Encoded: jsonString),
                      let frequency = try? JSONDecoder().decode([Int: Int].self, from: jsonData) else {
                    continue
                }

                for (keyCode, count) in frequency {
                    aggregated[keyCode, default: 0] += count
                }
            }

            return aggregated
        }
    }

    // MARK: - Context Switches

    /// Get context switch count for a date
    public func getContextSwitchCount(for date: Date) throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        return try db.read { db in
            // Get the last context switch event of the day (it contains the running count)
            let row = try Row.fetchOne(db, sql: """
                SELECT dataJson FROM raw_events
                WHERE eventType = 'contextSwitch'
                AND timestamp >= ? AND timestamp < ?
                ORDER BY timestamp DESC
                LIMIT 1
            """, arguments: [startOfDay, endOfDay])

            guard let jsonString: String = row?["dataJson"],
                  let jsonData = Data(base64Encoded: jsonString),
                  let data = try? JSONDecoder().decode([String: Int].self, from: jsonData),
                  let count = data["count"] else {
                return 0
            }
            return count
        }
    }

    // MARK: - Meeting Time

    /// Get total meeting time for a date (in seconds)
    public func getMeetingTime(for date: Date) throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT dataJson FROM raw_events
                WHERE eventType = 'meeting'
                AND timestamp >= ? AND timestamp < ?
            """, arguments: [startOfDay, endOfDay])

            var totalSeconds = 0
            for row in rows {
                guard let jsonString: String = row["dataJson"],
                      let jsonData = Data(base64Encoded: jsonString),
                      let data = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let duration = data["duration"] as? Int else {
                    continue
                }
                totalSeconds += duration
            }
            return totalSeconds
        }
    }

    // MARK: - Click Positions

    /// Get aggregated click positions for a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    ///   - limit: Maximum positions to return (default 50000, prevents memory exhaustion)
    public func getClickPositions(from startDate: Date, to endDate: Date, limit: Int = 50000) throws -> [[Int]] {
        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT dataJson FROM raw_events
                WHERE eventType = 'clickPositions'
                AND timestamp >= ? AND timestamp < ?
                ORDER BY timestamp DESC
            """, arguments: [startDate, endDate])

            var allPositions: [[Int]] = []
            allPositions.reserveCapacity(min(limit, 10000))  // Pre-allocate reasonable amount

            for row in rows {
                guard let jsonString: String = row["dataJson"],
                      let jsonData = Data(base64Encoded: jsonString),
                      let positions = try? JSONDecoder().decode([[Int]].self, from: jsonData) else {
                    continue
                }

                // Check limit before adding more positions
                let remaining = limit - allPositions.count
                if remaining <= 0 {
                    break
                }

                if positions.count <= remaining {
                    allPositions.append(contentsOf: positions)
                } else {
                    // Sample evenly from positions to stay under limit
                    let step = positions.count / remaining
                    for i in stride(from: 0, to: positions.count, by: max(1, step)) {
                        if allPositions.count >= limit { break }
                        allPositions.append(positions[i])
                    }
                }
            }

            return allPositions
        }
    }

    // MARK: - Period Comparison Data

    /// Aggregated stats for a time period used in comparisons
    public struct PeriodStats {
        public var activeSeconds: Int = 0
        public var keystrokes: Int = 0
        public var clicks: Int = 0
        public var scrollDistance: Int = 0
        public var focusSessions: Int = 0
        public var uniqueApps: Int = 0

        public init() {}
    }

    /// Get aggregated stats for a date range
    public func getPeriodStats(from start: Date, to end: Date) throws -> PeriodStats {
        let startTimestamp = Int64(start.timeIntervalSince1970)
        let endTimestamp = Int64(end.timeIntervalSince1970)

        return try db.read { db in
            var stats = PeriodStats()

            // Get minute stats aggregates
            let row = try Row.fetchOne(db, sql: """
                SELECT
                    COALESCE(SUM(activeSeconds), 0) as activeSeconds,
                    COALESCE(SUM(keystrokes), 0) as keystrokes,
                    COALESCE(SUM(clicks), 0) as clicks,
                    COALESCE(SUM(scrollDistance), 0) as scrollDistance,
                    COUNT(DISTINCT appId) as uniqueApps
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
            """, arguments: [startTimestamp, endTimestamp])

            if let row = row {
                stats.activeSeconds = row["activeSeconds"] ?? 0
                stats.keystrokes = row["keystrokes"] ?? 0
                stats.clicks = row["clicks"] ?? 0
                stats.scrollDistance = row["scrollDistance"] ?? 0
                stats.uniqueApps = row["uniqueApps"] ?? 0
            }

            // Get focus session count
            let focusCount = try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM focus_sessions
                WHERE startTime >= ? AND startTime < ? AND endTime IS NOT NULL
            """, arguments: [start, end]) ?? 0
            stats.focusSessions = focusCount

            return stats
        }
    }

    /// Get hourly activity breakdown by day of week (for productivity heatmap)
    /// Returns a dictionary keyed by (dayOfWeek * 100 + hour)
    public func getHourlyByDayOfWeek(from start: Date, to end: Date) throws -> [Int: Int] {
        let startTimestamp = Int64(start.timeIntervalSince1970)
        let endTimestamp = Int64(end.timeIntervalSince1970)

        return try db.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT
                    CAST(strftime('%w', datetime(timestamp, 'unixepoch', 'localtime')) AS INTEGER) as dayOfWeek,
                    CAST(strftime('%H', datetime(timestamp, 'unixepoch', 'localtime')) AS INTEGER) as hour,
                    SUM(activeSeconds) as seconds
                FROM minute_stats
                WHERE timestamp >= ? AND timestamp < ?
                GROUP BY dayOfWeek, hour
            """, arguments: [startTimestamp, endTimestamp])

            var result: [Int: Int] = [:]
            for row in rows {
                if let day: Int = row["dayOfWeek"], let hour: Int = row["hour"], let seconds: Int = row["seconds"] {
                    let key = day * 100 + hour
                    result[key] = seconds
                }
            }
            return result
        }
    }

    /// Get productivity heatmap data - active seconds by hour and day of week
    /// Returns [dayOfWeek][hour] = seconds
    public func getProductivityHeatmap(from start: Date, to end: Date) throws -> [[Int]] {
        let hourlyByDay = try getHourlyByDayOfWeek(from: start, to: end)

        // Initialize 7 days x 24 hours grid
        var grid: [[Int]] = Array(repeating: Array(repeating: 0, count: 24), count: 7)

        for (key, seconds) in hourlyByDay {
            let day = key / 100
            let hour = key % 100
            if day >= 0 && day < 7 && hour >= 0 && hour < 24 {
                grid[day][hour] = seconds
            }
        }

        return grid
    }

    // MARK: - Helpers

    // Static formatter for thread-safe, efficient date formatting
    // Uses local timezone for consistent local analytics
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
}

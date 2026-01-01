import Foundation
import GRDB

/// Singleton database manager for Clarity
public final class DatabaseManager {
    public static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue!

    /// Database file path
    public var databasePath: String {
        dbQueue.path
    }

    private init() {
        do {
            try setupDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    /// Initialize with custom path (for testing)
    public init(path: String) throws {
        dbQueue = try DatabaseQueue(path: path)
        try migrate()
    }

    private func setupDatabase() throws {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let clarityDir = appSupport.appendingPathComponent("Clarity")

        // Create directory if needed
        if !fileManager.fileExists(atPath: clarityDir.path) {
            try fileManager.createDirectory(
                at: clarityDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        let dbPath = clarityDir.appendingPathComponent("clarity.db")

        // Configure database
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable WAL mode for better performance
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        dbQueue = try DatabaseQueue(path: dbPath.path, configuration: config)
        try migrate()

        print("Database initialized at: \(dbPath.path)")
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        // Initial schema
        migrator.registerMigration("v1_initial") { db in
            // Apps table
            try db.create(table: "apps") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bundleId", .text).notNull().unique()
                t.column("name", .text).notNull()
                t.column("category", .text).notNull().defaults(to: "other")
                t.column("isDistraction", .boolean).notNull().defaults(to: false)
                t.column("iconPath", .text)
                t.column("firstSeen", .datetime).notNull()
            }

            // Minute stats table
            try db.create(table: "minute_stats") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .integer).notNull()
                t.column("appId", .integer).notNull()
                    .references("apps", onDelete: .cascade)
                t.column("keystrokes", .integer).notNull().defaults(to: 0)
                t.column("clicks", .integer).notNull().defaults(to: 0)
                t.column("scrollDistance", .integer).notNull().defaults(to: 0)
                t.column("mouseDistance", .integer).notNull().defaults(to: 0)
                t.column("activeSeconds", .integer).notNull().defaults(to: 0)
                t.column("idleSeconds", .integer).notNull().defaults(to: 0)

                t.uniqueKey(["timestamp", "appId"])
            }

            // Focus sessions table
            try db.create(table: "focus_sessions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("startTime", .datetime).notNull()
                t.column("endTime", .datetime)
                t.column("primaryAppId", .integer)
                    .references("apps", onDelete: .setNull)
                t.column("keystrokes", .integer).notNull().defaults(to: 0)
                t.column("clicks", .integer).notNull().defaults(to: 0)
                t.column("interruptions", .integer).notNull().defaults(to: 0)
            }

            // Daily stats table
            try db.create(table: "daily_stats") { t in
                t.column("date", .text).primaryKey()
                t.column("totalActiveSeconds", .integer).notNull().defaults(to: 0)
                t.column("totalFocusSeconds", .integer).notNull().defaults(to: 0)
                t.column("firstActivity", .datetime)
                t.column("lastActivity", .datetime)
                t.column("totalKeystrokes", .integer).notNull().defaults(to: 0)
                t.column("totalClicks", .integer).notNull().defaults(to: 0)
                t.column("totalScroll", .integer).notNull().defaults(to: 0)
                t.column("focusScore", .double).notNull().defaults(to: 0)
                t.column("productivityScore", .double).notNull().defaults(to: 0)
                t.column("topAppsJson", .text)
                t.column("hourlyBreakdownJson", .text)
            }

            // Raw events table (ephemeral)
            try db.create(table: "raw_events") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("timestamp", .datetime).notNull()
                t.column("eventType", .text).notNull()
                t.column("dataJson", .text).notNull()
            }

            // Indexes
            try db.create(
                index: "idx_minute_stats_timestamp",
                on: "minute_stats",
                columns: ["timestamp"]
            )
            try db.create(
                index: "idx_focus_sessions_startTime",
                on: "focus_sessions",
                columns: ["startTime"]
            )
            try db.create(
                index: "idx_raw_events_timestamp",
                on: "raw_events",
                columns: ["timestamp"]
            )
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Database Access

    /// Read from database
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.read(block)
    }

    /// Write to database
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.write(block)
    }

    /// Async write
    public func asyncWrite(_ block: @escaping (Database) throws -> Void) {
        dbQueue.asyncWrite({ db in
            try block(db)
        }, completion: { _, result in
            if case .failure(let error) = result {
                print("Database write error: \(error)")
            }
        })
    }

    // MARK: - Maintenance

    /// Clean up old raw events (older than 7 days)
    public func cleanupOldEvents() throws {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        try write { db in
            try RawEvent
                .filter(RawEvent.Columns.timestamp < cutoff)
                .deleteAll(db)
        }
    }

    /// Clean up old minute stats (older than 90 days)
    public func cleanupOldMinuteStats() throws {
        let cutoff = Int64(Date().addingTimeInterval(-90 * 24 * 60 * 60).timeIntervalSince1970)
        try write { db in
            try MinuteStat
                .filter(MinuteStat.Columns.timestamp < cutoff)
                .deleteAll(db)
        }
    }

    /// Vacuum database to reclaim space
    public func vacuum() throws {
        try dbQueue.vacuum()
    }

    /// Get database size in bytes
    public func databaseSize() -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: databasePath),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }
}

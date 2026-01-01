import Foundation
import GRDB

/// Aggregated statistics for a single minute
public struct MinuteStat: Codable, Identifiable {
    public var id: Int64?
    public var timestamp: Int64  // Unix timestamp (minute boundary)
    public var appId: Int64

    // Input metrics
    public var keystrokes: Int
    public var clicks: Int
    public var scrollDistance: Int
    public var mouseDistance: Int

    // Time metrics
    public var activeSeconds: Int
    public var idleSeconds: Int

    public init(
        id: Int64? = nil,
        timestamp: Int64,
        appId: Int64,
        keystrokes: Int = 0,
        clicks: Int = 0,
        scrollDistance: Int = 0,
        mouseDistance: Int = 0,
        activeSeconds: Int = 0,
        idleSeconds: Int = 0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appId = appId
        self.keystrokes = keystrokes
        self.clicks = clicks
        self.scrollDistance = scrollDistance
        self.mouseDistance = mouseDistance
        self.activeSeconds = activeSeconds
        self.idleSeconds = idleSeconds
    }

    /// Timestamp as Date
    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

// MARK: - GRDB Conformance

extension MinuteStat: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "minute_stats" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let timestamp = Column(CodingKeys.timestamp)
        static let appId = Column(CodingKeys.appId)
        static let keystrokes = Column(CodingKeys.keystrokes)
        static let clicks = Column(CodingKeys.clicks)
        static let scrollDistance = Column(CodingKeys.scrollDistance)
        static let mouseDistance = Column(CodingKeys.mouseDistance)
        static let activeSeconds = Column(CodingKeys.activeSeconds)
        static let idleSeconds = Column(CodingKeys.idleSeconds)
    }
}

import Foundation
import GRDB

/// Represents a focus/deep work session
public struct FocusSession: Codable, Identifiable {
    public var id: Int64?
    public var startTime: Date
    public var endTime: Date?
    public var primaryAppId: Int64?

    // Metrics during session
    public var keystrokes: Int
    public var clicks: Int
    public var interruptions: Int

    public init(
        id: Int64? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        primaryAppId: Int64? = nil,
        keystrokes: Int = 0,
        clicks: Int = 0,
        interruptions: Int = 0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.primaryAppId = primaryAppId
        self.keystrokes = keystrokes
        self.clicks = clicks
        self.interruptions = interruptions
    }

    /// Duration in seconds
    public var durationSeconds: Int? {
        guard let end = endTime else { return nil }
        return Int(end.timeIntervalSince(startTime))
    }

    /// Formatted duration string
    public var formattedDuration: String {
        guard let seconds = durationSeconds else { return "In progress" }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    /// Check if this qualifies as a deep work session (>25 minutes)
    public var isDeepWork: Bool {
        guard let seconds = durationSeconds else { return false }
        return seconds >= 25 * 60 && interruptions < 3
    }
}

// MARK: - GRDB Conformance

extension FocusSession: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "focus_sessions" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let startTime = Column(CodingKeys.startTime)
        static let endTime = Column(CodingKeys.endTime)
        static let primaryAppId = Column(CodingKeys.primaryAppId)
        static let keystrokes = Column(CodingKeys.keystrokes)
        static let clicks = Column(CodingKeys.clicks)
        static let interruptions = Column(CodingKeys.interruptions)
    }
}

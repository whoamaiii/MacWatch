import Foundation
import GRDB

/// Raw event for ephemeral storage (deleted after 7 days)
public struct RawEvent: Codable, Identifiable {
    public var id: Int64?
    public var timestamp: Date
    public var eventType: EventType
    public var dataJson: String

    public init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        eventType: EventType,
        data: Codable
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.dataJson = (try? JSONEncoder().encode(data).base64EncodedString()) ?? "{}"
    }

    /// Decode the data payload
    public func decode<T: Decodable>(_ type: T.Type) -> T? {
        guard let data = Data(base64Encoded: dataJson) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Event Types

public enum EventType: String, Codable {
    // App events
    case appActivate
    case appDeactivate
    case appLaunch
    case appQuit

    // Window events
    case windowFocus
    case windowTitleChange

    // Input events
    case keyDown
    case keyUp
    case mouseClick
    case mouseScroll
    case mouseMove

    // System events
    case screenLock
    case screenUnlock
    case systemSleep
    case systemWake
    case displayConnect
    case displayDisconnect

    // Power events
    case batteryLevel
    case chargingStateChange
}

// MARK: - Event Data Payloads

public struct AppEventData: Codable {
    public var bundleId: String
    public var name: String
    public var pid: Int32

    public init(bundleId: String, name: String, pid: Int32) {
        self.bundleId = bundleId
        self.name = name
        self.pid = pid
    }
}

public struct WindowEventData: Codable {
    public var appBundleId: String
    public var title: String
    public var bounds: CGRect?

    public init(appBundleId: String, title: String, bounds: CGRect? = nil) {
        self.appBundleId = appBundleId
        self.title = title
        self.bounds = bounds
    }
}

public struct KeyEventData: Codable {
    public var keyCode: Int
    public var modifiers: Int

    public init(keyCode: Int, modifiers: Int) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct ClickEventData: Codable {
    public var x: Double
    public var y: Double
    public var button: Int  // 0=left, 1=right, 2=middle

    public init(x: Double, y: Double, button: Int) {
        self.x = x
        self.y = y
        self.button = button
    }
}

public struct ScrollEventData: Codable {
    public var deltaX: Int
    public var deltaY: Int

    public init(deltaX: Int, deltaY: Int) {
        self.deltaX = deltaX
        self.deltaY = deltaY
    }
}

public struct BatteryEventData: Codable {
    public var level: Int  // 0-100
    public var isCharging: Bool

    public init(level: Int, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }
}

// MARK: - GRDB Conformance

extension RawEvent: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "raw_events" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let timestamp = Column(CodingKeys.timestamp)
        static let eventType = Column(CodingKeys.eventType)
        static let dataJson = Column(CodingKeys.dataJson)
    }
}

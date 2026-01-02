import Foundation
import GRDB

/// Raw event for ephemeral storage (deleted after 7 days)
public struct RawEvent: Codable, Identifiable {
    public var id: Int64?
    public var timestamp: Date
    public var eventType: EventType
    public var dataJson: String

    /// Initialize with data payload (throws if encoding fails)
    public init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        eventType: EventType,
        data: some Encodable
    ) throws {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.dataJson = try JSONEncoder().encode(data).base64EncodedString()
    }

    /// Initialize with pre-encoded JSON (for internal use)
    public init(
        id: Int64? = nil,
        timestamp: Date = Date(),
        eventType: EventType,
        dataJson: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.dataJson = dataJson
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

    // System metrics
    case processMetrics

    // Browser events
    case browserTab
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

public struct ProcessMetricsEventData: Codable {
    public var processes: [ProcessMetric]

    public init(processes: [ProcessMetric]) {
        self.processes = processes
    }
}

public struct ProcessMetric: Codable {
    public var bundleId: String
    public var name: String
    public var pid: Int32
    public var cpuPercent: Double
    public var memoryMB: Double

    public init(bundleId: String, name: String, pid: Int32, cpuPercent: Double, memoryMB: Double) {
        self.bundleId = bundleId
        self.name = name
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
    }
}

public struct BrowserTabEventData: Codable {
    public var bundleId: String
    public var tabTitle: String

    public init(bundleId: String, tabTitle: String) {
        self.bundleId = bundleId
        self.tabTitle = tabTitle
    }
}

// MARK: - GRDB Conformance

extension RawEvent: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "raw_events" }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let timestamp = Column(CodingKeys.timestamp)
        public static let eventType = Column(CodingKeys.eventType)
        public static let dataJson = Column(CodingKeys.dataJson)
    }
}

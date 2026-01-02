import Foundation

/// Shared tracking settings accessible by both the app and daemon
public final class TrackingSettings: ObservableObject {
    public static let shared = TrackingSettings()

    private static let sharedDefaultsSuiteName = "com.clarity.shared"
    private let defaults = UserDefaults(suiteName: TrackingSettings.sharedDefaultsSuiteName) ?? .standard
    private let legacyDefaults = UserDefaults.standard

    // Distributed notification for cross-process settings sync
    public static let settingsChangedNotification = Notification.Name("com.clarity.settingsChanged")

    // Keys
    private enum Keys {
        static let windowTracking = "windowTrackingEnabled"
        static let inputTracking = "inputTrackingEnabled"
        static let systemTracking = "systemTrackingEnabled"
        static let retentionDays = "retentionDays"
    }

    // MARK: - Settings

    @Published public var windowTrackingEnabled: Bool {
        didSet {
            defaults.set(windowTrackingEnabled, forKey: Keys.windowTracking)
            defaults.synchronize()  // Ensure cross-process visibility
            notifyChange()
        }
    }

    @Published public var inputTrackingEnabled: Bool {
        didSet {
            defaults.set(inputTrackingEnabled, forKey: Keys.inputTracking)
            defaults.synchronize()  // Ensure cross-process visibility
            notifyChange()
        }
    }

    @Published public var systemTrackingEnabled: Bool {
        didSet {
            defaults.set(systemTrackingEnabled, forKey: Keys.systemTracking)
            defaults.synchronize()  // Ensure cross-process visibility
            notifyChange()
        }
    }

    @Published public var retentionDays: Int {
        didSet {
            defaults.set(retentionDays, forKey: Keys.retentionDays)
            defaults.synchronize()  // Ensure cross-process visibility
            notifyChange()
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults(suiteName: TrackingSettings.sharedDefaultsSuiteName) ?? .standard
        let legacyDefaults = UserDefaults.standard

        // Load initial values
        self.windowTrackingEnabled = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.windowTracking,
            defaultValue: true
        )
        self.inputTrackingEnabled = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.inputTracking,
            defaultValue: true
        )
        self.systemTrackingEnabled = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.systemTracking,
            defaultValue: true
        )
        self.retentionDays = Self.loadInt(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.retentionDays,
            defaultValue: 90
        )

        // Listen for external changes (from other process via distributed notification)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: Self.settingsChangedNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Reload

    /// Reload settings from UserDefaults (call from daemon periodically)
    public func reload() {
        defaults.synchronize()  // Ensure we read latest values from disk
        let newWindow = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.windowTracking,
            defaultValue: true
        )
        let newInput = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.inputTracking,
            defaultValue: true
        )
        let newSystem = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.systemTracking,
            defaultValue: true
        )
        let newRetention = Self.loadInt(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.retentionDays,
            defaultValue: 90
        )
        applySettings(
            window: newWindow,
            input: newInput,
            system: newSystem,
            retention: newRetention
        )
    }

    @objc private func handleSettingsChange() {
        // Re-read from UserDefaults when notified by another process
        defaults.synchronize()  // Ensure we read latest values from disk
        let newWindow = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.windowTracking,
            defaultValue: true
        )
        let newInput = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.inputTracking,
            defaultValue: true
        )
        let newSystem = Self.loadBool(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.systemTracking,
            defaultValue: true
        )
        let newRetention = Self.loadInt(
            defaults: defaults,
            legacyDefaults: legacyDefaults,
            forKey: Keys.retentionDays,
            defaultValue: 90
        )

        applySettings(
            window: newWindow,
            input: newInput,
            system: newSystem,
            retention: newRetention
        )
    }

    private func notifyChange() {
        // Post distributed notification to notify other processes (app <-> daemon)
        DistributedNotificationCenter.default().postNotificationName(
            Self.settingsChangedNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private func applySettings(window: Bool, input: Bool, system: Bool, retention: Int) {
        let applyBlock = { [weak self] in
            guard let self = self else { return }
            if window != self.windowTrackingEnabled {
                self.windowTrackingEnabled = window
            }
            if input != self.inputTrackingEnabled {
                self.inputTrackingEnabled = input
            }
            if system != self.systemTrackingEnabled {
                self.systemTrackingEnabled = system
            }
            if retention != self.retentionDays {
                self.retentionDays = retention
            }
        }

        if Thread.isMainThread {
            applyBlock()
        } else {
            DispatchQueue.main.async(execute: applyBlock)
        }
    }

    private static func loadBool(
        defaults: UserDefaults,
        legacyDefaults: UserDefaults,
        forKey key: String,
        defaultValue: Bool
    ) -> Bool {
        if let value = defaults.object(forKey: key) as? Bool {
            return value
        }
        if let legacyValue = legacyDefaults.object(forKey: key) as? Bool {
            defaults.set(legacyValue, forKey: key)
            return legacyValue
        }
        return defaultValue
    }

    private static func loadInt(
        defaults: UserDefaults,
        legacyDefaults: UserDefaults,
        forKey key: String,
        defaultValue: Int
    ) -> Int {
        if let value = defaults.object(forKey: key) as? Int {
            return value
        }
        if let legacyValue = legacyDefaults.object(forKey: key) as? Int {
            defaults.set(legacyValue, forKey: key)
            return legacyValue
        }
        return defaultValue
    }
}

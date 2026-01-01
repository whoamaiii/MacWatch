import Foundation
import AppKit
import IOKit.ps
import ClarityShared

/// Collects system events and metrics
final class SystemCollector {
    private var observers: [NSObjectProtocol] = []
    private var batteryTimer: Timer?

    private var lastBatteryLevel: Int = -1
    private var lastChargingState: Bool?

    // MARK: - Lifecycle

    func start() {
        setupWorkspaceObservers()
        setupScreenObservers()
        setupBatteryMonitoring()

        print("SystemCollector started")
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        observers.removeAll()

        batteryTimer?.invalidate()
        batteryTimer = nil

        print("SystemCollector stopped")
    }

    // MARK: - Workspace Events

    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter

        // Sleep
        let sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSleep()
        }
        observers.append(sleepObserver)

        // Wake
        let wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }
        observers.append(wakeObserver)

        // Screen sleep
        let screenSleepObserver = center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenSleep()
        }
        observers.append(screenSleepObserver)

        // Screen wake
        let screenWakeObserver = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenWake()
        }
        observers.append(screenWakeObserver)

        // Space change
        let spaceObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }
        observers.append(spaceObserver)
    }

    // MARK: - Screen Lock/Unlock

    private func setupScreenObservers() {
        let center = DistributedNotificationCenter.default()

        // Screen lock
        let lockObserver = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenLock()
        }
        observers.append(lockObserver)

        // Screen unlock
        let unlockObserver = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenUnlock()
        }
        observers.append(unlockObserver)
    }

    // MARK: - Battery Monitoring

    private func setupBatteryMonitoring() {
        // Check battery every 30 seconds
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }

        // Initial check
        checkBattery()
    }

    private func checkBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            return
        }

        let level = info[kIOPSCurrentCapacityKey as String] as? Int ?? 0
        let isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false

        var shouldSave = false

        // Log significant changes
        if level != lastBatteryLevel {
            if lastBatteryLevel != -1 {
                print("Battery: \(level)%")
                shouldSave = true
            }
            lastBatteryLevel = level
        }

        if isCharging != lastChargingState {
            if lastChargingState != nil {
                print("Charging: \(isCharging ? "Yes" : "No")")
                shouldSave = true
            }
            lastChargingState = isCharging
        }

        // Save battery event on significant changes
        if shouldSave {
            let data = BatteryEventData(level: level, isCharging: isCharging)
            saveEvent(.batteryLevel, data: data)
        }
    }

    // MARK: - Event Handlers

    private func handleSleep() {
        print("System going to sleep")
        saveEvent(.systemSleep, data: SystemEventData(description: "System sleep"))
    }

    private func handleWake() {
        print("System woke up")
        saveEvent(.systemWake, data: SystemEventData(description: "System wake"))
    }

    private func handleScreenSleep() {
        print("Screen going to sleep")
        saveEvent(.systemSleep, data: SystemEventData(description: "Screen sleep"))
    }

    private func handleScreenWake() {
        print("Screen woke up")
        saveEvent(.systemWake, data: SystemEventData(description: "Screen wake"))
    }

    private func handleScreenLock() {
        print("Screen locked")
        saveEvent(.screenLock, data: SystemEventData(description: "Screen locked"))
    }

    private func handleScreenUnlock() {
        print("Screen unlocked")
        saveEvent(.screenUnlock, data: SystemEventData(description: "Screen unlocked"))
    }

    private func handleSpaceChange() {
        print("Space changed")
        // Space changes don't need to be persisted - they're high frequency
    }

    private func saveEvent<T: Codable>(_ type: EventType, data: T) {
        let event = RawEvent(eventType: type, data: data)
        DatabaseManager.shared.asyncWrite { db in
            var mutableEvent = event
            try mutableEvent.insert(db)
        }
    }
}

// MARK: - System Event Data

public struct SystemEventData: Codable {
    public var description: String

    public init(description: String) {
        self.description = description
    }
}

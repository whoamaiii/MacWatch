import Foundation
import AppKit
import IOKit.ps
import ClarityShared
import Darwin

/// Collects system events and metrics
final class SystemCollector {
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var batteryTimer: Timer?
    private var systemMetricsTimer: Timer?
    private let settings = TrackingSettings.shared

    private var lastBatteryLevel: Int = -1
    private var lastChargingState: Bool?

    // CPU tracking
    private var lastCPUTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]

    // MARK: - Lifecycle

    func start() {
        setupWorkspaceObservers()
        setupScreenObservers()
        setupBatteryMonitoring()
        setupSystemMetricsMonitoring()

        print("SystemCollector started")
    }

    func stop() {
        // Remove workspace observers from workspace notification center
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()

        // Remove distributed observers from distributed notification center
        for observer in distributedObservers {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        distributedObservers.removeAll()

        batteryTimer?.invalidate()
        batteryTimer = nil

        systemMetricsTimer?.invalidate()
        systemMetricsTimer = nil

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
        workspaceObservers.append(sleepObserver)

        // Wake
        let wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }
        workspaceObservers.append(wakeObserver)

        // Screen sleep
        let screenSleepObserver = center.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenSleep()
        }
        workspaceObservers.append(screenSleepObserver)

        // Screen wake
        let screenWakeObserver = center.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenWake()
        }
        workspaceObservers.append(screenWakeObserver)

        // Space change
        let spaceObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSpaceChange()
        }
        workspaceObservers.append(spaceObserver)
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
        distributedObservers.append(lockObserver)

        // Screen unlock
        let unlockObserver = center.addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenUnlock()
        }
        distributedObservers.append(unlockObserver)
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

    // MARK: - System Metrics Monitoring

    private func setupSystemMetricsMonitoring() {
        // Collect metrics every 60 seconds
        systemMetricsTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.collectProcessMetrics()
        }

        // Initial collection after a delay to establish baseline
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.collectProcessMetrics()
        }
    }

    private func collectProcessMetrics() {
        guard settings.systemTrackingEnabled else { return }
        var metrics: [ProcessMetric] = []
        let now = Date()

        for app in NSWorkspace.shared.runningApplications {
            guard let bundleId = app.bundleIdentifier,
                  app.activationPolicy == .regular else { continue }

            let pid = app.processIdentifier
            let name = app.localizedName ?? bundleId

            // Get memory usage
            let memoryMB = getProcessMemory(pid: pid)

            // Get CPU usage (based on delta from last sample)
            let cpuPercent = getProcessCPU(pid: pid, now: now)

            let metric = ProcessMetric(
                bundleId: bundleId,
                name: name,
                pid: pid,
                cpuPercent: cpuPercent,
                memoryMB: memoryMB
            )
            metrics.append(metric)
        }

        // Only save if we have metrics
        guard !metrics.isEmpty else { return }

        // Sort by CPU usage descending
        metrics.sort { $0.cpuPercent > $1.cpuPercent }

        let data = ProcessMetricsEventData(processes: metrics)
        saveEvent(.processMetrics, data: data)

        // Clean up stale CPU time entries for dead processes
        cleanupDeadProcesses()
    }

    private func getProcessMemory(pid: Int32) -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        var task: mach_port_t = 0
        guard task_for_pid(mach_task_self_, pid, &task) == KERN_SUCCESS else {
            return 0
        }
        defer { mach_port_deallocate(mach_task_self_, task) }

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        // Convert bytes to MB
        return Double(info.resident_size) / (1024 * 1024)
    }

    private func getProcessCPU(pid: Int32, now: Date) -> Double {
        var info = task_thread_times_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_thread_times_info>.size) / 4

        var task: mach_port_t = 0
        guard task_for_pid(mach_task_self_, pid, &task) == KERN_SUCCESS else {
            return 0
        }
        defer { mach_port_deallocate(mach_task_self_, task) }

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(task, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let userTime = UInt64(info.user_time.seconds) * 1_000_000 + UInt64(info.user_time.microseconds)
        let systemTime = UInt64(info.system_time.seconds) * 1_000_000 + UInt64(info.system_time.microseconds)

        // Calculate CPU percentage based on delta from last sample
        if let last = lastCPUTimes[pid] {
            let elapsed = now.timeIntervalSince(last.timestamp)
            guard elapsed > 0 else { return 0 }

            let userDelta = userTime > last.user ? userTime - last.user : 0
            let systemDelta = systemTime > last.system ? systemTime - last.system : 0

            // Check for overflow before adding (handles long-running processes)
            let (totalDeltaMicros, overflow) = userDelta.addingReportingOverflow(systemDelta)
            guard !overflow else {
                // Overflow detected - reset tracking for this process
                print("Warning: CPU time overflow detected for PID \(pid), resetting tracking")
                lastCPUTimes[pid] = (userTime, systemTime, now)
                return 0
            }

            let totalDelta = Double(totalDeltaMicros) / 1_000_000 // Convert to seconds

            // CPU percentage (can exceed 100% for multi-core)
            let cpuPercent = (totalDelta / elapsed) * 100

            lastCPUTimes[pid] = (userTime, systemTime, now)
            return min(cpuPercent, 800) // Cap at 800% (8 cores maxed)
        } else {
            // First sample - just record and return 0
            lastCPUTimes[pid] = (userTime, systemTime, now)
            return 0
        }
    }

    /// Clean up stale CPU time entries for dead processes
    private func cleanupDeadProcesses() {
        let staleCutoff = Date().addingTimeInterval(-300) // 5 minutes
        lastCPUTimes = lastCPUTimes.filter { _, value in
            value.timestamp > staleCutoff
        }
    }

    private func checkBattery() {
        guard settings.systemTrackingEnabled else { return }
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

    private func saveEvent<T: Encodable>(_ type: EventType, data: T) {
        guard settings.systemTrackingEnabled else { return }

        do {
            let event = try RawEvent(eventType: type, data: data)
            DatabaseManager.shared.asyncWrite { db in
                try event.insert(db)
            }
        } catch {
            // Failed to encode event data - skip saving
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

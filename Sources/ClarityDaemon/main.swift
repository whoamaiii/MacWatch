import Foundation
import ClarityShared
import AppKit

// Main entry point for the Clarity daemon
print("Clarity Daemon starting...")

// Check accessibility permissions
let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
let trusted = AXIsProcessTrustedWithOptions(options)

if !trusted {
    print("WARNING: Accessibility permission not granted. Some features will be limited.")
    print("Please grant accessibility permission in System Settings > Privacy & Security > Accessibility")
}

// Initialize daemon
let daemon = ClarityDaemon()
daemon.start()

// Keep running
print("Clarity Daemon running. Press Ctrl+C to stop.")
RunLoop.current.run()

/// Main daemon controller
final class ClarityDaemon {
    private let windowCollector = WindowCollector()
    private let inputCollector = InputCollector()
    private let systemCollector = SystemCollector()
    private let aggregator = Aggregator()

    private var isRunning = false
    private var cleanupTimer: Timer?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Start collectors
        windowCollector.start()
        inputCollector.start()
        systemCollector.start()

        // Start aggregation jobs
        aggregator.startPeriodicAggregation()

        // Schedule cleanup jobs
        scheduleCleanup()

        print("All collectors started")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        windowCollector.stop()
        inputCollector.stop()
        systemCollector.stop()
        aggregator.stop()

        cleanupTimer?.invalidate()
        cleanupTimer = nil

        print("Daemon stopped")
    }

    private func scheduleCleanup() {
        // Run cleanup daily at 3am - reschedule each time to handle DST correctly
        scheduleNextCleanup()
    }

    private func scheduleNextCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil

        let fireDate = nextCleanupTime()
        cleanupTimer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            self?.performCleanup()
            // Reschedule for next day after cleanup completes
            self?.scheduleNextCleanup()
        }
        if let timer = cleanupTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func nextCleanupTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 3
        components.minute = 0

        guard var cleanupTime = calendar.date(from: components) else {
            // Fallback: run cleanup in 1 hour
            return now.addingTimeInterval(3600)
        }
        if cleanupTime <= now {
            // Use calendar arithmetic to properly handle DST transitions
            cleanupTime = calendar.date(byAdding: .day, value: 1, to: cleanupTime) ?? now.addingTimeInterval(86400)
        }
        return cleanupTime
    }

    private func performCleanup() {
        print("Running scheduled cleanup...")
        do {
            try DatabaseManager.shared.cleanupOldEvents()
            let retentionDays = max(7, TrackingSettings.shared.retentionDays)
            try DatabaseManager.shared.cleanupOldMinuteStats(retentionDays: retentionDays)
            print("Cleanup complete")
        } catch {
            print("Cleanup error: \(error)")
        }
    }
}

/// Aggregator for rolling up data
final class Aggregator {
    private let statsRepo = StatsRepository()
    private var minuteTimer: Timer?

    func startPeriodicAggregation() {
        scheduleAlignedTimer()
    }

    func stop() {
        minuteTimer?.invalidate()
        minuteTimer = nil
    }

    private func scheduleAlignedTimer() {
        minuteTimer?.invalidate()
        minuteTimer = nil

        let now = Date()
        let calendar = Calendar.current
        let nextMinute = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? now.addingTimeInterval(60)

        let timer = Timer(
            fire: nextMinute,
            interval: 60,
            repeats: true
        ) { [weak self] _ in
            self?.aggregateLastMinute()
        }

        RunLoop.current.add(timer, forMode: .common)
        minuteTimer = timer
    }

    private func aggregateLastMinute() {
        // This is handled by the collectors directly writing to minute_stats
        // But we can do additional aggregation here if needed

        let calendar = Calendar.current
        let now = Date()

        // At the top of each hour, aggregate daily stats
        if calendar.component(.minute, from: now) == 0 {
            aggregateHourly()
        }

        // At midnight, finalize previous day
        if calendar.component(.hour, from: now) == 0 && calendar.component(.minute, from: now) == 0 {
            finalizePreviousDay()
        }
    }

    private func aggregateHourly() {
        // Could aggregate hourly summaries here
    }

    private func finalizePreviousDay() {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return
        }
        do {
            _ = try statsRepo.aggregateDaily(for: yesterday)
            print("Finalized daily stats for \(yesterday)")
        } catch {
            print("Failed to finalize daily stats: \(error)")
        }
    }
}

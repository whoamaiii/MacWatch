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

        print("Daemon stopped")
    }

    private func scheduleCleanup() {
        // Run cleanup daily at 3am
        let timer = Timer(fire: nextCleanupTime(), interval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    private func nextCleanupTime() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 3
        components.minute = 0

        var cleanupTime = calendar.date(from: components)!
        if cleanupTime < Date() {
            cleanupTime = calendar.date(byAdding: .day, value: 1, to: cleanupTime)!
        }
        return cleanupTime
    }

    private func performCleanup() {
        print("Running scheduled cleanup...")
        do {
            try DatabaseManager.shared.cleanupOldEvents()
            try DatabaseManager.shared.cleanupOldMinuteStats()
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
        // Aggregate every minute
        minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.aggregateLastMinute()
        }
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
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        do {
            _ = try statsRepo.aggregateDaily(for: yesterday)
            print("Finalized daily stats for \(yesterday)")
        } catch {
            print("Failed to finalize daily stats: \(error)")
        }
    }
}

import Foundation
import UserNotifications
import SwiftUI

/// Service for managing break reminders to promote healthy work habits
@MainActor
public final class BreakReminderService: ObservableObject {
    public static let shared = BreakReminderService()

    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "breakReminderEnabled")
            if isEnabled {
                scheduleNextReminder()
            } else {
                cancelReminders()
            }
        }
    }

    @Published public var intervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(intervalMinutes, forKey: "breakReminderInterval")
            if isEnabled {
                scheduleNextReminder()
            }
        }
    }

    @Published public var breakDurationMinutes: Int {
        didSet {
            UserDefaults.standard.set(breakDurationMinutes, forKey: "breakDuration")
        }
    }

    @Published public var lastBreakTime: Date?
    @Published public var minutesSinceBreak: Int = 0

    private var reminderTimer: Timer?
    private var trackingTimer: Timer?

    /// Lazy notification center to avoid crash when running outside of app bundle
    private var notificationCenter: UNUserNotificationCenter? {
        // Only works in proper app bundle context
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    private init() {
        // Load saved settings
        isEnabled = UserDefaults.standard.object(forKey: "breakReminderEnabled") as? Bool ?? false
        intervalMinutes = UserDefaults.standard.object(forKey: "breakReminderInterval") as? Int ?? 50
        breakDurationMinutes = UserDefaults.standard.object(forKey: "breakDuration") as? Int ?? 5

        // Request notification permissions
        requestNotificationPermissions()

        // Start tracking time since last break
        startTrackingTimer()

        // Schedule reminder if enabled
        if isEnabled {
            scheduleNextReminder()
        }
    }

    deinit {
        reminderTimer?.invalidate()
        trackingTimer?.invalidate()
    }

    // MARK: - Notification Permissions

    private func requestNotificationPermissions() {
        notificationCenter?.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Reminder Scheduling

    public func scheduleNextReminder() {
        cancelReminders()

        guard isEnabled else { return }

        // Schedule a timer-based reminder
        reminderTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendBreakReminder()
            }
        }
    }

    private func cancelReminders() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        notificationCenter?.removeAllPendingNotificationRequests()
    }

    private func sendBreakReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for a Break!"
        content.body = "You've been working for \(intervalMinutes) minutes. Take a \(breakDurationMinutes)-minute break to rest your eyes and stretch."
        content.sound = .default
        content.categoryIdentifier = "BREAK_REMINDER"

        let request = UNNotificationRequest(
            identifier: "breakReminder-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        notificationCenter?.add(request)

        // Play break reminder sound
        SoundEffectsService.shared.play(.breakReminder)
    }

    // MARK: - Break Tracking

    private func startTrackingTimer() {
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinutesSinceBreak()
            }
        }
    }

    private func updateMinutesSinceBreak() {
        if let lastBreak = lastBreakTime {
            minutesSinceBreak = Int(Date().timeIntervalSince(lastBreak) / 60)
        } else {
            minutesSinceBreak += 1
        }
    }

    public func takeBreak() {
        lastBreakTime = Date()
        minutesSinceBreak = 0

        // Reset the reminder timer
        if isEnabled {
            scheduleNextReminder()
        }
    }

    // MARK: - Break Suggestions

    public var breakSuggestion: String {
        let suggestions = [
            "Stand up and stretch for a moment",
            "Look away from the screen at something 20 feet away",
            "Take a short walk around the room",
            "Do some quick breathing exercises",
            "Get a glass of water",
            "Close your eyes and rest them for a minute",
            "Roll your shoulders and neck gently",
            "Step outside for some fresh air"
        ]
        return suggestions.randomElement() ?? suggestions[0]
    }

    public var breakProgress: Double {
        guard intervalMinutes > 0 else { return 0 }
        return min(1.0, Double(minutesSinceBreak) / Double(intervalMinutes))
    }

    public var shouldTakeBreak: Bool {
        minutesSinceBreak >= intervalMinutes
    }
}

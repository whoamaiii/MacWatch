import Foundation
import SwiftUI
import UserNotifications

/// Service for scheduling focus sessions in advance
@MainActor
public final class FocusScheduleService: ObservableObject {
    public static let shared = FocusScheduleService()

    // MARK: - Published Properties

    @Published public var scheduledSessions: [ScheduledSession] = []
    @Published public var upcomingSession: ScheduledSession?

    // MARK: - Types

    public struct ScheduledSession: Codable, Identifiable {
        public let id: UUID
        public var title: String
        public var startTime: Date
        public var durationMinutes: Int
        public var repeatPattern: RepeatPattern
        public var reminderMinutes: Int
        public var isEnabled: Bool
        public var color: String
        public var notes: String?

        public init(
            id: UUID = UUID(),
            title: String,
            startTime: Date,
            durationMinutes: Int = 25,
            repeatPattern: RepeatPattern = .none,
            reminderMinutes: Int = 5,
            isEnabled: Bool = true,
            color: String = "purple",
            notes: String? = nil
        ) {
            self.id = id
            self.title = title
            self.startTime = startTime
            self.durationMinutes = durationMinutes
            self.repeatPattern = repeatPattern
            self.reminderMinutes = reminderMinutes
            self.isEnabled = isEnabled
            self.color = color
            self.notes = notes
        }

        public var swiftUIColor: Color {
            switch color {
            case "red": return .red
            case "orange": return .orange
            case "yellow": return .yellow
            case "green": return .green
            case "blue": return .blue
            case "purple": return .purple
            case "pink": return .pink
            default: return ClarityColors.deepFocus
            }
        }

        public var formattedTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: startTime)
        }

        public var formattedDuration: String {
            if durationMinutes >= 60 {
                let hours = durationMinutes / 60
                let mins = durationMinutes % 60
                return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
            }
            return "\(durationMinutes)m"
        }

        public var nextOccurrence: Date? {
            let now = Date()
            let calendar = Calendar.current

            switch repeatPattern {
            case .none:
                return startTime > now ? startTime : nil

            case .daily:
                var date = startTime
                while date <= now {
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
                    date = nextDate
                }
                return date

            case .weekdays:
                var date = startTime
                var iterations = 0
                while date <= now || !isWeekday(date) {
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
                    date = nextDate
                    iterations += 1
                    if iterations > 400 { return nil } // Safety limit (~1 year)
                }
                return date

            case .weekly:
                var date = startTime
                while date <= now {
                    guard let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: date) else { return nil }
                    date = nextDate
                }
                return date

            case .custom(let days):
                guard !days.isEmpty else { return nil } // Prevent infinite loop with empty days
                var date = startTime
                guard let maxDate = calendar.date(byAdding: .day, value: 30, to: startTime) else { return nil }
                while date <= now || !days.contains(calendar.component(.weekday, from: date)) {
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
                    date = nextDate
                    if date > maxDate {
                        return nil // Prevent infinite loop
                    }
                }
                return date
            }
        }

        private func isWeekday(_ date: Date) -> Bool {
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekday >= 2 && weekday <= 6
        }
    }

    public enum RepeatPattern: Codable, Equatable, Hashable {
        case none
        case daily
        case weekdays
        case weekly
        case custom([Int]) // 1 = Sunday, 7 = Saturday

        var displayName: String {
            switch self {
            case .none: return "One-time"
            case .daily: return "Daily"
            case .weekdays: return "Weekdays"
            case .weekly: return "Weekly"
            case .custom: return "Custom"
            }
        }
    }

    // MARK: - Private

    private let storageKey = "scheduledFocusSessions"
    private var checkTimer: Timer?

    // MARK: - Init

    private init() {
        loadSessions()
        startCheckTimer()
        requestNotificationPermission()
    }

    // MARK: - Public Methods

    public func addSession(_ session: ScheduledSession) {
        scheduledSessions.append(session)
        saveSessions()
        scheduleNotification(for: session)
        updateUpcoming()
    }

    public func updateSession(_ session: ScheduledSession) {
        if let index = scheduledSessions.firstIndex(where: { $0.id == session.id }) {
            cancelNotification(for: scheduledSessions[index])
            scheduledSessions[index] = session
            saveSessions()
            if session.isEnabled {
                scheduleNotification(for: session)
            }
            updateUpcoming()
        }
    }

    public func deleteSession(id: UUID) {
        if let session = scheduledSessions.first(where: { $0.id == id }) {
            cancelNotification(for: session)
        }
        scheduledSessions.removeAll { $0.id == id }
        saveSessions()
        updateUpcoming()
    }

    public func toggleSession(id: UUID) {
        if let index = scheduledSessions.firstIndex(where: { $0.id == id }) {
            scheduledSessions[index].isEnabled.toggle()
            if scheduledSessions[index].isEnabled {
                scheduleNotification(for: scheduledSessions[index])
            } else {
                cancelNotification(for: scheduledSessions[index])
            }
            saveSessions()
            updateUpcoming()
        }
    }

    public func getSessionsForDate(_ date: Date) -> [ScheduledSession] {
        let calendar = Calendar.current
        return scheduledSessions.filter { session in
            guard session.isEnabled, let nextOccurrence = session.nextOccurrence else { return false }
            return calendar.isDate(nextOccurrence, inSameDayAs: date)
        }
    }

    // MARK: - Private Methods

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ScheduledSession].self, from: data) else {
            return
        }
        scheduledSessions = decoded
        updateUpcoming()
    }

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(scheduledSessions) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func updateUpcoming() {
        let now = Date()
        upcomingSession = scheduledSessions
            .filter { $0.isEnabled && $0.nextOccurrence != nil }
            .sorted { ($0.nextOccurrence ?? .distantFuture) < ($1.nextOccurrence ?? .distantFuture) }
            .first { ($0.nextOccurrence ?? .distantPast) > now }
    }

    private func startCheckTimer() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForUpcomingSessions()
            }
        }
    }

    private func checkForUpcomingSessions() {
        updateUpcoming()
    }

    private func requestNotificationPermission() {
        // Only request notification permission if running in proper app bundle
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(for session: ScheduledSession) {
        guard session.isEnabled, let nextOccurrence = session.nextOccurrence else { return }

        guard let reminderTime = Calendar.current.date(
            byAdding: .minute,
            value: -session.reminderMinutes,
            to: nextOccurrence
        ) else { return }

        guard reminderTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Focus Session Starting Soon"
        content.body = "\"\(session.title)\" begins in \(session.reminderMinutes) minutes"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "focus-session-\(session.id.uuidString)",
            content: content,
            trigger: trigger
        )

        // Only add notification if running in proper app bundle
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelNotification(for session: ScheduledSession) {
        // Only remove notification if running in proper app bundle
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["focus-session-\(session.id.uuidString)"]
        )
    }
}

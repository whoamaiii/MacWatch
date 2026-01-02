import Foundation
import UserNotifications
import AppKit
import ClarityShared

/// Service that monitors app usage and alerts when spending too much time on distracting apps
@MainActor
public final class DistractionAlertService: ObservableObject {
    public static let shared = DistractionAlertService()

    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "distractionAlertsEnabled")
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    @Published public var thresholdMinutes: Int {
        didSet {
            UserDefaults.standard.set(thresholdMinutes, forKey: "distractionThreshold")
        }
    }

    @Published public var currentDistractionApp: String?
    @Published public var currentDistractionMinutes: Int = 0
    @Published public var dailyDistractionMinutes: Int = 0

    private var monitoringTimer: Timer?
    private var lastAlertTime: Date?
    private let notificationCenter = UNUserNotificationCenter.current()
    private let dataService = DataService.shared

    // Categories considered distracting
    private let distractingCategories: Set<AppCategory> = [
        .entertainment,
        .social,
        .gaming,
        .video
    ]

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: "distractionAlertsEnabled") as? Bool ?? false
        thresholdMinutes = UserDefaults.standard.object(forKey: "distractionThreshold") as? Int ?? 30

        if isEnabled {
            startMonitoring()
        }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        stopMonitoring()

        // Check every minute
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkDistractionLevels()
            }
        }

        // Initial check
        Task {
            await checkDistractionLevels()
        }
    }

    private func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func checkDistractionLevels() async {
        // Get today's app usage
        let topApps = await dataService.getTopApps(for: Date(), limit: 20)

        // Calculate total distraction time
        var totalDistractionSeconds = 0
        var currentAppDistraction: (name: String, seconds: Int)?

        for app in topApps {
            if distractingCategories.contains(app.category) {
                totalDistractionSeconds += app.durationSeconds

                // Check if this is the current frontmost app
                if let frontApp = NSWorkspace.shared.frontmostApplication,
                   frontApp.localizedName == app.name {
                    currentAppDistraction = (app.name, app.durationSeconds)
                }
            }
        }

        dailyDistractionMinutes = totalDistractionSeconds / 60

        // Update current distraction tracking
        if let current = currentAppDistraction {
            currentDistractionApp = current.name
            currentDistractionMinutes = current.seconds / 60

            // Check if we should alert
            if current.seconds / 60 >= thresholdMinutes {
                await sendDistractionAlert(appName: current.name, minutes: current.seconds / 60)
            }
        } else {
            currentDistractionApp = nil
            currentDistractionMinutes = 0
        }
    }

    private func sendDistractionAlert(appName: String, minutes: Int) async {
        // Don't alert more than once per 15 minutes for the same condition
        if let lastAlert = lastAlertTime,
           Date().timeIntervalSince(lastAlert) < 900 {
            return
        }

        lastAlertTime = Date()

        let content = UNMutableNotificationContent()
        content.title = "Distraction Alert"
        content.body = "You've spent \(minutes) minutes on \(appName) today. Consider taking a break or switching to a productive task."
        content.sound = .default
        content.categoryIdentifier = "DISTRACTION_ALERT"

        let request = UNNotificationRequest(
            identifier: "distractionAlert-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send distraction alert: \(error)")
        }
    }

    // MARK: - Helpers

    public var distractionLevel: DistractionLevel {
        if dailyDistractionMinutes < 30 {
            return .low
        } else if dailyDistractionMinutes < 60 {
            return .moderate
        } else if dailyDistractionMinutes < 120 {
            return .high
        } else {
            return .veryHigh
        }
    }

    public enum DistractionLevel: String {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case veryHigh = "Very High"

        public var color: String {
            switch self {
            case .low: return "success"
            case .moderate: return "warning"
            case .high: return "danger"
            case .veryHigh: return "danger"
            }
        }

        public var message: String {
            switch self {
            case .low:
                return "Great focus! Minimal distractions today."
            case .moderate:
                return "Some distraction time. Consider staying focused."
            case .high:
                return "High distraction time. Try to refocus on work."
            case .veryHigh:
                return "Very high distraction time. Take action to improve focus."
            }
        }
    }
}

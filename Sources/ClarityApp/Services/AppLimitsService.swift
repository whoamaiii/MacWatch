import Foundation
import UserNotifications
import SwiftUI
import ClarityShared

/// Manages daily usage limits for apps
@MainActor
public final class AppLimitsService: ObservableObject {
    public static let shared = AppLimitsService()

    /// App limit configuration
    public struct AppLimit: Codable, Identifiable {
        public var id: String { bundleId }
        public let bundleId: String
        public let appName: String
        public var dailyLimitMinutes: Int
        public var isEnabled: Bool

        public init(bundleId: String, appName: String, dailyLimitMinutes: Int, isEnabled: Bool = true) {
            self.bundleId = bundleId
            self.appName = appName
            self.dailyLimitMinutes = dailyLimitMinutes
            self.isEnabled = isEnabled
        }
    }

    /// Usage status for an app
    public struct AppUsageStatus: Identifiable {
        public var id: String { bundleId }
        public let bundleId: String
        public let appName: String
        public let usedMinutes: Int
        public let limitMinutes: Int
        public let icon: NSImage?

        public var progress: Double {
            guard limitMinutes > 0 else { return 0 }
            return min(1.0, Double(usedMinutes) / Double(limitMinutes))
        }

        public var isOverLimit: Bool {
            usedMinutes >= limitMinutes
        }

        public var isApproachingLimit: Bool {
            progress >= 0.8 && !isOverLimit
        }

        public var remainingMinutes: Int {
            max(0, limitMinutes - usedMinutes)
        }
    }

    @Published public var limits: [AppLimit] = []
    @Published public var usageStatuses: [AppUsageStatus] = []
    @Published public var showLimitReachedAlert: Bool = false
    @Published public var limitReachedApp: String = ""

    private let limitsKey = "appUsageLimits"
    private let dataService = DataService.shared
    private var monitoringTimer: Timer?

    /// Lazy notification center to avoid crash when running outside of app bundle
    private var notificationCenter: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }
    private var notifiedApps: Set<String> = []

    private init() {
        loadLimits()
        startMonitoring()
    }

    // MARK: - Limit Management

    public func addLimit(bundleId: String, appName: String, dailyMinutes: Int) {
        let limit = AppLimit(bundleId: bundleId, appName: appName, dailyLimitMinutes: dailyMinutes)
        if !limits.contains(where: { $0.bundleId == bundleId }) {
            limits.append(limit)
            saveLimits()
        }
    }

    public func updateLimit(bundleId: String, dailyMinutes: Int) {
        if let index = limits.firstIndex(where: { $0.bundleId == bundleId }) {
            limits[index].dailyLimitMinutes = dailyMinutes
            saveLimits()
        }
    }

    public func toggleLimit(bundleId: String, enabled: Bool) {
        if let index = limits.firstIndex(where: { $0.bundleId == bundleId }) {
            limits[index].isEnabled = enabled
            saveLimits()
        }
    }

    public func removeLimit(bundleId: String) {
        limits.removeAll { $0.bundleId == bundleId }
        saveLimits()
    }

    public func getLimit(for bundleId: String) -> AppLimit? {
        limits.first { $0.bundleId == bundleId }
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        // Check every minute
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkUsageLimits()
            }
        }

        // Initial check
        Task {
            await checkUsageLimits()
        }
    }

    public func checkUsageLimits() async {
        let topApps = await dataService.getTopApps(for: Date(), limit: 50)

        var statuses: [AppUsageStatus] = []

        for limit in limits where limit.isEnabled {
            let usedMinutes: Int
            if let app = topApps.first(where: { $0.bundleId == limit.bundleId }) {
                usedMinutes = app.durationSeconds / 60
            } else {
                usedMinutes = 0
            }

            let icon = getAppIcon(bundleId: limit.bundleId)

            let status = AppUsageStatus(
                bundleId: limit.bundleId,
                appName: limit.appName,
                usedMinutes: usedMinutes,
                limitMinutes: limit.dailyLimitMinutes,
                icon: icon
            )
            statuses.append(status)

            // Check if we need to send alerts
            if status.isOverLimit && !notifiedApps.contains(limit.bundleId) {
                sendLimitReachedNotification(appName: limit.appName)
                notifiedApps.insert(limit.bundleId)
                limitReachedApp = limit.appName
                showLimitReachedAlert = true
            } else if status.isApproachingLimit && !notifiedApps.contains("\(limit.bundleId)-warning") {
                sendApproachingLimitNotification(appName: limit.appName, remaining: status.remainingMinutes)
                notifiedApps.insert("\(limit.bundleId)-warning")
            }
        }

        usageStatuses = statuses.sorted { $0.progress > $1.progress }
    }

    private func sendLimitReachedNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Daily Limit Reached"
        content.body = "You've reached your daily limit for \(appName). Consider taking a break or switching to a productive task."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "limit-\(appName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter?.add(request)
        SoundEffectsService.shared.play(.breakReminder)
    }

    private func sendApproachingLimitNotification(appName: String, remaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Approaching Limit"
        content.body = "You have \(remaining) minutes left for \(appName) today."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "approaching-\(appName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        notificationCenter?.add(request)
    }

    // MARK: - Persistence

    private func loadLimits() {
        guard let data = UserDefaults.standard.data(forKey: limitsKey),
              let decoded = try? JSONDecoder().decode([AppLimit].self, from: data) else {
            return
        }
        limits = decoded
    }

    private func saveLimits() {
        if let data = try? JSONEncoder().encode(limits) {
            UserDefaults.standard.set(data, forKey: limitsKey)
        }
    }

    // MARK: - Reset

    public func resetDailyNotifications() {
        notifiedApps.removeAll()
    }

    // MARK: - Helpers

    private func getAppIcon(bundleId: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    /// Get suggested apps to limit (entertainment/social apps)
    public func getSuggestedAppsToLimit() async -> [DataService.AppUsageDisplay] {
        let topApps = await dataService.getTopApps(for: Date(), limit: 20)
        let distractingCategories: Set<AppCategory> = [.entertainment, .social, .gaming]

        return topApps.filter { distractingCategories.contains($0.category) }
    }
}

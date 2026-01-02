import Foundation
import SwiftUI
import ClarityShared

/// Service for managing app groups for combined tracking
@MainActor
public final class AppGroupService: ObservableObject {
    public static let shared = AppGroupService()

    // MARK: - Published Properties

    @Published public var groups: [AppGroup] = []

    // MARK: - Types

    public struct AppGroup: Codable, Identifiable {
        public let id: UUID
        public var name: String
        public var icon: String
        public var color: String
        public var bundleIds: [String]
        public var createdAt: Date

        public init(
            id: UUID = UUID(),
            name: String,
            icon: String = "folder.fill",
            color: String = "blue",
            bundleIds: [String] = [],
            createdAt: Date = Date()
        ) {
            self.id = id
            self.name = name
            self.icon = icon
            self.color = color
            self.bundleIds = bundleIds
            self.createdAt = createdAt
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
            default: return ClarityColors.accentPrimary
            }
        }
    }

    public struct GroupUsageStats: Identifiable {
        public let id: UUID
        public let group: AppGroup
        public let totalSeconds: Int
        public let appBreakdown: [(bundleId: String, name: String, seconds: Int)]

        public var formattedDuration: String {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }
    }

    // MARK: - Private

    private let storageKey = "appGroups"
    private let dataService = DataService.shared

    // MARK: - Init

    private init() {
        loadGroups()
        createDefaultGroupsIfNeeded()
    }

    // MARK: - Public Methods

    public func createGroup(name: String, icon: String, color: String, bundleIds: [String]) {
        let group = AppGroup(
            name: name,
            icon: icon,
            color: color,
            bundleIds: bundleIds
        )
        groups.append(group)
        saveGroups()
    }

    public func updateGroup(_ group: AppGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }

    public func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        saveGroups()
    }

    public func addAppToGroup(bundleId: String, groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            if !groups[index].bundleIds.contains(bundleId) {
                groups[index].bundleIds.append(bundleId)
                saveGroups()
            }
        }
    }

    public func removeAppFromGroup(bundleId: String, groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].bundleIds.removeAll { $0 == bundleId }
            saveGroups()
        }
    }

    public func getGroupForApp(bundleId: String) -> AppGroup? {
        groups.first { $0.bundleIds.contains(bundleId) }
    }

    public func getGroupUsage(for date: Date) async -> [GroupUsageStats] {
        var stats: [GroupUsageStats] = []

        for group in groups {
            var totalSeconds = 0
            var breakdown: [(String, String, Int)] = []

            for bundleId in group.bundleIds {
                let appUsage = await dataService.getAppUsage(bundleId: bundleId, for: date)
                if appUsage > 0 {
                    totalSeconds += appUsage
                    let appName = await dataService.getAppName(bundleId: bundleId) ?? bundleId
                    breakdown.append((bundleId, appName, appUsage))
                }
            }

            if totalSeconds > 0 || !group.bundleIds.isEmpty {
                stats.append(GroupUsageStats(
                    id: group.id,
                    group: group,
                    totalSeconds: totalSeconds,
                    appBreakdown: breakdown.sorted { $0.2 > $1.2 }
                ))
            }
        }

        return stats.sorted { $0.totalSeconds > $1.totalSeconds }
    }

    // MARK: - Private Methods

    private func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AppGroup].self, from: data) else {
            return
        }
        groups = decoded
    }

    private func saveGroups() {
        if let encoded = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func createDefaultGroupsIfNeeded() {
        guard groups.isEmpty else { return }

        // Create some helpful default groups
        let defaultGroups: [AppGroup] = [
            AppGroup(
                name: "Development",
                icon: "hammer.fill",
                color: "purple",
                bundleIds: [
                    "com.apple.dt.Xcode",
                    "com.microsoft.VSCode",
                    "com.todesktop.230313mzl4w4u92",  // Cursor
                    "com.apple.Terminal",
                    "com.googlecode.iterm2",
                    "com.sublimehq.Sublime-Text"
                ]
            ),
            AppGroup(
                name: "Communication",
                icon: "bubble.left.and.bubble.right.fill",
                color: "blue",
                bundleIds: [
                    "com.tinyspeck.slackmacgap",
                    "com.apple.MobileSMS",
                    "com.apple.mail",
                    "us.zoom.xos",
                    "com.microsoft.teams2"
                ]
            ),
            AppGroup(
                name: "Browsers",
                icon: "globe",
                color: "orange",
                bundleIds: [
                    "com.apple.Safari",
                    "com.google.Chrome",
                    "company.thebrowser.Browser",  // Arc
                    "org.mozilla.firefox",
                    "com.brave.Browser"
                ]
            ),
            AppGroup(
                name: "Creative",
                icon: "paintbrush.fill",
                color: "pink",
                bundleIds: [
                    "com.figma.Desktop",
                    "com.adobe.Photoshop",
                    "com.adobe.illustrator",
                    "com.sketch.Design"
                ]
            )
        ]

        groups = defaultGroups
        saveGroups()
    }
}

// MARK: - DataService Extension

extension DataService {
    func getAppUsage(bundleId: String, for date: Date) async -> Int {
        // Get usage seconds for a specific app on a specific date
        let topApps = await getTopApps(for: date, limit: 100)
        return topApps.first { $0.bundleId == bundleId }?.durationSeconds ?? 0
    }

    func getAppName(bundleId: String) async -> String? {
        let topApps = await getTopApps(for: Date(), limit: 100)
        return topApps.first { $0.bundleId == bundleId }?.name
    }
}

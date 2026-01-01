import Foundation
import GRDB

/// Represents a tracked application
public struct App: Codable, Identifiable, Hashable {
    public var id: Int64?
    public var bundleId: String
    public var name: String
    public var category: AppCategory
    public var isDistraction: Bool
    public var iconPath: String?
    public var firstSeen: Date

    public init(
        id: Int64? = nil,
        bundleId: String,
        name: String,
        category: AppCategory = .other,
        isDistraction: Bool = false,
        iconPath: String? = nil,
        firstSeen: Date = Date()
    ) {
        self.id = id
        self.bundleId = bundleId
        self.name = name
        self.category = category
        self.isDistraction = isDistraction
        self.iconPath = iconPath
        self.firstSeen = firstSeen
    }
}

// MARK: - GRDB Conformance

extension App: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String { "apps" }

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let bundleId = Column(CodingKeys.bundleId)
        static let name = Column(CodingKeys.name)
        static let category = Column(CodingKeys.category)
        static let isDistraction = Column(CodingKeys.isDistraction)
        static let iconPath = Column(CodingKeys.iconPath)
        static let firstSeen = Column(CodingKeys.firstSeen)
    }
}

// MARK: - App Category

public enum AppCategory: String, Codable, CaseIterable {
    case development
    case communication
    case productivity
    case entertainment
    case utilities
    case browsers
    case design
    case writing
    case finance
    case education
    case social
    case music
    case video
    case gaming
    case other

    /// Color for data visualization
    public var colorHex: String {
        switch self {
        case .development: return "5856D6"  // Indigo
        case .communication: return "5AC8FA" // Teal
        case .productivity: return "34C759"  // Green
        case .entertainment: return "FF9500" // Orange
        case .utilities: return "8E8E93"     // Gray
        case .browsers: return "007AFF"      // Blue
        case .design: return "FF2D55"        // Pink
        case .writing: return "AF52DE"       // Purple
        case .finance: return "30B0C7"       // Cyan
        case .education: return "FFD60A"     // Yellow
        case .social: return "FF375F"        // Red
        case .music: return "BF5AF2"         // Magenta
        case .video: return "FF6482"         // Coral
        case .gaming: return "64D2FF"        // Light Blue
        case .other: return "AEAEB2"         // Light Gray
        }
    }

    /// Determine category from bundle ID
    public static func from(bundleId: String) -> AppCategory {
        let id = bundleId.lowercased()

        // Development
        if id.contains("xcode") || id.contains("vscode") || id.contains("jetbrains") ||
           id.contains("sublime") || id.contains("atom") || id.contains("terminal") ||
           id.contains("iterm") || id.contains("github") || id.contains("tower") {
            return .development
        }

        // Communication
        if id.contains("slack") || id.contains("discord") || id.contains("zoom") ||
           id.contains("teams") || id.contains("skype") || id.contains("messages") ||
           id.contains("mail") || id.contains("telegram") || id.contains("whatsapp") {
            return .communication
        }

        // Browsers
        if id.contains("safari") || id.contains("chrome") || id.contains("firefox") ||
           id.contains("arc") || id.contains("brave") || id.contains("edge") ||
           id.contains("opera") {
            return .browsers
        }

        // Productivity
        if id.contains("notion") || id.contains("obsidian") || id.contains("notes") ||
           id.contains("reminders") || id.contains("calendar") || id.contains("todoist") ||
           id.contains("things") || id.contains("omnifocus") || id.contains("asana") {
            return .productivity
        }

        // Design
        if id.contains("figma") || id.contains("sketch") || id.contains("photoshop") ||
           id.contains("illustrator") || id.contains("affinity") || id.contains("pixelmator") {
            return .design
        }

        // Writing
        if id.contains("word") || id.contains("pages") || id.contains("docs") ||
           id.contains("ulysses") || id.contains("bear") || id.contains("ia-writer") {
            return .writing
        }

        // Entertainment
        if id.contains("netflix") || id.contains("youtube") || id.contains("twitch") ||
           id.contains("hulu") || id.contains("disney") || id.contains("primevideo") {
            return .entertainment
        }

        // Music
        if id.contains("spotify") || id.contains("music") || id.contains("soundcloud") ||
           id.contains("podcasts") || id.contains("audible") {
            return .music
        }

        // Social
        if id.contains("twitter") || id.contains("facebook") || id.contains("instagram") ||
           id.contains("tiktok") || id.contains("reddit") || id.contains("linkedin") {
            return .social
        }

        // Finance
        if id.contains("quicken") || id.contains("mint") || id.contains("excel") ||
           id.contains("numbers") || id.contains("banking") {
            return .finance
        }

        return .other
    }
}

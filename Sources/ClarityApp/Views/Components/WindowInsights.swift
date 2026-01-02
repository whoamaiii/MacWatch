import SwiftUI
import ClarityShared

/// Shows insights about window titles and what the user worked on
struct WindowInsights: View {
    @StateObject private var viewModel = WindowInsightsViewModel()
    @State private var selectedCategory: WorkCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                Text("What You Worked On")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                // Category filter
                Menu {
                    Button("All") { selectedCategory = nil }
                    Divider()
                    ForEach(WorkCategory.allCases, id: \.self) { category in
                        Button(category.rawValue) { selectedCategory = category }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedCategory?.rawValue ?? "All")
                            .font(ClarityTypography.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(ClarityColors.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding()
            } else if viewModel.insights.isEmpty {
                Text("No window activity recorded yet")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Insights list
                VStack(spacing: ClaritySpacing.sm) {
                    ForEach(filteredInsights.prefix(10)) { insight in
                        WindowInsightRow(insight: insight)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var filteredInsights: [WindowInsight] {
        if let category = selectedCategory {
            return viewModel.insights.filter { $0.category == category }
        }
        return viewModel.insights
    }
}

// MARK: - Work Category

enum WorkCategory: String, CaseIterable {
    case documents = "Documents"
    case code = "Code"
    case web = "Web"
    case communication = "Communication"
    case media = "Media"
    case other = "Other"

    var icon: String {
        switch self {
        case .documents: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .web: return "globe"
        case .communication: return "bubble.left.and.bubble.right"
        case .media: return "play.rectangle"
        case .other: return "square.grid.2x2"
        }
    }

    var color: Color {
        switch self {
        case .documents: return ClarityColors.productivity
        case .code: return ClarityColors.deepFocus
        case .web: return ClarityColors.accentPrimary
        case .communication: return ClarityColors.communication
        case .media: return ClarityColors.entertainment
        case .other: return ClarityColors.textTertiary
        }
    }
}

// MARK: - Window Insight

struct WindowInsight: Identifiable {
    let id = UUID()
    let title: String
    let appName: String
    let appIcon: NSImage?
    let duration: String
    let durationSeconds: Int
    let category: WorkCategory
    let url: String?
}

// MARK: - Insight Row

struct WindowInsightRow: View {
    let insight: WindowInsight

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // Category icon
            ZStack {
                Circle()
                    .fill(insight.category.color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: insight.category.icon)
                    .font(.system(size: 12))
                    .foregroundColor(insight.category.color)
            }

            // Title and app
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: ClaritySpacing.xs) {
                    if let icon = insight.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 12, height: 12)
                            .cornerRadius(2)
                    }

                    Text(insight.appName)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }

            Spacer()

            // Duration
            Text(insight.duration)
                .font(ClarityTypography.mono)
                .foregroundColor(ClarityColors.textSecondary)
        }
        .padding(ClaritySpacing.sm)
        .background(ClarityColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(ClarityRadius.md)
    }
}

// MARK: - View Model

@MainActor
class WindowInsightsViewModel: ObservableObject {
    @Published var insights: [WindowInsight] = []
    @Published var isLoading = true

    private let dataService = DataService.shared

    func load() async {
        isLoading = true
        defer { isLoading = false }

        // Get top apps for today
        let topApps = await dataService.getTopApps(for: Date(), limit: 15)

        var insightList: [WindowInsight] = []

        for app in topApps {
            let category = categorizeApp(bundleId: app.bundleId, appCategory: app.category)

            insightList.append(WindowInsight(
                title: app.name,
                appName: app.name,
                appIcon: app.icon,
                duration: app.duration,
                durationSeconds: app.durationSeconds,
                category: category,
                url: nil
            ))
        }

        insights = insightList
    }

    private func categorizeApp(bundleId: String, appCategory: AppCategory) -> WorkCategory {
        let bundleLower = bundleId.lowercased()

        // Code editors
        if bundleLower.contains("xcode") ||
           bundleLower.contains("vscode") ||
           bundleLower.contains("sublime") ||
           bundleLower.contains("jetbrains") ||
           bundleLower.contains("cursor") ||
           bundleLower.contains("terminal") ||
           bundleLower.contains("iterm") {
            return .code
        }

        // Communication
        if bundleLower.contains("slack") ||
           bundleLower.contains("discord") ||
           bundleLower.contains("teams") ||
           bundleLower.contains("zoom") ||
           bundleLower.contains("mail") ||
           bundleLower.contains("messages") ||
           appCategory == .communication {
            return .communication
        }

        // Documents
        if bundleLower.contains("pages") ||
           bundleLower.contains("word") ||
           bundleLower.contains("docs") ||
           bundleLower.contains("notion") ||
           bundleLower.contains("obsidian") ||
           bundleLower.contains("notes") ||
           bundleLower.contains("preview") ||
           appCategory == .productivity {
            return .documents
        }

        // Media
        if bundleLower.contains("spotify") ||
           bundleLower.contains("music") ||
           bundleLower.contains("vlc") ||
           bundleLower.contains("quicktime") ||
           appCategory == .entertainment ||
           appCategory == .gaming {
            return .media
        }

        // Web (browsers)
        if bundleLower.contains("safari") ||
           bundleLower.contains("chrome") ||
           bundleLower.contains("firefox") ||
           bundleLower.contains("brave") ||
           bundleLower.contains("arc") ||
           bundleLower.contains("edge") ||
           appCategory == .browsers {
            return .web
        }

        // Social
        if appCategory == .social {
            return .communication
        }

        return .other
    }
}

// MARK: - Preview

#Preview {
    GlassCard {
        WindowInsights()
    }
    .padding()
    .frame(width: 500)
}

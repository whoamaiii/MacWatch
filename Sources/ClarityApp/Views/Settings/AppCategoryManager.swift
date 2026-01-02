import SwiftUI
import ClarityShared

/// Allows users to customize app categories
struct AppCategoryManager: View {
    @StateObject private var viewModel = AppCategoryManagerViewModel()
    @State private var searchText = ""
    @State private var selectedApp: AppCategoryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                Text("App Categories")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ClarityColors.textTertiary)
                    TextField("Search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(ClaritySpacing.sm)
                .background(ClarityColors.backgroundSecondary)
                .cornerRadius(ClarityRadius.md)
                .frame(width: 200)
            }

            Text("Customize how apps are categorized to improve your productivity insights")
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)

            Divider()

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else {
                // App list
                ScrollView {
                    LazyVStack(spacing: ClaritySpacing.xs) {
                        ForEach(filteredApps) { app in
                            AppCategoryRow(
                                app: app,
                                isSelected: selectedApp?.id == app.id,
                                onSelect: { selectedApp = app },
                                onCategoryChange: { newCategory in
                                    viewModel.updateCategory(bundleId: app.bundleId, to: newCategory)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            // Category legend
            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                Text("Categories")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: ClaritySpacing.sm) {
                    ForEach(AppCategory.allCases, id: \.self) { category in
                        HStack(spacing: ClaritySpacing.xs) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                            Text(category.rawValue.capitalized)
                                .font(.system(size: 11))
                                .foregroundColor(ClarityColors.textSecondary)
                        }
                    }
                }
            }
            .padding(ClaritySpacing.md)
            .background(ClarityColors.backgroundSecondary.opacity(0.5))
            .cornerRadius(ClarityRadius.md)
        }
        .task {
            await viewModel.load()
        }
    }

    private var filteredApps: [AppCategoryItem] {
        if searchText.isEmpty {
            return viewModel.apps
        }
        return viewModel.apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleId.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - App Category Item

struct AppCategoryItem: Identifiable {
    let id: Int64
    let bundleId: String
    let name: String
    let icon: NSImage?
    var category: AppCategory
    let isCustomCategory: Bool
}

// MARK: - App Category Row

struct AppCategoryRow: View {
    let app: AppCategoryItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCategoryChange: (AppCategory) -> Void

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // App icon
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(app.category.color.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "app.fill")
                            .font(.system(size: 12))
                            .foregroundColor(app.category.color)
                    }
            }

            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)
                    .lineLimit(1)

                Text(app.bundleId)
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Custom badge
            if app.isCustomCategory {
                Text("Custom")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(ClarityColors.accentPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ClarityColors.accentPrimary.opacity(0.1))
                    .cornerRadius(ClarityRadius.sm)
            }

            // Category picker
            Menu {
                ForEach(AppCategory.allCases, id: \.self) { category in
                    Button {
                        onCategoryChange(category)
                    } label: {
                        HStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                            Text(category.rawValue.capitalized)
                            if category == app.category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(app.category.color)
                        .frame(width: 8, height: 8)
                    Text(app.category.rawValue.capitalized)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textSecondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ClarityColors.backgroundSecondary)
                .cornerRadius(ClarityRadius.sm)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(ClaritySpacing.sm)
        .background(isSelected ? ClarityColors.accentPrimary.opacity(0.1) : Color.clear)
        .cornerRadius(ClarityRadius.md)
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - View Model

@MainActor
class AppCategoryManagerViewModel: ObservableObject {
    @Published var apps: [AppCategoryItem] = []
    @Published var isLoading = true

    private let appRepository = AppRepository()
    private let customCategoriesKey = "customAppCategories"

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allApps = try appRepository.getAll()
            let customCategories = loadCustomCategories()

            apps = allApps.map { app in
                let isCustom = customCategories[app.bundleId] != nil
                let category = customCategories[app.bundleId] ?? app.category

                return AppCategoryItem(
                    id: app.id ?? 0,
                    bundleId: app.bundleId,
                    name: app.name,
                    icon: getAppIcon(bundleId: app.bundleId),
                    category: category,
                    isCustomCategory: isCustom
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            print("Error loading apps: \(error)")
        }
    }

    func updateCategory(bundleId: String, to category: AppCategory) {
        // Update in memory
        if let index = apps.firstIndex(where: { $0.bundleId == bundleId }) {
            apps[index].category = category
        }

        // Save custom category
        var customCategories = loadCustomCategories()
        customCategories[bundleId] = category
        saveCustomCategories(customCategories)

        // Update in database
        do {
            try appRepository.updateCategory(bundleId: bundleId, category: category)
        } catch {
            print("Error updating app category: \(error)")
        }
    }

    private func loadCustomCategories() -> [String: AppCategory] {
        guard let data = UserDefaults.standard.data(forKey: customCategoriesKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded.compactMapValues { AppCategory(rawValue: $0) }
    }

    private func saveCustomCategories(_ categories: [String: AppCategory]) {
        let encoded = categories.mapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(encoded) {
            UserDefaults.standard.set(data, forKey: customCategoriesKey)
        }
    }

    private func getAppIcon(bundleId: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

// MARK: - Preview

#Preview {
    GlassCard {
        AppCategoryManager()
    }
    .padding()
    .frame(width: 600, height: 600)
}

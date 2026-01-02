import SwiftUI
import ClarityShared

/// Settings section for managing app groups
struct AppGroupsSection: View {
    @ObservedObject private var groupService = AppGroupService.shared
    @State private var showingAddGroup = false
    @State private var editingGroup: AppGroupService.AppGroup?
    @State private var groupStats: [AppGroupService.GroupUsageStats] = []

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.title2)
                    .foregroundColor(ClarityColors.accentPrimary)

                Text("App Groups")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Button {
                    showingAddGroup = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New Group")
                    }
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            Text("Group apps together to track combined usage (e.g., all development tools)")
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)

            Divider()

            // Groups list
            if groupService.groups.isEmpty {
                VStack(spacing: ClaritySpacing.md) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(ClarityColors.textTertiary)

                    Text("No app groups yet")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textSecondary)

                    Text("Create groups to track combined usage of related apps")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: ClaritySpacing.sm) {
                    ForEach(groupService.groups) { group in
                        AppGroupRow(
                            group: group,
                            stats: groupStats.first { $0.group.id == group.id },
                            onEdit: { editingGroup = group },
                            onDelete: { groupService.deleteGroup(id: group.id) }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            EditAppGroupSheet(isPresented: $showingAddGroup, group: nil)
        }
        .sheet(item: $editingGroup) { group in
            EditAppGroupSheet(
                isPresented: Binding(
                    get: { editingGroup != nil },
                    set: { if !$0 { editingGroup = nil } }
                ),
                group: group
            )
        }
        .task {
            groupStats = await groupService.getGroupUsage(for: Date())
        }
    }
}

// MARK: - App Group Row

struct AppGroupRow: View {
    let group: AppGroupService.AppGroup
    let stats: AppGroupService.GroupUsageStats?
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: ClaritySpacing.md) {
                // Group icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(group.swiftUIColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: group.icon)
                        .font(.system(size: 16))
                        .foregroundColor(group.swiftUIColor)
                }

                // Group info
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text("\(group.bundleIds.count) apps")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                Spacer()

                // Usage today
                if let stats = stats {
                    Text(stats.formattedDuration)
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textSecondary)
                }

                // Expand button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(ClarityColors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .buttonStyle(.plain)

                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(ClarityColors.danger.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(ClaritySpacing.sm)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                    if let stats = stats, !stats.appBreakdown.isEmpty {
                        ForEach(stats.appBreakdown, id: \.bundleId) { app in
                            HStack {
                                Text(app.name)
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textSecondary)

                                Spacer()

                                Text(formatDuration(app.seconds))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(ClarityColors.textTertiary)
                            }
                        }
                    } else {
                        Text("No usage recorded today")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                }
                .padding(.horizontal, ClaritySpacing.md)
                .padding(.bottom, ClaritySpacing.sm)
                .padding(.leading, 48)
            }
        }
        .background(ClarityColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(ClarityRadius.md)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Edit App Group Sheet

struct EditAppGroupSheet: View {
    @Binding var isPresented: Bool
    let group: AppGroupService.AppGroup?

    @ObservedObject private var groupService = AppGroupService.shared
    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColor: String = "blue"
    @State private var selectedBundleIds: Set<String> = []
    @State private var availableApps: [DataService.AppUsageDisplay] = []
    @State private var isLoading = true

    private let icons = [
        "folder.fill", "hammer.fill", "globe", "bubble.left.and.bubble.right.fill",
        "paintbrush.fill", "doc.text.fill", "play.rectangle.fill", "gamecontroller.fill",
        "chart.bar.fill", "gear", "book.fill", "music.note"
    ]

    private let colors = ["red", "orange", "yellow", "green", "blue", "purple", "pink"]

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
            // Header
            HStack {
                Text(group == nil ? "New App Group" : "Edit App Group")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Name field
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Group Name")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                TextField("e.g., Development", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Icon picker
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Icon")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? colorForString(selectedColor).opacity(0.3) : ClarityColors.backgroundSecondary)
                                    .frame(width: 40, height: 40)

                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(selectedIcon == icon ? colorForString(selectedColor) : ClarityColors.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color picker
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Color")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(colorForString(color))
                                    .frame(width: 28, height: 28)

                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Apps picker
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                HStack {
                    Text("Apps in Group")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)

                    Spacer()

                    Text("\(selectedBundleIds.count) selected")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(availableApps) { app in
                                HStack(spacing: ClaritySpacing.sm) {
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .cornerRadius(4)
                                    }

                                    Text(app.name)
                                        .font(ClarityTypography.body)
                                        .foregroundColor(ClarityColors.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    if selectedBundleIds.contains(app.bundleId) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(colorForString(selectedColor))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(ClarityColors.textTertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(selectedBundleIds.contains(app.bundleId) ? colorForString(selectedColor).opacity(0.1) : Color.clear)
                                .cornerRadius(ClarityRadius.sm)
                                .onTapGesture {
                                    if selectedBundleIds.contains(app.bundleId) {
                                        selectedBundleIds.remove(app.bundleId)
                                    } else {
                                        selectedBundleIds.insert(app.bundleId)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(group == nil ? "Create Group" : "Save Changes") {
                    saveGroup()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(colorForString(selectedColor))
                .disabled(name.isEmpty)
            }
        }
        .padding(ClaritySpacing.lg)
        .frame(width: 450, height: 600)
        .background(.ultraThinMaterial)
        .onAppear {
            if let group = group {
                name = group.name
                selectedIcon = group.icon
                selectedColor = group.color
                selectedBundleIds = Set(group.bundleIds)
            }
        }
        .task {
            isLoading = true
            availableApps = await DataService.shared.getTopApps(for: Date(), limit: 50)
            isLoading = false
        }
    }

    private func colorForString(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }

    private func saveGroup() {
        if let existingGroup = group {
            var updated = existingGroup
            updated.name = name
            updated.icon = selectedIcon
            updated.color = selectedColor
            updated.bundleIds = Array(selectedBundleIds)
            groupService.updateGroup(updated)
        } else {
            groupService.createGroup(
                name: name,
                icon: selectedIcon,
                color: selectedColor,
                bundleIds: Array(selectedBundleIds)
            )
        }
    }
}

#Preview {
    GlassCard {
        AppGroupsSection()
    }
    .padding()
    .frame(width: 500)
}

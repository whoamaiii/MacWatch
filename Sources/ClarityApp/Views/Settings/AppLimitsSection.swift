import SwiftUI
import ClarityShared

/// Settings section for managing app usage limits
struct AppLimitsSection: View {
    @ObservedObject private var limitsService = AppLimitsService.shared
    @State private var showingAddLimit = false
    @State private var suggestedApps: [DataService.AppUsageDisplay] = []

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundColor(ClarityColors.warning)

                Text("App Usage Limits")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Button {
                    showingAddLimit = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add Limit")
                    }
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            Text("Set daily time limits for distracting apps and get notified when you're approaching them")
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)

            Divider()

            // Current limits
            if limitsService.limits.isEmpty {
                VStack(spacing: ClaritySpacing.md) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundColor(ClarityColors.textTertiary)

                    Text("No app limits set")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textSecondary)

                    Text("Set limits on distracting apps to improve your focus")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                VStack(spacing: ClaritySpacing.sm) {
                    ForEach(limitsService.usageStatuses) { status in
                        AppLimitRow(
                            status: status,
                            onRemove: {
                                limitsService.removeLimit(bundleId: status.bundleId)
                            },
                            onUpdateLimit: { newLimit in
                                limitsService.updateLimit(bundleId: status.bundleId, dailyMinutes: newLimit)
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddLimit) {
            AddAppLimitSheet(isPresented: $showingAddLimit)
        }
        .task {
            await limitsService.checkUsageLimits()
        }
    }
}

// MARK: - App Limit Row

struct AppLimitRow: View {
    let status: AppLimitsService.AppUsageStatus
    let onRemove: () -> Void
    let onUpdateLimit: (Int) -> Void

    @State private var isEditing = false
    @State private var editedLimit: Int

    init(status: AppLimitsService.AppUsageStatus, onRemove: @escaping () -> Void, onUpdateLimit: @escaping (Int) -> Void) {
        self.status = status
        self.onRemove = onRemove
        self.onUpdateLimit = onUpdateLimit
        self._editedLimit = State(initialValue: status.limitMinutes)
    }

    var body: some View {
        VStack(spacing: ClaritySpacing.sm) {
            HStack(spacing: ClaritySpacing.md) {
                // App icon
                if let icon = status.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ClarityColors.warning.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ClarityColors.warning)
                        }
                }

                // App name and usage
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.appName)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(ClarityColors.textPrimary)

                    HStack(spacing: ClaritySpacing.xs) {
                        Text("\(status.usedMinutes)m / \(status.limitMinutes)m")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        if status.isOverLimit {
                            Text("Over limit!")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ClarityColors.danger)
                                .cornerRadius(ClarityRadius.sm)
                        } else if status.isApproachingLimit {
                            Text("Approaching")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ClarityColors.warning)
                                .cornerRadius(ClarityRadius.sm)
                        }
                    }
                }

                Spacer()

                // Edit button
                Button {
                    isEditing.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)

                // Remove button
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ClarityColors.backgroundSecondary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressColor)
                        .frame(width: geo.size.width * status.progress)
                }
            }
            .frame(height: 4)

            // Edit controls
            if isEditing {
                HStack(spacing: ClaritySpacing.md) {
                    Text("Daily limit:")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textSecondary)

                    Stepper(
                        value: $editedLimit,
                        in: 5...480,
                        step: 5
                    ) {
                        Text("\(editedLimit) minutes")
                            .font(ClarityTypography.mono)
                            .foregroundColor(ClarityColors.textPrimary)
                    }

                    Button("Apply") {
                        onUpdateLimit(editedLimit)
                        isEditing = false
                    }
                    .font(ClarityTypography.captionMedium)
                    .buttonStyle(.borderedProminent)
                    .tint(ClarityColors.accentPrimary)
                    .controlSize(.small)
                }
                .padding(.top, ClaritySpacing.xs)
            }
        }
        .padding(ClaritySpacing.sm)
        .background(ClarityColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(ClarityRadius.md)
    }

    private var progressColor: Color {
        if status.isOverLimit {
            return ClarityColors.danger
        } else if status.isApproachingLimit {
            return ClarityColors.warning
        }
        return ClarityColors.success
    }
}

// MARK: - Add App Limit Sheet

struct AddAppLimitSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var limitsService = AppLimitsService.shared
    @State private var suggestedApps: [DataService.AppUsageDisplay] = []
    @State private var selectedBundleId: String?
    @State private var limitMinutes: Int = 30
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
            // Header
            HStack {
                Text("Add App Limit")
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

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if suggestedApps.isEmpty {
                Text("No distracting apps found. Use your computer for a while to generate suggestions.")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textTertiary)
                    .padding()
            } else {
                Text("Select an app to limit:")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                ScrollView {
                    VStack(spacing: ClaritySpacing.xs) {
                        ForEach(suggestedApps) { app in
                            HStack(spacing: ClaritySpacing.md) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 28, height: 28)
                                        .cornerRadius(6)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(ClarityTypography.bodyMedium)
                                        .foregroundColor(ClarityColors.textPrimary)

                                    Text("\(app.duration) today")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                }

                                Spacer()

                                if selectedBundleId == app.bundleId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(ClarityColors.accentPrimary)
                                }
                            }
                            .padding(ClaritySpacing.sm)
                            .background(selectedBundleId == app.bundleId ? ClarityColors.accentPrimary.opacity(0.1) : Color.clear)
                            .cornerRadius(ClarityRadius.md)
                            .onTapGesture {
                                selectedBundleId = app.bundleId
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)

                // Limit setting
                if selectedBundleId != nil {
                    Divider()

                    HStack {
                        Text("Daily limit:")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)

                        Spacer()

                        Stepper(
                            value: $limitMinutes,
                            in: 5...480,
                            step: 5
                        ) {
                            Text("\(limitMinutes) minutes")
                                .font(ClarityTypography.mono)
                                .foregroundColor(ClarityColors.accentPrimary)
                        }
                    }
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

                Button("Add Limit") {
                    if let bundleId = selectedBundleId,
                       let app = suggestedApps.first(where: { $0.bundleId == bundleId }) {
                        limitsService.addLimit(bundleId: bundleId, appName: app.name, dailyMinutes: limitMinutes)
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ClarityColors.accentPrimary)
                .disabled(selectedBundleId == nil)
            }
        }
        .padding(ClaritySpacing.lg)
        .frame(width: 400, height: 450)
        .background(.ultraThinMaterial)
        .task {
            isLoading = true
            suggestedApps = await limitsService.getSuggestedAppsToLimit()
            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    GlassCard {
        AppLimitsSection()
    }
    .padding()
    .frame(width: 500)
}

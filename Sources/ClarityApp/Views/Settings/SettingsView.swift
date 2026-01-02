import SwiftUI
import ClarityShared
import ServiceManagement

/// Settings view for configuring Clarity preferences
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Tracking Settings
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Tracking")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        Text("Control what data Clarity collects")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        trackingToggle(
                            title: "Window Tracking",
                            description: "Track active windows and app usage",
                            icon: "macwindow",
                            isOn: $viewModel.windowTrackingEnabled
                        )

                        trackingToggle(
                            title: "Input Tracking",
                            description: "Track keyboard and mouse activity",
                            icon: "keyboard",
                            isOn: $viewModel.inputTrackingEnabled
                        )

                        trackingToggle(
                            title: "System Events",
                            description: "Track sleep, wake, and screen lock events",
                            icon: "desktopcomputer",
                            isOn: $viewModel.systemTrackingEnabled
                        )
                    }
                }

                // Daily Goals
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack {
                            Image(systemName: "target")
                                .font(.title2)
                                .foregroundColor(ClarityColors.deepFocus)

                            Text("Daily Goals")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)
                        }

                        Text("Set your daily productivity targets")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        // Active Time Goal
                        goalSlider(
                            title: "Active Time Goal",
                            icon: ClarityIcons.time,
                            value: $viewModel.activeTimeGoalHours,
                            range: 1...12,
                            unit: "hours",
                            color: ClarityColors.accentPrimary
                        )

                        // Keystrokes Goal
                        goalSlider(
                            title: "Keystrokes Goal",
                            icon: ClarityIcons.keystrokes,
                            value: $viewModel.keystrokesGoal,
                            range: 1000...20000,
                            step: 500,
                            unit: "",
                            color: ClarityColors.productivity
                        )

                        // Focus Score Goal
                        goalSlider(
                            title: "Focus Score Goal",
                            icon: "target",
                            value: $viewModel.focusScoreGoal,
                            range: 50...100,
                            step: 5,
                            unit: "%",
                            color: ClarityColors.deepFocus
                        )
                    }
                }

                // Break Reminders
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title2)
                                .foregroundColor(ClarityColors.success)

                            Text("Break Reminders")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)
                        }

                        Text("Get reminded to take regular breaks")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Enable Break Reminders")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Get notified when it's time to take a break")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.breakRemindersEnabled)
                                .toggleStyle(.switch)
                                .tint(ClarityColors.success)
                        }

                        if viewModel.breakRemindersEnabled {
                            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                                HStack {
                                    Text("Remind every")
                                        .font(ClarityTypography.body)
                                        .foregroundColor(ClarityColors.textPrimary)

                                    Spacer()

                                    Text("\(viewModel.breakIntervalMinutes) minutes")
                                        .font(ClarityTypography.mono)
                                        .foregroundColor(ClarityColors.success)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.breakIntervalMinutes) },
                                        set: { viewModel.breakIntervalMinutes = Int($0) }
                                    ),
                                    in: 15...120,
                                    step: 5
                                )
                                .tint(ClarityColors.success)

                                HStack {
                                    Text("15 min")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Spacer()
                                    Text("2 hours")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                }
                            }
                            .padding(.top, ClaritySpacing.xs)

                            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                                HStack {
                                    Text("Break duration")
                                        .font(ClarityTypography.body)
                                        .foregroundColor(ClarityColors.textPrimary)

                                    Spacer()

                                    Text("\(viewModel.breakDurationMinutes) minutes")
                                        .font(ClarityTypography.mono)
                                        .foregroundColor(ClarityColors.success)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.breakDurationMinutes) },
                                        set: { viewModel.breakDurationMinutes = Int($0) }
                                    ),
                                    in: 1...15,
                                    step: 1
                                )
                                .tint(ClarityColors.success)

                                HStack {
                                    Text("1 min")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Spacer()
                                    Text("15 min")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                }
                            }
                        }
                    }
                }

                // Distraction Alerts
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .font(.title2)
                                .foregroundColor(ClarityColors.warning)

                            Text("Distraction Alerts")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)
                        }

                        Text("Get notified when spending too much time on distracting apps")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Enable Distraction Alerts")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Alert when entertainment/social apps exceed threshold")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.distractionAlertsEnabled)
                                .toggleStyle(.switch)
                                .tint(ClarityColors.warning)
                        }

                        if viewModel.distractionAlertsEnabled {
                            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                                HStack {
                                    Text("Alert after")
                                        .font(ClarityTypography.body)
                                        .foregroundColor(ClarityColors.textPrimary)

                                    Spacer()

                                    Text("\(viewModel.distractionThreshold) minutes")
                                        .font(ClarityTypography.mono)
                                        .foregroundColor(ClarityColors.warning)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(viewModel.distractionThreshold) },
                                        set: { viewModel.distractionThreshold = Int($0) }
                                    ),
                                    in: 10...120,
                                    step: 5
                                )
                                .tint(ClarityColors.warning)

                                HStack {
                                    Text("10 min")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Spacer()
                                    Text("2 hours")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                }
                            }
                            .padding(.top, ClaritySpacing.xs)

                            // Current distraction level
                            HStack(spacing: ClaritySpacing.sm) {
                                Circle()
                                    .fill(distractionLevelColor)
                                    .frame(width: 8, height: 8)

                                Text("Today: \(viewModel.dailyDistractionMinutes)m on distracting apps")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textSecondary)
                            }
                            .padding(.top, ClaritySpacing.xs)
                        }
                    }
                }

                // Data Retention
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Data Retention")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        Text("How long to keep detailed activity data")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                            HStack {
                                Text("Keep minute-level data for")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Spacer()

                                Text("\(viewModel.retentionDays) days")
                                    .font(ClarityTypography.mono)
                                    .foregroundColor(ClarityColors.accentPrimary)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(viewModel.retentionDays) },
                                    set: { viewModel.retentionDays = Int($0) }
                                ),
                                in: 7...365,
                                step: 1
                            )
                            .tint(ClarityColors.accentPrimary)

                            HStack {
                                Text("7 days")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                                Spacer()
                                Text("1 year")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }
                        }

                        Text("Daily summaries are kept indefinitely. Raw events are automatically deleted after 7 days.")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                            .padding(.top, ClaritySpacing.xs)
                    }
                }

                // Sounds
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title2)
                                .foregroundColor(ClarityColors.accentPrimary)

                            Text("Sounds")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)
                        }

                        Text("Audio feedback for events and achievements")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Enable Sound Effects")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Play sounds for achievements, sessions, and alerts")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.soundEffectsEnabled)
                                .toggleStyle(.switch)
                                .tint(ClarityColors.accentPrimary)
                        }

                        if viewModel.soundEffectsEnabled {
                            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                                HStack {
                                    Text("Volume")
                                        .font(ClarityTypography.body)
                                        .foregroundColor(ClarityColors.textPrimary)

                                    Spacer()

                                    Text("\(Int(viewModel.soundVolume * 100))%")
                                        .font(ClarityTypography.mono)
                                        .foregroundColor(ClarityColors.accentPrimary)
                                }

                                HStack(spacing: ClaritySpacing.sm) {
                                    Image(systemName: "speaker.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(ClarityColors.textTertiary)

                                    Slider(value: $viewModel.soundVolume, in: 0...1)
                                        .tint(ClarityColors.accentPrimary)

                                    Image(systemName: "speaker.wave.3.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(ClarityColors.textTertiary)
                                }

                                // Test sound button
                                Button {
                                    SoundEffectsService.shared.play(.achievementUnlocked)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                        Text("Test Sound")
                                    }
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.accentPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, ClaritySpacing.xs)
                        }
                    }
                }

                // App Limits
                GlassCard {
                    AppLimitsSection()
                }

                // App Categories
                GlassCard {
                    AppCategoryManager()
                }

                // App Groups
                GlassCard {
                    AppGroupsSection()
                }

                // Startup
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Startup")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Launch at Login")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Start Clarity automatically when you log in")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.launchAtLogin)
                                .toggleStyle(.switch)
                                .tint(ClarityColors.accentPrimary)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Show in Menu Bar")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Display Clarity widget in the menu bar")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.showInMenuBar)
                                .toggleStyle(.switch)
                                .tint(ClarityColors.accentPrimary)
                        }
                    }
                }

                // Data Export
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Data Export")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        Text("Export your activity data")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)

                        Divider()

                        HStack(spacing: ClaritySpacing.md) {
                            // Date range picker
                            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                                Text("Date Range")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)

                                Picker("", selection: $viewModel.exportRange) {
                                    ForEach(ExportRange.allCases, id: \.self) { range in
                                        Text(range.rawValue).tag(range)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 300)
                            }

                            Spacer()
                        }

                        HStack(spacing: ClaritySpacing.md) {
                            Button(action: { viewModel.exportJSON() }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text("Export JSON")
                                }
                                .font(ClarityTypography.bodyMedium)
                                .foregroundColor(.white)
                                .padding(.horizontal, ClaritySpacing.md)
                                .padding(.vertical, ClaritySpacing.sm)
                                .background(ClarityColors.accentPrimary)
                                .cornerRadius(ClarityRadius.sm)
                            }
                            .buttonStyle(.plain)

                            Button(action: { viewModel.exportCSV() }) {
                                HStack {
                                    Image(systemName: "tablecells")
                                    Text("Export CSV")
                                }
                                .font(ClarityTypography.bodyMedium)
                                .foregroundColor(ClarityColors.accentPrimary)
                                .padding(.horizontal, ClaritySpacing.md)
                                .padding(.vertical, ClaritySpacing.sm)
                                .background(ClarityColors.backgroundSecondary)
                                .cornerRadius(ClarityRadius.sm)
                            }
                            .buttonStyle(.plain)

                            if viewModel.isExporting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }

                            Spacer()
                        }

                        if let message = viewModel.exportMessage {
                            Text(message)
                                .font(ClarityTypography.caption)
                                .foregroundColor(viewModel.exportSuccess ? ClarityColors.success : ClarityColors.danger)
                        }
                    }
                }

                // Danger Zone
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Danger Zone")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.danger)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Clear All Data")
                                    .font(ClarityTypography.body)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Permanently delete all tracked activity data")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Button(action: { viewModel.showClearDataAlert = true }) {
                                Text("Clear Data")
                                    .font(ClarityTypography.bodyMedium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, ClaritySpacing.md)
                                    .padding(.vertical, ClaritySpacing.xs)
                                    .background(ClarityColors.danger)
                                    .cornerRadius(ClarityRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // About
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("About")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                Text("Clarity")
                                    .font(ClarityTypography.bodyMedium)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text("Version 1.0.0")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }

                            Spacer()

                            Text("macOS Personal Analytics")
                                .font(ClarityTypography.caption)
                                .foregroundColor(ClarityColors.textTertiary)
                        }
                    }
                }
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .alert("Clear All Data?", isPresented: $viewModel.showClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text("This will permanently delete all your tracked activity data. This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Settings")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Configure Clarity preferences")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Tracking Toggle

    private func trackingToggle(
        title: String,
        description: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ClarityColors.accentPrimary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text(title)
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textPrimary)

                Text(description)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(ClarityColors.accentPrimary)
        }
    }

    // MARK: - Distraction Level Color

    private var distractionLevelColor: Color {
        let minutes = viewModel.dailyDistractionMinutes
        if minutes < 30 {
            return ClarityColors.success
        } else if minutes < 60 {
            return ClarityColors.warning
        } else {
            return ClarityColors.danger
        }
    }

    // MARK: - Goal Slider

    private func goalSlider(
        title: String,
        icon: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Text(unit.isEmpty ? "\(value.wrappedValue.formatted())" : "\(value.wrappedValue) \(unit)")
                    .font(ClarityTypography.mono)
                    .foregroundColor(color)
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .tint(color)
        }
    }
}

// MARK: - Export Range

enum ExportRange: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case all = "All Time"

    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            return calendar.date(byAdding: .year, value: -10, to: now) ?? now
        }
    }
}

// MARK: - ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    // Use shared tracking settings
    private let trackingSettings = TrackingSettings.shared
    private var isLoadingSettings = true

    // Tracking Settings (bound to shared settings)
    var windowTrackingEnabled: Bool {
        get { trackingSettings.windowTrackingEnabled }
        set {
            objectWillChange.send()
            trackingSettings.windowTrackingEnabled = newValue
        }
    }

    var inputTrackingEnabled: Bool {
        get { trackingSettings.inputTrackingEnabled }
        set {
            objectWillChange.send()
            trackingSettings.inputTrackingEnabled = newValue
        }
    }

    var systemTrackingEnabled: Bool {
        get { trackingSettings.systemTrackingEnabled }
        set {
            objectWillChange.send()
            trackingSettings.systemTrackingEnabled = newValue
        }
    }

    var retentionDays: Int {
        get { trackingSettings.retentionDays }
        set {
            objectWillChange.send()
            trackingSettings.retentionDays = newValue
        }
    }

    // Startup
    @Published var launchAtLogin = false {
        didSet {
            guard !isLoadingSettings else { return }
            saveSettings()
        }
    }
    @Published var showInMenuBar = true {
        didSet {
            guard !isLoadingSettings else { return }
            saveSettings()
        }
    }

    // Daily Goals
    @Published var activeTimeGoalHours: Int = 6 {
        didSet {
            guard !isLoadingSettings else { return }
            UserDefaults.standard.set(activeTimeGoalHours, forKey: "activeTimeGoalHours")
        }
    }
    @Published var keystrokesGoal: Int = 5000 {
        didSet {
            guard !isLoadingSettings else { return }
            UserDefaults.standard.set(keystrokesGoal, forKey: "keystrokesGoal")
        }
    }
    @Published var focusScoreGoal: Int = 70 {
        didSet {
            guard !isLoadingSettings else { return }
            UserDefaults.standard.set(focusScoreGoal, forKey: "focusScoreGoal")
        }
    }

    // Break Reminders (bound to BreakReminderService)
    private let breakService = BreakReminderService.shared

    var breakRemindersEnabled: Bool {
        get { breakService.isEnabled }
        set {
            objectWillChange.send()
            breakService.isEnabled = newValue
        }
    }

    var breakIntervalMinutes: Int {
        get { breakService.intervalMinutes }
        set {
            objectWillChange.send()
            breakService.intervalMinutes = newValue
        }
    }

    var breakDurationMinutes: Int {
        get { breakService.breakDurationMinutes }
        set {
            objectWillChange.send()
            breakService.breakDurationMinutes = newValue
        }
    }

    // Distraction Alerts (bound to DistractionAlertService)
    private let distractionService = DistractionAlertService.shared

    var distractionAlertsEnabled: Bool {
        get { distractionService.isEnabled }
        set {
            objectWillChange.send()
            distractionService.isEnabled = newValue
        }
    }

    var distractionThreshold: Int {
        get { distractionService.thresholdMinutes }
        set {
            objectWillChange.send()
            distractionService.thresholdMinutes = newValue
        }
    }

    var dailyDistractionMinutes: Int {
        distractionService.dailyDistractionMinutes
    }

    // Sound Effects (bound to SoundEffectsService)
    private let soundService = SoundEffectsService.shared

    var soundEffectsEnabled: Bool {
        get { soundService.isEnabled }
        set {
            objectWillChange.send()
            soundService.isEnabled = newValue
        }
    }

    var soundVolume: Float {
        get { soundService.volume }
        set {
            objectWillChange.send()
            soundService.volume = newValue
        }
    }

    // Export
    @Published var exportRange: ExportRange = .week
    @Published var isExporting = false
    @Published var exportMessage: String?
    @Published var exportSuccess = false

    // Alerts
    @Published var showClearDataAlert = false

    private let statsRepository = StatsRepository()
    private let appRepository = AppRepository()

    init() {
        loadSettings()
        isLoadingSettings = false
    }

    private func loadSettings() {
        // Load non-tracking settings from UserDefaults
        let defaults = UserDefaults.standard
        showInMenuBar = defaults.object(forKey: "showInMenuBar") as? Bool ?? true

        // Load daily goals
        activeTimeGoalHours = defaults.object(forKey: "activeTimeGoalHours") as? Int ?? 6
        keystrokesGoal = defaults.object(forKey: "keystrokesGoal") as? Int ?? 5000
        focusScoreGoal = defaults.object(forKey: "focusScoreGoal") as? Int ?? 70

        // Check launch at login status
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(showInMenuBar, forKey: "showInMenuBar")

        // Update launch at login
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    func exportJSON() {
        isExporting = true
        exportMessage = nil

        Task {
            do {
                let data = try await generateExportData()
                let jsonData = try JSONEncoder().encode(data)

                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = "clarity-export-\(formatDate(Date())).json"

                if panel.runModal() == .OK, let url = panel.url {
                    try jsonData.write(to: url)
                    exportMessage = "Exported successfully to \(url.lastPathComponent)"
                    exportSuccess = true
                }
            } catch {
                exportMessage = "Export failed: \(error.localizedDescription)"
                exportSuccess = false
            }
            isExporting = false
        }
    }

    func exportCSV() {
        isExporting = true
        exportMessage = nil

        Task {
            do {
                let csvString = try await generateCSVData()

                let panel = NSSavePanel()
                panel.allowedContentTypes = [.commaSeparatedText]
                panel.nameFieldStringValue = "clarity-export-\(formatDate(Date())).csv"

                if panel.runModal() == .OK, let url = panel.url {
                    try csvString.write(to: url, atomically: true, encoding: .utf8)
                    exportMessage = "Exported successfully to \(url.lastPathComponent)"
                    exportSuccess = true
                }
            } catch {
                exportMessage = "Export failed: \(error.localizedDescription)"
                exportSuccess = false
            }
            isExporting = false
        }
    }

    func clearAllData() {
        Task {
            do {
                try DatabaseManager.shared.clearAllData()
                exportMessage = "All data cleared"
                exportSuccess = true
            } catch {
                exportMessage = "Failed to clear data: \(error.localizedDescription)"
                exportSuccess = false
            }
        }
    }

    private func generateExportData() async throws -> ExportData {
        let startDate = exportRange.startDate
        let endDate = Date()

        let minuteStats = try statsRepository.getMinuteStats(from: startDate, to: endDate)
        let apps = try appRepository.getAll()
        let dailyStats = try statsRepository.getDailyStats(from: startDate, to: endDate)

        return ExportData(
            exportedAt: Date(),
            range: ExportData.DateRange(start: startDate, end: endDate),
            apps: apps.map { ExportData.AppData(from: $0) },
            dailyStats: dailyStats.map { ExportData.DailyData(from: $0) },
            minuteStats: minuteStats.map { ExportData.MinuteData(from: $0) }
        )
    }

    private func generateCSVData() async throws -> String {
        let startDate = exportRange.startDate
        let endDate = Date()

        let minuteStats = try statsRepository.getMinuteStats(from: startDate, to: endDate)
        let apps = try appRepository.getAll()
        let appMap = Dictionary(uniqueKeysWithValues: apps.compactMap { app -> (Int64, String)? in
            guard let id = app.id else { return nil }
            return (id, app.name)
        })

        var csv = "timestamp,date,hour,app_name,keystrokes,clicks,scroll_distance,mouse_distance,active_seconds\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for stat in minuteStats {
            let date = Date(timeIntervalSince1970: TimeInterval(stat.timestamp))
            let appName = appMap[stat.appId] ?? "Unknown"
            let hour = Calendar.current.component(.hour, from: date)
            let escapedAppName = appName.replacingOccurrences(of: "\"", with: "\"\"")

            csv += "\(stat.timestamp),\(dateFormatter.string(from: date)),\(hour),\"\(escapedAppName)\",\(stat.keystrokes),\(stat.clicks),\(stat.scrollDistance),\(stat.mouseDistance),\(stat.activeSeconds)\n"
        }

        return csv
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Export Data Structures

struct ExportData: Codable {
    let exportedAt: Date
    let range: DateRange
    let apps: [AppData]
    let dailyStats: [DailyData]
    let minuteStats: [MinuteData]

    struct DateRange: Codable {
        let start: Date
        let end: Date
    }

    struct AppData: Codable {
        let bundleId: String
        let name: String
        let category: String
        let firstSeen: Date

        init(from app: ClarityShared.App) {
            self.bundleId = app.bundleId
            self.name = app.name
            self.category = app.category.rawValue
            self.firstSeen = app.firstSeen
        }
    }

    struct DailyData: Codable {
        let date: String
        let activeSeconds: Int
        let focusSeconds: Int
        let keystrokes: Int
        let clicks: Int
        let focusScore: Double

        init(from stat: DailyStat) {
            self.date = stat.date
            self.activeSeconds = stat.totalActiveSeconds
            self.focusSeconds = stat.totalFocusSeconds
            self.keystrokes = stat.totalKeystrokes
            self.clicks = stat.totalClicks
            self.focusScore = stat.focusScore
        }
    }

    struct MinuteData: Codable {
        let timestamp: Int64
        let appId: Int64
        let keystrokes: Int
        let clicks: Int
        let scrollDistance: Int
        let mouseDistance: Int
        let activeSeconds: Int

        init(from stat: MinuteStat) {
            self.timestamp = stat.timestamp
            self.appId = stat.appId
            self.keystrokes = stat.keystrokes
            self.clicks = stat.clicks
            self.scrollDistance = stat.scrollDistance
            self.mouseDistance = stat.mouseDistance
            self.activeSeconds = stat.activeSeconds
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 900, height: 800)
}

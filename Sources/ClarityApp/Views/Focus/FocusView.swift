import SwiftUI
import ClarityShared
import AppKit

/// Focus session preset durations
enum FocusPreset: String, CaseIterable, Identifiable {
    case pomodoro = "Pomodoro"
    case deepWork = "Deep Work"
    case shortBreak = "Short Break"
    case custom = "Open-ended"

    var id: String { rawValue }

    var duration: TimeInterval? {
        switch self {
        case .pomodoro: return 25 * 60  // 25 minutes
        case .deepWork: return 90 * 60  // 90 minutes
        case .shortBreak: return 5 * 60 // 5 minutes
        case .custom: return nil        // No time limit
        }
    }

    var icon: String {
        switch self {
        case .pomodoro: return "timer"
        case .deepWork: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer"
        case .custom: return "infinity"
        }
    }

    var description: String {
        switch self {
        case .pomodoro: return "25 min focused work"
        case .deepWork: return "90 min deep focus"
        case .shortBreak: return "5 min break"
        case .custom: return "No time limit"
        }
    }
}

/// Focus view showing deep work sessions and distractions
struct FocusView: View {
    @StateObject private var viewModel = FocusViewModel()
    @State private var isInFocusSession = false
    @State private var focusSessionStart: Date?
    @State private var currentSessionId: Int64?
    @State private var elapsedTime: TimeInterval = 0
    @State private var errorMessage: String?
    @State private var selectedPreset: FocusPreset = .pomodoro
    @State private var targetDuration: TimeInterval? = 25 * 60
    @State private var recentSessions: [DataService.FocusSessionDisplay] = []
    @State private var editingSessionId: Int64?
    @State private var showingNoteEditor = false

    private let statsRepository = StatsRepository()
    private let appRepository = AppRepository()
    private let dataService = DataService.shared
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Focus session control
                focusSessionControl

                // Pomodoro Timer
                GlassCard {
                    PomodoroView()
                }

                // Scheduled Sessions
                GlassCard {
                    FocusScheduleView()
                }

                // Stats overview
                statsOverview

                // Today's activity
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Today's Focus Activity")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.totalActiveSeconds == 0 {
                            Text("No activity recorded yet. Start tracking to see your focus data.")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            focusActivitySummary
                        }
                    }
                }

                // Top apps during focus
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Top Apps")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.topApps.isEmpty {
                            Text("No apps tracked yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            topAppsList
                        }
                    }
                }

                // Recent Sessions
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Recent Sessions")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if recentSessions.isEmpty {
                            Text("No focus sessions recorded yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            VStack(spacing: ClaritySpacing.sm) {
                                ForEach(recentSessions.prefix(5)) { session in
                                    SessionRow(
                                        session: session,
                                        onAddNote: {
                                            editingSessionId = session.id
                                            showingNoteEditor = true
                                        }
                                    )

                                    if session.id != recentSessions.prefix(5).last?.id {
                                        Divider()
                                            .opacity(0.5)
                                    }
                                }
                            }
                        }
                    }
                }

                // Tips
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Focus Tips")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        focusTips
                    }
                }
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .onReceive(timer) { _ in
            if isInFocusSession, let start = focusSessionStart {
                elapsedTime = Date().timeIntervalSince(start)
            }
        }
        .task {
            await viewModel.load()
            recentSessions = await dataService.getRecentFocusSessions(limit: 10)
        }
        .sheet(isPresented: $showingNoteEditor) {
            if let sessionId = editingSessionId {
                SessionNoteEditor(sessionId: sessionId, isPresented: $showingNoteEditor)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Focus")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Deep work sessions and productivity")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Focus Session Control

    private var focusSessionControl: some View {
        GlassCard {
            VStack(spacing: ClaritySpacing.md) {
                // Error banner
                if let error = errorMessage {
                    HStack(spacing: ClaritySpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ClarityColors.danger)
                        Text(error)
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.danger)
                        Spacer()
                        Button(action: { errorMessage = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12))
                                .foregroundColor(ClarityColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(ClaritySpacing.sm)
                    .background(ClarityColors.danger.opacity(0.1))
                    .cornerRadius(ClarityRadius.sm)
                }

                if isInFocusSession {
                    // Active session view with progress ring
                    activeSessionView
                } else {
                    // Preset selection
                    presetSelectionView
                }
            }
        }
    }

    private var presetSelectionView: some View {
        VStack(spacing: ClaritySpacing.md) {
            Text("Choose Focus Mode")
                .font(ClarityTypography.title2)
                .foregroundColor(ClarityColors.textPrimary)

            HStack(spacing: ClaritySpacing.sm) {
                ForEach(FocusPreset.allCases) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        action: {
                            selectedPreset = preset
                            targetDuration = preset.duration
                        }
                    )
                }
            }

            Button(action: toggleFocusSession) {
                HStack(spacing: ClaritySpacing.sm) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                    Text("Start \(selectedPreset.rawValue)")
                        .font(ClarityTypography.bodyMedium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, ClaritySpacing.xl)
                .padding(.vertical, ClaritySpacing.md)
                .background(ClarityColors.deepFocus)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var activeSessionView: some View {
        HStack(spacing: ClaritySpacing.xl) {
            // Progress ring
            FocusProgressRing(
                elapsed: elapsedTime,
                target: targetDuration,
                preset: selectedPreset
            )
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                HStack(spacing: ClaritySpacing.sm) {
                    Image(systemName: selectedPreset.icon)
                        .foregroundColor(ClarityColors.deepFocus)
                    Text(selectedPreset.rawValue)
                        .font(ClarityTypography.title3)
                        .foregroundColor(ClarityColors.textSecondary)
                }

                Text(formatElapsedTime(elapsedTime))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(ClarityColors.textPrimary)

                if let target = targetDuration {
                    let remaining = max(0, target - elapsedTime)
                    Text(remaining > 0 ? "\(formatElapsedTime(remaining)) remaining" : "Goal reached!")
                        .font(ClarityTypography.caption)
                        .foregroundColor(remaining > 0 ? ClarityColors.textTertiary : ClarityColors.success)
                }

                HStack(spacing: ClaritySpacing.xs) {
                    Circle()
                        .fill(ClarityColors.success)
                        .frame(width: 8, height: 8)
                    Text("Recording")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.success)
                }
            }

            Spacer()

            Button(action: toggleFocusSession) {
                HStack(spacing: ClaritySpacing.sm) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                    Text("End Session")
                        .font(ClarityTypography.bodyMedium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, ClaritySpacing.lg)
                .padding(.vertical, ClaritySpacing.md)
                .background(ClarityColors.danger)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleFocusSession() {
        // Clear any previous error
        errorMessage = nil

        withAnimation(.spring(response: 0.3)) {
            if isInFocusSession {
                // End focus session
                guard let sessionId = currentSessionId else { return }
                do {
                    _ = try statsRepository.endFocusSession(id: sessionId)
                    // Only update UI state after successful database operation
                    isInFocusSession = false
                    focusSessionStart = nil
                    currentSessionId = nil
                    elapsedTime = 0
                    // Play end sound
                    SoundEffectsService.shared.play(.focusSessionEnd)
                    // Reload data to show completed session
                    Task {
                        await viewModel.load()
                        recentSessions = await dataService.getRecentFocusSessions(limit: 10)
                    }
                } catch {
                    // Keep session active on error - show feedback to user
                    errorMessage = "Failed to end focus session. Please try again."
                    print("Error ending focus session: \(error)")
                }
            } else {
                // Start new focus session
                do {
                    let primaryAppId = currentFrontmostAppId()
                    let session = try statsRepository.startFocusSession(primaryAppId: primaryAppId)
                    // Only update UI state after successful database operation
                    currentSessionId = session.id
                    isInFocusSession = true
                    focusSessionStart = session.startTime
                    // Play start sound
                    SoundEffectsService.shared.play(.focusSessionStart)
                } catch {
                    // Show feedback to user on error
                    errorMessage = "Failed to start focus session. Please try again."
                    print("Error starting focus session: \(error)")
                }
            }
        }
    }

    private func formatElapsedTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func currentFrontmostAppId() -> Int64? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier,
              let name = frontApp.localizedName else {
            return nil
        }

        do {
            let app = try appRepository.findOrCreate(bundleId: bundleId, name: name)
            return app.id
        } catch {
            return nil
        }
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                title: "Focus Score",
                value: "\(viewModel.focusScore)%",
                icon: "target",
                color: ClarityColors.deepFocus
            )

            StatCard(
                title: "Active Time",
                value: viewModel.formattedActiveTime,
                icon: "brain.head.profile",
                color: ClarityColors.accentPrimary
            )

            StatCard(
                title: "Keystrokes",
                value: formatNumber(viewModel.totalKeystrokes),
                icon: ClarityIcons.keystrokes,
                color: ClarityColors.productivity
            )

            StatCard(
                title: "Apps Used",
                value: "\(viewModel.appsUsed)",
                icon: "app.badge",
                color: ClarityColors.warning
            )
        }
    }

    // MARK: - Focus Activity Summary

    private var focusActivitySummary: some View {
        VStack(spacing: ClaritySpacing.md) {
            HStack(spacing: ClaritySpacing.xl) {
                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Total Active Time")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text(viewModel.formattedActiveTime)
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Total Keystrokes")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text(formatNumber(viewModel.totalKeystrokes))
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Total Clicks")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text(formatNumber(viewModel.totalClicks))
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Top Apps List

    private var topAppsList: some View {
        VStack(spacing: ClaritySpacing.sm) {
            ForEach(viewModel.topApps) { app in
                HStack(spacing: ClaritySpacing.md) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(app.color.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(app.color)
                            }
                    }

                    Text(app.name)
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    Text(app.duration)
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textSecondary)
                }
            }
        }
    }

    // MARK: - Focus Tips

    private var focusTips: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            tipRow(icon: "brain.head.profile", text: "Take regular breaks every 25-50 minutes")
            tipRow(icon: "bell.slash", text: "Silence notifications during focus sessions")
            tipRow(icon: "clock", text: "Track your peak productivity hours")
            tipRow(icon: "target", text: "Set clear goals before each session")
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: ClaritySpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ClarityColors.deepFocus)
                .frame(width: 24)

            Text(text)
                .font(ClarityTypography.body)
                .foregroundColor(ClarityColors.textSecondary)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - ViewModel

@MainActor
class FocusViewModel: ObservableObject {
    @Published var totalActiveSeconds: Int = 0
    @Published var totalKeystrokes: Int = 0
    @Published var totalClicks: Int = 0
    @Published var focusScore: Int = 0
    @Published var appsUsed: Int = 0
    @Published var topApps: [DataService.AppUsageDisplay] = []
    @Published var isLoading = true

    private let dataService = DataService.shared

    var formattedActiveTime: String {
        let hours = totalActiveSeconds / 3600
        let minutes = (totalActiveSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let stats = await dataService.getStats(for: Date())
        totalActiveSeconds = stats.activeTimeSeconds
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks
        focusScore = stats.focusScore

        topApps = await dataService.getTopApps(for: Date(), limit: 5)
        appsUsed = await dataService.getUniqueAppCount(for: Date())
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: FocusPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ClaritySpacing.xs) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? ClarityColors.deepFocus : ClarityColors.textSecondary)

                Text(preset.rawValue)
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(isSelected ? ClarityColors.textPrimary : ClarityColors.textSecondary)

                Text(preset.description)
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ClaritySpacing.md)
            .background(isSelected ? ClarityColors.deepFocus.opacity(0.1) : ClarityColors.backgroundSecondary.opacity(0.5))
            .cornerRadius(ClarityRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: ClarityRadius.md)
                    .stroke(isSelected ? ClarityColors.deepFocus : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Focus Progress Ring

struct FocusProgressRing: View {
    let elapsed: TimeInterval
    let target: TimeInterval?
    let preset: FocusPreset

    private var progress: Double {
        guard let target = target, target > 0 else { return 0 }
        return min(1.0, elapsed / target)
    }

    private var isComplete: Bool {
        guard let target = target else { return false }
        return elapsed >= target
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ClarityColors.backgroundSecondary, lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isComplete ? ClarityColors.success : ClarityColors.deepFocus,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            // Center content
            VStack(spacing: 2) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : preset.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isComplete ? ClarityColors.success : ClarityColors.deepFocus)

                if target != nil {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(ClarityColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Recent Sessions Card

struct RecentSessionsCard: View {
    let sessions: [FocusSessionDisplay]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                Text("Recent Sessions")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                if sessions.isEmpty {
                    Text("No focus sessions recorded yet")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    VStack(spacing: ClaritySpacing.sm) {
                        ForEach(sessions) { session in
                            HStack(spacing: ClaritySpacing.md) {
                                Image(systemName: "target")
                                    .font(.system(size: 16))
                                    .foregroundColor(ClarityColors.deepFocus)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.dateString)
                                        .font(ClarityTypography.bodyMedium)
                                        .foregroundColor(ClarityColors.textPrimary)

                                    Text(session.timeRange)
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                }

                                Spacer()

                                Text(session.duration)
                                    .font(ClarityTypography.mono)
                                    .foregroundColor(ClarityColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FocusSessionDisplay: Identifiable {
    let id = UUID()
    let dateString: String
    let timeRange: String
    let duration: String
}

// MARK: - Session Row with Notes

struct SessionRow: View {
    let session: DataService.FocusSessionDisplay
    let onAddNote: () -> Void

    @ObservedObject private var notesManager = SessionNotesManager.shared

    private var sessionTags: [String] {
        notesManager.getTags(for: session.id)
    }

    private var sessionNote: String? {
        notesManager.getNote(for: session.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
            HStack(spacing: ClaritySpacing.md) {
                // Deep work badge
                ZStack {
                    Circle()
                        .fill(session.isDeepWork ? ClarityColors.success.opacity(0.15) : ClarityColors.deepFocus.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: session.isDeepWork ? "brain.head.profile" : "target")
                        .font(.system(size: 14))
                        .foregroundColor(session.isDeepWork ? ClarityColors.success : ClarityColors.deepFocus)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.dateString)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text(session.timeRange)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.duration)
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textSecondary)

                    if session.isDeepWork {
                        Text("Deep Work")
                            .font(.system(size: 10))
                            .foregroundColor(ClarityColors.success)
                    }
                }

                // Notes button
                Button(action: onAddNote) {
                    Image(systemName: sessionNote != nil || !sessionTags.isEmpty ? "note.text" : "note.text.badge.plus")
                        .font(.system(size: 14))
                        .foregroundColor(sessionNote != nil || !sessionTags.isEmpty ? ClarityColors.accentPrimary : ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Add notes and tags")
            }

            // Show tags if any
            if !sessionTags.isEmpty {
                HStack(spacing: ClaritySpacing.xs) {
                    ForEach(sessionTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ClarityColors.accentPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ClarityColors.accentPrimary.opacity(0.1))
                            .cornerRadius(ClarityRadius.sm)
                    }
                }
                .padding(.leading, 44) // Align with text
            }

            // Show note preview if any
            if let note = sessionNote, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundColor(ClarityColors.textSecondary)
                    .lineLimit(1)
                    .padding(.leading, 44) // Align with text
            }
        }
    }
}

#Preview {
    FocusView()
        .frame(width: 900, height: 800)
}

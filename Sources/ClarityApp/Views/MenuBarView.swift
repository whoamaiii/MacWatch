import SwiftUI
import ClarityShared
import AppKit

/// Menu bar dropdown view
struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @ObservedObject private var daemonManager = DaemonManager.shared
    @ObservedObject private var breakService = BreakReminderService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with streak and status
            HStack {
                Text("TODAY")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textTertiary)

                Spacer()

                // Streak indicator
                if viewModel.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(ClarityColors.warning)
                        Text("\(viewModel.currentStreak)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(ClarityColors.warning)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ClarityColors.warning.opacity(0.15))
                    .cornerRadius(8)
                }

                // Live indicator showing daemon status
                HStack(spacing: 4) {
                    Circle()
                        .fill(daemonManager.isRunning ? ClarityColors.success : ClarityColors.danger)
                        .frame(width: 6, height: 6)

                    Text(daemonManager.isRunning ? "Tracking" : "Stopped")
                        .font(ClarityTypography.caption)
                        .foregroundColor(daemonManager.isRunning ? ClarityColors.success : ClarityColors.danger)
                }
            }
            .padding(.horizontal, ClaritySpacing.md)
            .padding(.top, ClaritySpacing.md)
            .padding(.bottom, ClaritySpacing.sm)

            // Quick Stats - 2 rows for more info
            VStack(spacing: ClaritySpacing.sm) {
                HStack(spacing: ClaritySpacing.lg) {
                    QuickStatItem(
                        icon: ClarityIcons.time,
                        value: viewModel.activeTime,
                        label: "Active"
                    )

                    QuickStatItem(
                        icon: "target",
                        value: "\(viewModel.focusScore)%",
                        label: "Focus"
                    )

                    QuickStatItem(
                        icon: ClarityIcons.keystrokes,
                        value: viewModel.keystrokes.formatted,
                        label: "Keys"
                    )
                }
            }
            .padding(.horizontal, ClaritySpacing.md)
            .padding(.bottom, ClaritySpacing.sm)

            // Break reminder indicator
            if breakService.isEnabled {
                HStack(spacing: ClaritySpacing.sm) {
                    // Progress ring
                    ZStack {
                        Circle()
                            .stroke(ClarityColors.backgroundSecondary, lineWidth: 3)
                            .frame(width: 24, height: 24)

                        Circle()
                            .trim(from: 0, to: breakService.breakProgress)
                            .stroke(
                                breakService.shouldTakeBreak ? ClarityColors.warning : ClarityColors.success,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: breakService.shouldTakeBreak ? "exclamationmark" : "cup.and.saucer.fill")
                            .font(.system(size: 8))
                            .foregroundColor(breakService.shouldTakeBreak ? ClarityColors.warning : ClarityColors.success)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(breakService.shouldTakeBreak ? "Break time!" : "Next break")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(breakService.shouldTakeBreak ? ClarityColors.warning : ClarityColors.textSecondary)

                        Text(breakService.shouldTakeBreak ? breakService.breakSuggestion : "\(breakService.intervalMinutes - breakService.minutesSinceBreak)m")
                            .font(.system(size: 10))
                            .foregroundColor(ClarityColors.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if breakService.shouldTakeBreak {
                        Button {
                            breakService.takeBreak()
                        } label: {
                            Text("Done")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ClarityColors.success)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ClaritySpacing.md)
                .padding(.bottom, ClaritySpacing.sm)
            }

            Divider()

            // Current App
            HStack(spacing: ClaritySpacing.sm) {
                if let icon = viewModel.currentAppIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ClarityColors.deepFocus.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "app.fill")
                                .font(.system(size: 12))
                                .foregroundColor(ClarityColors.deepFocus)
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Current")
                        .font(.system(size: 10))
                        .foregroundColor(ClarityColors.textTertiary)

                    Text(viewModel.currentApp)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                Spacer()

                Text(viewModel.currentAppDuration)
                    .font(ClarityTypography.mono)
                    .foregroundColor(ClarityColors.textSecondary)
            }
            .padding(.horizontal, ClaritySpacing.md)
            .padding(.vertical, ClaritySpacing.sm)

            Divider()

            // Actions
            VStack(spacing: 0) {
                if daemonManager.isRunning {
                    MenuButton(
                        title: "Stop Tracking",
                        icon: "pause.fill"
                    ) {
                        daemonManager.stopDaemon()
                    }
                } else {
                    MenuButton(
                        title: "Start Tracking",
                        icon: "play.fill"
                    ) {
                        daemonManager.startDaemon()
                    }
                }

                MenuButton(
                    title: viewModel.isFocusActive ? "End Focus Session" : "Start Focus Session",
                    icon: "target"
                ) {
                    Task {
                        await viewModel.toggleFocusSession()
                    }
                }

                Divider()
                    .padding(.vertical, ClaritySpacing.xxs)

                MenuButton(
                    title: "Open Clarity",
                    icon: "rectangle.expand.vertical"
                ) {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "Clarity" || $0.identifier?.rawValue.contains("Clarity") == true }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                MenuButton(
                    title: "Preferences...",
                    icon: ClarityIcons.settings
                ) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

                Divider()
                    .padding(.vertical, ClaritySpacing.xxs)

                MenuButton(
                    title: "Quit Clarity",
                    icon: "power"
                ) {
                    daemonManager.stopDaemon()
                    NSApp.terminate(nil)
                }
            }
            .padding(.vertical, ClaritySpacing.xxs)
        }
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .task {
            viewModel.startRefreshing()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
    }
}

// MARK: - MenuBar ViewModel

@MainActor
class MenuBarViewModel: ObservableObject {
    @Published var activeTime: String = "0m"
    @Published var keystrokes: Int = 0
    @Published var clicks: Int = 0
    @Published var focusScore: Int = 0
    @Published var currentStreak: Int = 0
    @Published var currentApp: String = "No app"
    @Published var currentAppDuration: String = "0m"
    @Published var currentAppIcon: NSImage?
    @Published var isFocusActive: Bool = false
    @Published var activeFocusSessionId: Int64?

    private let dataService = DataService.shared
    private let statsRepository = StatsRepository()
    private let appRepository = AppRepository()
    private var refreshTask: Task<Void, Never>?

    init() {}

    /// Start periodic refresh - call from view's onAppear or task
    func startRefreshing() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.load()
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }

    /// Stop periodic refresh - call from view's onDisappear
    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit {
        refreshTask?.cancel()
    }

    func load() async {
        let stats = await dataService.getStats(for: Date())
        activeTime = formatActiveTime(stats.activeTimeSeconds)
        keystrokes = stats.keystrokes
        clicks = stats.clicks
        focusScore = stats.focusScore

        // Get streak
        let streak = await dataService.getStreak()
        currentStreak = streak.currentStreak

        // Get frontmost app with today's usage
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontApp.bundleIdentifier {
            currentApp = frontApp.localizedName ?? bundleId
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                currentAppIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            } else {
                currentAppIcon = nil
            }

            if let usage = await dataService.getAppUsage(bundleId: bundleId, from: startOfDay, to: Date()) {
                currentAppDuration = usage.duration
            } else {
                currentAppDuration = "0m"
            }
        } else {
            currentApp = "No activity"
            currentAppDuration = "0m"
            currentAppIcon = nil
        }

        // Check for active focus session
        do {
            if let session = try statsRepository.getActiveFocusSession() {
                isFocusActive = true
                activeFocusSessionId = session.id
            } else {
                isFocusActive = false
                activeFocusSessionId = nil
            }
        } catch {
            // Silently fail - will retry on next load
        }
    }

    func toggleFocusSession() async {
        do {
            if isFocusActive, let sessionId = activeFocusSessionId {
                // End the session - only update state after success
                _ = try statsRepository.endFocusSession(id: sessionId)
                isFocusActive = false
                activeFocusSessionId = nil
            } else {
                // Start a new session - only update state after success
                let primaryAppId = currentFrontmostAppId()
                let session = try statsRepository.startFocusSession(primaryAppId: primaryAppId)
                isFocusActive = true
                activeFocusSessionId = session.id
            }
        } catch {
            // Don't update UI state on error - keeps UI in sync with database
        }
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

    private func formatActiveTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Quick Stat Item

struct QuickStatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: ClaritySpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(ClarityColors.accentPrimary)

            Text(value)
                .font(ClarityTypography.mono)
                .foregroundColor(ClarityColors.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(ClarityColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Menu Button

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: ClaritySpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(ClarityColors.textSecondary)
                    .frame(width: 20)

                Text(title)
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, ClaritySpacing.md)
            .padding(.vertical, ClaritySpacing.xs)
            .background(isHovered ? ClarityColors.accentPrimary.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MenuBarView()
}

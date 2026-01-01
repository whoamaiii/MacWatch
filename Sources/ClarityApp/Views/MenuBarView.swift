import SwiftUI
import ClarityShared

/// Menu bar dropdown view
struct MenuBarView: View {
    @StateObject private var viewModel = MenuBarViewModel()
    @ObservedObject private var daemonManager = DaemonManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("TODAY")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textTertiary)

                Spacer()

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

            // Quick Stats
            HStack(spacing: ClaritySpacing.lg) {
                QuickStatItem(
                    icon: ClarityIcons.time,
                    value: viewModel.activeTime,
                    label: "Active"
                )

                QuickStatItem(
                    icon: ClarityIcons.keystrokes,
                    value: viewModel.keystrokes.formatted,
                    label: "Keys"
                )

                QuickStatItem(
                    icon: ClarityIcons.clicks,
                    value: viewModel.clicks.formatted,
                    label: "Clicks"
                )
            }
            .padding(.horizontal, ClaritySpacing.md)
            .padding(.bottom, ClaritySpacing.md)

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
                    title: "Start Focus Session",
                    icon: "target"
                ) {
                    // TODO: Navigate to focus view
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
            await viewModel.load()
        }
    }
}

// MARK: - MenuBar ViewModel

@MainActor
class MenuBarViewModel: ObservableObject {
    @Published var activeTime: String = "0m"
    @Published var keystrokes: Int = 0
    @Published var clicks: Int = 0
    @Published var currentApp: String = "No app"
    @Published var currentAppDuration: String = "0m"
    @Published var currentAppIcon: NSImage?

    private let dataService = DataService.shared
    private var refreshTimer: Timer?

    init() {
        // Refresh stats every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.load()
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func load() async {
        let stats = await dataService.getStats(for: Date())
        activeTime = formatActiveTime(stats.activeTimeSeconds)
        keystrokes = stats.keystrokes
        clicks = stats.clicks

        // Get current/top app
        let topApps = await dataService.getTopApps(for: Date(), limit: 1)
        if let topApp = topApps.first {
            currentApp = topApp.name
            currentAppDuration = topApp.duration
            currentAppIcon = topApp.icon
        } else {
            currentApp = "No activity"
            currentAppDuration = "0m"
            currentAppIcon = nil
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

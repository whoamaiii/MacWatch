import SwiftUI

/// Main app view with navigation
struct MainView: View {
    @State private var selectedView: NavigationItem = .today
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var daemonManager = DaemonManager.shared

    private var isSetupComplete: Bool {
        permissionManager.hasAccessibilityPermission && daemonManager.isRunning
    }

    var body: some View {
        Group {
            if isSetupComplete {
                NavigationSplitView {
                    Sidebar(selection: $selectedView)
                } detail: {
                    DetailView(selection: selectedView)
                }
                .navigationSplitViewStyle(.balanced)
                // Keyboard shortcuts for navigation
                .keyboardShortcut(for: .today, selection: $selectedView)
                .keyboardShortcut(for: .weekly, selection: $selectedView)
                .keyboardShortcut(for: .timeline, selection: $selectedView)
                .keyboardShortcut(for: .apps, selection: $selectedView)
                .keyboardShortcut(for: .input, selection: $selectedView)
                .keyboardShortcut(for: .focus, selection: $selectedView)
                .keyboardShortcut(for: .achievements, selection: $selectedView)
                .keyboardShortcut(for: .insights, selection: $selectedView)
                .keyboardShortcut(for: .system, selection: $selectedView)
                .keyboardShortcut(for: .settings, selection: $selectedView)
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            // Auto-start daemon if permissions are granted
            if permissionManager.hasAccessibilityPermission && !daemonManager.isRunning {
                daemonManager.startDaemon()
            }
        }
        .onChange(of: permissionManager.hasAccessibilityPermission) { _, granted in
            // Auto-start daemon when permission is granted
            if granted && !daemonManager.isRunning {
                daemonManager.startDaemon()
            }
        }
    }
}

// MARK: - Navigation Items

enum NavigationItem: String, CaseIterable, Identifiable {
    case today = "Today"
    case weekly = "Weekly"
    case timeline = "Timeline"
    case apps = "Apps"
    case input = "Input"
    case focus = "Focus"
    case achievements = "Achievements"
    case insights = "Insights"
    case system = "System"
    case settings = "Settings"

    var id: String { rawValue }

    /// Keyboard shortcut key for this navigation item (Cmd+number)
    var shortcutKey: KeyEquivalent? {
        switch self {
        case .today: return "1"
        case .weekly: return "2"
        case .timeline: return "3"
        case .apps: return "4"
        case .input: return "5"
        case .focus: return "6"
        case .achievements: return "7"
        case .insights: return "8"
        case .system: return "9"
        case .settings: return ","  // Standard macOS settings shortcut
        }
    }

    var icon: String {
        switch self {
        case .today: return ClarityIcons.dashboard
        case .weekly: return "calendar.badge.clock"
        case .timeline: return ClarityIcons.timeline
        case .apps: return ClarityIcons.apps
        case .input: return ClarityIcons.input
        case .focus: return ClarityIcons.focus
        case .achievements: return "trophy.fill"
        case .insights: return ClarityIcons.insights
        case .system: return ClarityIcons.system
        case .settings: return ClarityIcons.settings
        }
    }

    var color: Color {
        switch self {
        case .today: return ClarityColors.accentPrimary
        case .weekly: return ClarityColors.communication
        case .timeline: return ClarityColors.focusIndigo
        case .apps: return ClarityColors.success
        case .input: return ClarityColors.warning
        case .focus: return ClarityColors.deepFocus
        case .achievements: return ClarityColors.warning
        case .insights: return ClarityColors.entertainment
        case .system: return ClarityColors.textTertiary
        case .settings: return ClarityColors.textSecondary
        }
    }
}

// MARK: - Sidebar

struct Sidebar: View {
    @Binding var selection: NavigationItem
    @ObservedObject private var daemonManager = DaemonManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Navigation items
            List(selection: $selection) {
                Section {
                    ForEach(NavigationItem.allCases.prefix(6)) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }

                Section {
                    ForEach([NavigationItem.achievements, NavigationItem.insights, NavigationItem.system]) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }

                Section {
                    NavigationLink(value: NavigationItem.settings) {
                        Label("Settings", systemImage: ClarityIcons.settings)
                    }
                }
            }
            .listStyle(.sidebar)

            Spacer()

            // Live indicator showing actual daemon status
            HStack(spacing: ClaritySpacing.xs) {
                Circle()
                    .fill(daemonManager.isRunning ? ClarityColors.success : ClarityColors.danger)
                    .frame(width: 8, height: 8)
                    .overlay {
                        if daemonManager.isRunning {
                            Circle()
                                .stroke(ClarityColors.success.opacity(0.5), lineWidth: 2)
                                .scaleEffect(1.5)
                                .opacity(0.5)
                        }
                    }
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: daemonManager.isRunning)

                Text(daemonManager.isRunning ? "Tracking" : "Stopped")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(daemonManager.isRunning ? ClarityColors.success : ClarityColors.danger)

                if !daemonManager.isRunning {
                    Button {
                        daemonManager.startDaemon()
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(ClarityColors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .frame(minWidth: ClaritySpacing.sidebarWidth)
    }
}

// MARK: - Detail View

struct DetailView: View {
    let selection: NavigationItem
    @State private var animationTrigger = false

    var body: some View {
        Group {
            switch selection {
            case .today:
                DashboardView()
            case .weekly:
                WeeklyDetailView()
            case .timeline:
                TimelineDetailView()
            case .apps:
                AppsDetailView()
            case .input:
                InputDetailView()
            case .focus:
                FocusDetailView()
            case .achievements:
                AchievementsDetailView()
            case .insights:
                InsightsDetailView()
            case .system:
                SystemDetailView()
            case .settings:
                SettingsDetailView()
            }
        }
        .opacity(animationTrigger ? 1 : 0)
        .offset(y: animationTrigger ? 0 : 10)
        .animation(.easeOut(duration: 0.2), value: animationTrigger)
        .onChange(of: selection) { _, _ in
            animationTrigger = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation {
                    animationTrigger = true
                }
            }
        }
        .onAppear {
            animationTrigger = true
        }
    }
}

// MARK: - Detail View Wrappers
// These wrap the actual views for navigation

struct WeeklyDetailView: View {
    var body: some View {
        WeeklySummaryView()
    }
}

struct TimelineDetailView: View {
    var body: some View {
        TimelineView()
    }
}

struct AppsDetailView: View {
    var body: some View {
        AppsView()
    }
}

struct InputDetailView: View {
    var body: some View {
        InputView()
    }
}

struct FocusDetailView: View {
    var body: some View {
        FocusView()
    }
}

struct AchievementsDetailView: View {
    var body: some View {
        AchievementsView()
    }
}

struct InsightsDetailView: View {
    var body: some View {
        InsightsView()
    }
}

struct SystemDetailView: View {
    var body: some View {
        SystemView()
    }
}

struct SettingsDetailView: View {
    var body: some View {
        SettingsView()
    }
}

// MARK: - Keyboard Shortcuts Extension

extension View {
    /// Add a keyboard shortcut for navigating to a specific view
    func keyboardShortcut(for item: NavigationItem, selection: Binding<NavigationItem>) -> some View {
        self.background {
            if let key = item.shortcutKey {
                Button("") {
                    selection.wrappedValue = item
                }
                .keyboardShortcut(key, modifiers: .command)
                .hidden()
            }
        }
    }
}

#Preview {
    MainView()
        .frame(width: 1200, height: 800)
}

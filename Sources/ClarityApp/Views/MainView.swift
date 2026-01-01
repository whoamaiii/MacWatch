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
    case timeline = "Timeline"
    case apps = "Apps"
    case input = "Input"
    case focus = "Focus"
    case insights = "Insights"
    case system = "System"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return ClarityIcons.dashboard
        case .timeline: return ClarityIcons.timeline
        case .apps: return ClarityIcons.apps
        case .input: return ClarityIcons.input
        case .focus: return ClarityIcons.focus
        case .insights: return ClarityIcons.insights
        case .system: return ClarityIcons.system
        }
    }

    var color: Color {
        switch self {
        case .today: return ClarityColors.accentPrimary
        case .timeline: return ClarityColors.focusIndigo
        case .apps: return ClarityColors.success
        case .input: return ClarityColors.warning
        case .focus: return ClarityColors.deepFocus
        case .insights: return ClarityColors.entertainment
        case .system: return ClarityColors.textTertiary
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
                    ForEach(NavigationItem.allCases.prefix(5)) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
                    }
                }

                Section {
                    ForEach(NavigationItem.allCases.suffix(2)) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                        }
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

    var body: some View {
        switch selection {
        case .today:
            DashboardView()
        case .timeline:
            TimelineDetailView()
        case .apps:
            AppsDetailView()
        case .input:
            InputDetailView()
        case .focus:
            FocusDetailView()
        case .insights:
            InsightsDetailView()
        case .system:
            SystemDetailView()
        }
    }
}

// MARK: - Detail View Wrappers
// These wrap the actual views for navigation

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

#Preview {
    MainView()
        .frame(width: 1200, height: 800)
}

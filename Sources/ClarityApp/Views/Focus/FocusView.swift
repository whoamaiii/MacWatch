import SwiftUI
import ClarityShared

/// Focus view showing deep work sessions and distractions
struct FocusView: View {
    @StateObject private var viewModel = FocusViewModel()
    @State private var isInFocusSession = false
    @State private var focusSessionStart: Date?
    @State private var currentSessionId: Int64?
    @State private var elapsedTime: TimeInterval = 0

    private let statsRepository = StatsRepository()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Focus session control
                focusSessionControl

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
            HStack(spacing: ClaritySpacing.lg) {
                VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                    Text(isInFocusSession ? "Focus Session Active" : "Start a Focus Session")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    if isInFocusSession {
                        Text(formatElapsedTime(elapsedTime))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(ClarityColors.deepFocus)
                    } else {
                        Text("Enter deep work mode to track your focus time")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textSecondary)
                    }
                }

                Spacer()

                Button(action: toggleFocusSession) {
                    HStack(spacing: ClaritySpacing.sm) {
                        Image(systemName: isInFocusSession ? "stop.fill" : "play.fill")
                            .font(.system(size: 16))

                        Text(isInFocusSession ? "End Session" : "Start Focus")
                            .font(ClarityTypography.bodyMedium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, ClaritySpacing.lg)
                    .padding(.vertical, ClaritySpacing.md)
                    .background(isInFocusSession ? ClarityColors.danger : ClarityColors.deepFocus)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if isInFocusSession {
                    HStack(spacing: ClaritySpacing.xs) {
                        Circle()
                            .fill(ClarityColors.success)
                            .frame(width: 8, height: 8)

                        Text("Recording")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.success)
                    }
                }
            }
        }
    }

    private func toggleFocusSession() {
        withAnimation(.spring(response: 0.3)) {
            if isInFocusSession {
                // End focus session
                if let sessionId = currentSessionId {
                    do {
                        _ = try statsRepository.endFocusSession(id: sessionId)
                        print("Focus session ended: \(sessionId)")
                    } catch {
                        print("Failed to end focus session: \(error)")
                    }
                }
                isInFocusSession = false
                focusSessionStart = nil
                currentSessionId = nil
                elapsedTime = 0

                // Reload data to show completed session
                Task {
                    await viewModel.load()
                }
            } else {
                // Start new focus session
                do {
                    let session = try statsRepository.startFocusSession()
                    currentSessionId = session.id
                    isInFocusSession = true
                    focusSessionStart = session.startTime
                    print("Focus session started: \(session.id ?? 0)")
                } catch {
                    print("Failed to start focus session: \(error)")
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
        appsUsed = topApps.count
    }
}

#Preview {
    FocusView()
        .frame(width: 900, height: 800)
}

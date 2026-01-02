import SwiftUI
import ClarityShared

/// A compact floating widget showing key stats
struct MiniStatsWidget: View {
    @StateObject private var viewModel = MiniStatsViewModel()
    @ObservedObject private var breakService = BreakReminderService.shared

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Compact view (always visible)
            HStack(spacing: ClaritySpacing.sm) {
                // Active time
                StatPill(
                    icon: ClarityIcons.time,
                    value: viewModel.activeTime,
                    color: ClarityColors.accentPrimary
                )

                // Focus score
                StatPill(
                    icon: "target",
                    value: "\(viewModel.focusScore)%",
                    color: viewModel.focusScore >= 70 ? ClarityColors.success : ClarityColors.warning
                )

                // Streak (if any)
                if viewModel.streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                        Text("\(viewModel.streak)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(ClarityColors.warning)
                }

                // Expand/collapse button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ClaritySpacing.md)
            .padding(.vertical, ClaritySpacing.sm)

            // Expanded view
            if isExpanded {
                Divider()
                    .opacity(0.5)

                VStack(spacing: ClaritySpacing.sm) {
                    // Today's progress bars
                    ProgressRow(
                        label: "Active Time",
                        current: viewModel.activeTimeSeconds,
                        goal: viewModel.activeTimeGoal,
                        color: ClarityColors.accentPrimary
                    )

                    ProgressRow(
                        label: "Keystrokes",
                        current: viewModel.keystrokes,
                        goal: viewModel.keystrokesGoal,
                        color: ClarityColors.productivity
                    )

                    ProgressRow(
                        label: "Focus Score",
                        current: viewModel.focusScore,
                        goal: viewModel.focusScoreGoal,
                        color: ClarityColors.deepFocus,
                        isPercentage: true
                    )

                    Divider()
                        .opacity(0.5)

                    // Break reminder status
                    if breakService.isEnabled {
                        HStack(spacing: ClaritySpacing.sm) {
                            Image(systemName: breakService.shouldTakeBreak ? "cup.and.saucer.fill" : "clock")
                                .font(.system(size: 12))
                                .foregroundColor(breakService.shouldTakeBreak ? ClarityColors.warning : ClarityColors.textTertiary)

                            Text(breakService.shouldTakeBreak ? "Time for a break!" : "Break in \(breakService.intervalMinutes - breakService.minutesSinceBreak)m")
                                .font(.system(size: 11))
                                .foregroundColor(breakService.shouldTakeBreak ? ClarityColors.warning : ClarityColors.textSecondary)

                            Spacer()

                            if breakService.shouldTakeBreak {
                                Button("Take Break") {
                                    breakService.takeBreak()
                                }
                                .font(.system(size: 10, weight: .medium))
                                .buttonStyle(.borderedProminent)
                                .tint(ClarityColors.success)
                                .controlSize(.mini)
                            }
                        }
                    }

                    // Current app
                    if !viewModel.currentApp.isEmpty {
                        HStack(spacing: ClaritySpacing.sm) {
                            if let icon = viewModel.currentAppIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                                    .cornerRadius(4)
                            }

                            Text(viewModel.currentApp)
                                .font(.system(size: 11))
                                .foregroundColor(ClarityColors.textSecondary)
                                .lineLimit(1)

                            Spacer()

                            Text(viewModel.currentAppTime)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(ClarityColors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, ClaritySpacing.md)
                .padding(.vertical, ClaritySpacing.sm)
            }
        }
        .background(.ultraThinMaterial)
        .cornerRadius(ClarityRadius.lg)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .task {
            await viewModel.load()
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(ClarityColors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(ClarityRadius.sm)
    }
}

// MARK: - Progress Row

struct ProgressRow: View {
    let label: String
    let current: Int
    let goal: Int
    let color: Color
    var isPercentage: Bool = false

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(1.0, Double(current) / Double(goal))
    }

    private var valueText: String {
        if isPercentage {
            return "\(current)% / \(goal)%"
        } else if goal >= 3600 {
            let currentHours = current / 3600
            let currentMins = (current % 3600) / 60
            let goalHours = goal / 3600
            return "\(currentHours)h \(currentMins)m / \(goalHours)h"
        } else {
            return "\(current.formatted()) / \(goal.formatted())"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)

                Spacer()

                Text(valueText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(ClarityColors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ClarityColors.backgroundSecondary)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - ViewModel

@MainActor
class MiniStatsViewModel: ObservableObject {
    @Published var activeTime: String = "0m"
    @Published var activeTimeSeconds: Int = 0
    @Published var focusScore: Int = 0
    @Published var keystrokes: Int = 0
    @Published var streak: Int = 0
    @Published var currentApp: String = ""
    @Published var currentAppTime: String = ""
    @Published var currentAppIcon: NSImage?

    // Goals
    var activeTimeGoal: Int {
        let hours = UserDefaults.standard.object(forKey: "activeTimeGoalHours") as? Int ?? 6
        return hours * 3600
    }
    var keystrokesGoal: Int {
        UserDefaults.standard.object(forKey: "keystrokesGoal") as? Int ?? 5000
    }
    var focusScoreGoal: Int {
        UserDefaults.standard.object(forKey: "focusScoreGoal") as? Int ?? 70
    }

    private let dataService = DataService.shared
    private var refreshTimer: Timer?

    init() {
        // Refresh every 30 seconds
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
        activeTimeSeconds = stats.activeTimeSeconds
        activeTime = formatTime(stats.activeTimeSeconds)
        focusScore = stats.focusScore
        keystrokes = stats.keystrokes

        let streakData = await dataService.getStreak()
        streak = streakData.currentStreak

        // Get current app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            currentApp = frontApp.localizedName ?? ""
            if let bundleId = frontApp.bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                currentAppIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            }

            // Get today's usage for this app
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            if let bundleId = frontApp.bundleIdentifier,
               let usage = await dataService.getAppUsage(bundleId: bundleId, from: startOfDay, to: Date()) {
                currentAppTime = usage.duration
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Preview

#Preview {
    MiniStatsWidget()
        .frame(width: 280)
        .padding()
}

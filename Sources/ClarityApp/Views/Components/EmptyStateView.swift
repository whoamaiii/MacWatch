import SwiftUI

/// Reusable empty state component with contextual messaging and actions
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var secondaryMessage: String? = nil

    var body: some View {
        VStack(spacing: ClaritySpacing.lg) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(ClarityColors.textQuaternary)

            // Title
            Text(title)
                .font(ClarityTypography.title2)
                .foregroundColor(ClarityColors.textSecondary)

            // Message
            Text(message)
                .font(ClarityTypography.body)
                .foregroundColor(ClarityColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            // Action button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, ClaritySpacing.lg)
                        .padding(.vertical, ClaritySpacing.sm)
                        .background(ClarityColors.accentPrimary)
                        .cornerRadius(ClarityRadius.sm)
                }
                .buttonStyle(.plain)
            }

            // Secondary message
            if let secondaryMessage = secondaryMessage {
                Text(secondaryMessage)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textQuaternary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(ClaritySpacing.xl)
    }
}

// MARK: - Preset Empty States

extension EmptyStateView {
    /// Empty state for when tracking hasn't started
    static func noTracking(onStart: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "play.circle",
            title: "Start Tracking",
            message: "Begin tracking your activity to see insights about your productivity.",
            actionTitle: "Start Daemon",
            action: onStart,
            secondaryMessage: "Data will appear within a few minutes"
        )
    }

    /// Empty state for when there's no data for the selected period
    static func noData(for period: String = "today") -> EmptyStateView {
        EmptyStateView(
            icon: "chart.bar.xaxis",
            title: "No Activity Yet",
            message: "No activity has been recorded \(period). Use your Mac normally and check back later.",
            secondaryMessage: "Data updates every minute"
        )
    }

    /// Empty state for timeline view
    static func noTimeline() -> EmptyStateView {
        EmptyStateView(
            icon: "clock.badge.questionmark",
            title: "No Timeline Data",
            message: "Your activity timeline will appear here once you start using apps.",
            secondaryMessage: "Switch between apps to see your timeline grow"
        )
    }

    /// Empty state for apps view
    static func noApps() -> EmptyStateView {
        EmptyStateView(
            icon: "square.grid.2x2",
            title: "No Apps Tracked",
            message: "Apps you use will appear here with usage statistics.",
            secondaryMessage: "Try opening some applications"
        )
    }

    /// Empty state for input view
    static func noInput() -> EmptyStateView {
        EmptyStateView(
            icon: "keyboard",
            title: "No Input Data",
            message: "Keyboard and mouse activity will be tracked and displayed here.",
            secondaryMessage: "Start typing or clicking to see your patterns"
        )
    }

    /// Empty state for focus sessions
    static func noFocusSessions() -> EmptyStateView {
        EmptyStateView(
            icon: "target",
            title: "No Focus Sessions",
            message: "Start a focus session to track deep work periods and minimize distractions.",
            secondaryMessage: "Focus sessions help you understand your productivity patterns"
        )
    }

    /// Empty state for achievements
    static func noAchievements() -> EmptyStateView {
        EmptyStateView(
            icon: "trophy",
            title: "No Achievements Yet",
            message: "Keep using Clarity to unlock achievements and track your progress.",
            secondaryMessage: "Achievements are earned through consistent usage"
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        EmptyStateView.noData()
            .frame(height: 300)
            .background(ClarityColors.backgroundSecondary)
            .cornerRadius(ClarityRadius.lg)

        EmptyStateView.noTracking(onStart: {})
            .frame(height: 300)
            .background(ClarityColors.backgroundSecondary)
            .cornerRadius(ClarityRadius.lg)
    }
    .padding()
    .frame(width: 600, height: 700)
}

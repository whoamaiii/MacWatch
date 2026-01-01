import SwiftUI
import ClarityShared

/// Onboarding view shown when permissions need to be granted
struct OnboardingView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @ObservedObject var daemonManager = DaemonManager.shared
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: ClaritySpacing.md) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ClarityColors.accentPrimary, ClarityColors.deepFocus],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, ClaritySpacing.xxl)

                Text("Welcome to Clarity")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Let's get you set up to track your productivity")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }
            .padding(.bottom, ClaritySpacing.xl)

            // Steps
            VStack(spacing: ClaritySpacing.md) {
                // Step 1: Accessibility Permission
                SetupStepCard(
                    stepNumber: 1,
                    title: "Grant Accessibility Access",
                    description: "Required to track which app you're using and your input activity",
                    isComplete: permissionManager.hasAccessibilityPermission,
                    isActive: !permissionManager.hasAccessibilityPermission,
                    action: {
                        permissionManager.requestAccessibilityPermission()
                    },
                    actionLabel: "Open System Settings"
                )

                // Step 2: Start Daemon
                SetupStepCard(
                    stepNumber: 2,
                    title: "Start Background Tracking",
                    description: "Clarity runs a lightweight daemon to collect your usage data",
                    isComplete: daemonManager.isRunning,
                    isActive: permissionManager.hasAccessibilityPermission && !daemonManager.isRunning,
                    action: {
                        daemonManager.startDaemon()
                    },
                    actionLabel: "Start Tracking"
                )

                // Step 3: Complete
                SetupStepCard(
                    stepNumber: 3,
                    title: "You're All Set!",
                    description: "Clarity is now tracking your activity. Use your Mac normally and check back for insights.",
                    isComplete: daemonManager.isRunning && permissionManager.hasAccessibilityPermission,
                    isActive: false,
                    action: nil,
                    actionLabel: nil
                )
            }
            .padding(.horizontal, ClaritySpacing.xl)

            Spacer()

            // Footer
            VStack(spacing: ClaritySpacing.sm) {
                HStack(spacing: ClaritySpacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(ClarityColors.success)
                    Text("100% local and private. Your data never leaves this device.")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textSecondary)
                }

                if daemonManager.lastError != nil {
                    HStack(spacing: ClaritySpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ClarityColors.warning)
                        Text(daemonManager.lastError ?? "")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.warning)
                    }
                }
            }
            .padding(.bottom, ClaritySpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClarityColors.backgroundPrimary)
    }
}

// MARK: - Setup Step Card

struct SetupStepCard: View {
    let stepNumber: Int
    let title: String
    let description: String
    let isComplete: Bool
    let isActive: Bool
    let action: (() -> Void)?
    let actionLabel: String?

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(isComplete ? ClarityColors.success : (isActive ? ClarityColors.accentPrimary : ClarityColors.backgroundSecondary))
                    .frame(width: 36, height: 36)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(stepNumber)")
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(isActive ? .white : ClarityColors.textTertiary)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text(title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(isComplete ? ClarityColors.textSecondary : ClarityColors.textPrimary)

                Text(description)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Action button
            if isActive, let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, ClaritySpacing.md)
                        .padding(.vertical, ClaritySpacing.xs)
                        .background(ClarityColors.accentPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(ClarityColors.success)
            }
        }
        .padding(ClaritySpacing.md)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? ClarityColors.accentPrimary.opacity(0.05) : ClarityColors.backgroundSecondary.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? ClarityColors.accentPrimary.opacity(0.2) : Color.clear, lineWidth: 1)
                }
        }
        .opacity(isComplete || isActive ? 1 : 0.6)
    }
}

#Preview {
    OnboardingView()
        .frame(width: 600, height: 600)
}

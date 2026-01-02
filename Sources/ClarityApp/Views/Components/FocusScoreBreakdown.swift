import SwiftUI
import ClarityShared

/// A detailed breakdown of how the focus score is calculated
struct FocusScoreBreakdown: View {
    let focusScore: Int
    let activeTimeSeconds: Int
    let contextSwitches: Int
    let deepWorkMinutes: Int
    let distractionMinutes: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header with score
            HStack {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(ClarityColors.backgroundSecondary, lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: Double(focusScore) / 100)
                        .stroke(
                            scoreGradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(focusScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(ClarityColors.textPrimary)
                        Text("/ 100")
                            .font(.system(size: 12))
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                }
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Focus Score")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text(scoreDescription)
                        .font(ClarityTypography.body)
                        .foregroundColor(scoreColor)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Hide breakdown" : "How is this calculated?")
                                .font(ClarityTypography.caption)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ClarityColors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // Expanded breakdown
            if isExpanded {
                VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                    Divider()

                    Text("Score Breakdown")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)

                    // Factors
                    VStack(spacing: ClaritySpacing.sm) {
                        ScoreFactor(
                            icon: "clock.fill",
                            title: "Deep Work Time",
                            description: "Time spent in uninterrupted focus (25+ min sessions)",
                            value: "\(deepWorkMinutes)m",
                            impact: deepWorkImpact,
                            color: ClarityColors.deepFocus
                        )

                        ScoreFactor(
                            icon: "arrow.triangle.swap",
                            title: "Context Switches",
                            description: "Number of times you switched between apps",
                            value: "\(contextSwitches)",
                            impact: contextSwitchImpact,
                            color: contextSwitches < 20 ? ClarityColors.success : ClarityColors.warning
                        )

                        ScoreFactor(
                            icon: "moon.zzz.fill",
                            title: "Distraction Time",
                            description: "Time on entertainment/social apps",
                            value: "\(distractionMinutes)m",
                            impact: distractionImpact,
                            color: distractionMinutes < 30 ? ClarityColors.success : ClarityColors.danger
                        )

                        ScoreFactor(
                            icon: "hourglass",
                            title: "Active Time",
                            description: "Total productive time today",
                            value: formatTime(activeTimeSeconds),
                            impact: activeTimeImpact,
                            color: ClarityColors.accentPrimary
                        )
                    }

                    Divider()

                    // Tips
                    VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                        Text("Tips to Improve")
                            .font(ClarityTypography.captionMedium)
                            .foregroundColor(ClarityColors.textSecondary)

                        ForEach(improvementTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: ClaritySpacing.sm) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ClarityColors.warning)

                                Text(tip)
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var scoreGradient: LinearGradient {
        let colors: [Color]
        if focusScore >= 80 {
            colors = [ClarityColors.success, ClarityColors.success.opacity(0.7)]
        } else if focusScore >= 60 {
            colors = [ClarityColors.accentPrimary, ClarityColors.focusIndigo]
        } else if focusScore >= 40 {
            colors = [ClarityColors.warning, ClarityColors.warning.opacity(0.7)]
        } else {
            colors = [ClarityColors.danger, ClarityColors.danger.opacity(0.7)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private var scoreColor: Color {
        if focusScore >= 80 { return ClarityColors.success }
        if focusScore >= 60 { return ClarityColors.accentPrimary }
        if focusScore >= 40 { return ClarityColors.warning }
        return ClarityColors.danger
    }

    private var scoreDescription: String {
        if focusScore >= 80 { return "Excellent focus!" }
        if focusScore >= 60 { return "Good focus" }
        if focusScore >= 40 { return "Moderate focus" }
        return "Needs improvement"
    }

    private var deepWorkImpact: String {
        if deepWorkMinutes >= 120 { return "+25 pts" }
        if deepWorkMinutes >= 60 { return "+15 pts" }
        if deepWorkMinutes >= 30 { return "+10 pts" }
        return "+5 pts"
    }

    private var contextSwitchImpact: String {
        if contextSwitches < 10 { return "+20 pts" }
        if contextSwitches < 20 { return "+10 pts" }
        if contextSwitches < 40 { return "+0 pts" }
        return "-10 pts"
    }

    private var distractionImpact: String {
        if distractionMinutes < 15 { return "+20 pts" }
        if distractionMinutes < 30 { return "+10 pts" }
        if distractionMinutes < 60 { return "+0 pts" }
        return "-15 pts"
    }

    private var activeTimeImpact: String {
        let hours = activeTimeSeconds / 3600
        if hours >= 6 { return "+25 pts" }
        if hours >= 4 { return "+15 pts" }
        if hours >= 2 { return "+10 pts" }
        return "+5 pts"
    }

    private var improvementTips: [String] {
        var tips: [String] = []

        if deepWorkMinutes < 60 {
            tips.append("Try longer uninterrupted work sessions (aim for 25+ minutes)")
        }
        if contextSwitches > 30 {
            tips.append("Reduce app switching by grouping similar tasks together")
        }
        if distractionMinutes > 30 {
            tips.append("Limit time on entertainment apps during work hours")
        }
        if activeTimeSeconds < 4 * 3600 {
            tips.append("Increase your active work time throughout the day")
        }

        if tips.isEmpty {
            tips.append("Great job! Keep maintaining your focused work habits.")
        }

        return Array(tips.prefix(3))
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

// MARK: - Score Factor Row

struct ScoreFactor: View {
    let icon: String
    let title: String
    let description: String
    let value: String
    let impact: String
    let color: Color

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(ClarityColors.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Value and impact
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(ClarityColors.textPrimary)

                Text(impact)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(impact.hasPrefix("-") ? ClarityColors.danger : ClarityColors.success)
            }
        }
        .padding(ClaritySpacing.sm)
        .background(ClarityColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(ClarityRadius.md)
    }
}

// MARK: - Preview

#Preview {
    GlassCard {
        FocusScoreBreakdown(
            focusScore: 72,
            activeTimeSeconds: 18000,
            contextSwitches: 25,
            deepWorkMinutes: 90,
            distractionMinutes: 20
        )
    }
    .padding()
    .frame(width: 500)
}

import SwiftUI
import ClarityShared

/// View displaying all achievements and their status
struct AchievementsView: View {
    @ObservedObject private var achievementService = AchievementService.shared  // Singleton - use @ObservedObject
    @State private var selectedCategory: AchievementCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header with progress
                header

                // Category filter
                categoryFilter

                // Achievements grid
                achievementsGrid
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .task {
            await achievementService.checkAchievements()
        }
    }

    // MARK: - Header

    private var header: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                    Text("Achievements")
                        .font(ClarityTypography.displayMedium)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text("Track your productivity milestones")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textSecondary)
                }

                Spacer()

                // Progress circle
                ZStack {
                    Circle()
                        .stroke(ClarityColors.textQuaternary.opacity(0.3), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: progressPercentage)
                        .stroke(
                            LinearGradient(
                                colors: [ClarityColors.accentPrimary, ClarityColors.focusIndigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(achievementService.earnedCount)")
                            .font(ClarityTypography.title1)
                            .foregroundColor(ClarityColors.textPrimary)
                        Text("of \(achievementService.totalCount)")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                }
                .frame(width: 80, height: 80)
            }
        }
    }

    private var progressPercentage: Double {
        guard achievementService.totalCount > 0 else { return 0 }
        return Double(achievementService.earnedCount) / Double(achievementService.totalCount)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        HStack(spacing: ClaritySpacing.sm) {
            FilterChip(title: "All", isSelected: selectedCategory == nil) {
                selectedCategory = nil
            }

            ForEach(AchievementCategory.allCases, id: \.self) { category in
                FilterChip(title: category.rawValue, isSelected: selectedCategory == category) {
                    selectedCategory = category
                }
            }

            Spacer()
        }
    }

    // MARK: - Achievements Grid

    private var achievementsGrid: some View {
        let filteredAchievements = achievementService.getAllWithStatus().filter { item in
            guard let category = selectedCategory else { return true }
            return item.achievement.category == category
        }

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: ClaritySpacing.md),
            GridItem(.flexible(), spacing: ClaritySpacing.md),
            GridItem(.flexible(), spacing: ClaritySpacing.md)
        ], spacing: ClaritySpacing.md) {
            ForEach(filteredAchievements, id: \.achievement.id) { item in
                AchievementCard(
                    achievement: item.achievement,
                    isEarned: item.earned,
                    earnedAt: item.earnedAt
                )
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ClarityTypography.captionMedium)
                .foregroundColor(isSelected ? .white : ClarityColors.textSecondary)
                .padding(.horizontal, ClaritySpacing.md)
                .padding(.vertical, ClaritySpacing.xs)
                .background(isSelected ? ClarityColors.accentPrimary : ClarityColors.backgroundSecondary)
                .cornerRadius(ClarityRadius.sm)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: Achievement
    let isEarned: Bool
    let earnedAt: Date?

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: ClaritySpacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(isEarned ? categoryColor.opacity(0.2) : ClarityColors.textQuaternary.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isEarned ? categoryColor : ClarityColors.textQuaternary)
            }

            // Text
            VStack(spacing: ClaritySpacing.xxs) {
                Text(achievement.name)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(isEarned ? ClarityColors.textPrimary : ClarityColors.textTertiary)
                    .lineLimit(1)

                Text(achievement.description)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Earned date or locked indicator
            if isEarned, let date = earnedAt {
                Text("Earned \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.success)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Locked")
                        .font(.system(size: 10))
                }
                .foregroundColor(ClarityColors.textQuaternary)
            }
        }
        .padding(ClaritySpacing.md)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: ClarityRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: ClarityRadius.lg)
                        .stroke(
                            isEarned ? categoryColor.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                }
        }
        .opacity(isEarned ? 1 : 0.7)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(ClarityAnimations.microSpring, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var categoryColor: Color {
        switch achievement.category {
        case .focus:
            return ClarityColors.focusIndigo
        case .productivity:
            return ClarityColors.success
        case .consistency:
            return ClarityColors.warning
        case .input:
            return ClarityColors.accentPrimary
        }
    }
}

// MARK: - Achievement Popup

struct AchievementPopup: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    @State private var isShowing = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            VStack(spacing: ClaritySpacing.md) {
                // Celebration icon
                ZStack {
                    // Pulsing rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(ClarityColors.warning.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                            .frame(width: 80 + CGFloat(i * 20), height: 80 + CGFloat(i * 20))
                            .scaleEffect(isShowing ? 1.2 : 0.8)
                            .opacity(isShowing ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.2),
                                value: isShowing
                            )
                    }

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ClarityColors.warning, ClarityColors.warning.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: ClarityColors.warning.opacity(0.5), radius: 10)

                    Image(systemName: achievement.icon)
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .scaleEffect(isShowing ? 1 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isShowing)

                Text("Achievement Unlocked!")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)
                    .opacity(isShowing ? 1 : 0)
                    .offset(y: isShowing ? 0 : 10)
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: isShowing)

                Text(achievement.name)
                    .font(ClarityTypography.title1)
                    .foregroundColor(ClarityColors.accentPrimary)
                    .opacity(isShowing ? 1 : 0)
                    .offset(y: isShowing ? 0 : 10)
                    .animation(.easeOut(duration: 0.3).delay(0.3), value: isShowing)

                Text(achievement.description)
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(isShowing ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.4), value: isShowing)

                Button("Awesome!") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(ClarityColors.accentPrimary)
                .padding(.top, ClaritySpacing.sm)
                .opacity(isShowing ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.5), value: isShowing)
            }
            .padding(ClaritySpacing.xl)
            .background {
                RoundedRectangle(cornerRadius: ClarityRadius.xl)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            }

            // Confetti overlay
            ConfettiView(isActive: $showConfetti)
        }
        .onAppear {
            isShowing = true
            // Trigger confetti after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    AchievementsView()
        .frame(width: 900, height: 700)
}

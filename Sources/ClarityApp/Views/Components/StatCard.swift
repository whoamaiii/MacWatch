import SwiftUI

/// Card displaying a single metric
public struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let comparison: Comparison?

    @Environment(\.colorScheme) var colorScheme

    public enum Comparison {
        case up(String)
        case down(String)
        case neutral(String)

        var color: Color {
            switch self {
            case .up: return ClarityColors.success
            case .down: return ClarityColors.danger
            case .neutral: return ClarityColors.textTertiary
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }

        var text: String {
            switch self {
            case .up(let t), .down(let t), .neutral(let t): return t
            }
        }
    }

    public init(
        icon: String,
        value: String,
        label: String,
        comparison: Comparison? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.comparison = comparison
    }

    /// Convenience initializer with title/color/trend parameters
    public init(
        title: String,
        value: String,
        icon: String,
        color: Color = ClarityColors.accentPrimary,
        trend: String? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = title
        if let trend = trend {
            if trend.hasPrefix("+") {
                self.comparison = .up(trend)
            } else if trend.hasPrefix("-") {
                self.comparison = .down(trend)
            } else {
                self.comparison = .neutral(trend)
            }
        } else {
            self.comparison = nil
        }
    }

    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(ClarityColors.accentPrimary)

                // Value
                Text(value)
                    .font(ClarityTypography.monoLarge)
                    .foregroundColor(colorScheme == .dark ? .white : ClarityColors.textPrimary)

                // Label
                Text(label)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)

                // Comparison
                if let comparison = comparison {
                    HStack(spacing: 4) {
                        Image(systemName: comparison.icon)
                            .font(.caption2)
                        Text(comparison.text)
                            .font(ClarityTypography.caption)
                    }
                    .foregroundColor(comparison.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .hoverEffect()
    }
}

// MARK: - Animated Number

public struct AnimatedNumber: View {
    let value: Int
    var format: String = "%d"

    @State private var displayValue: Double = 0

    public var body: some View {
        Text(String(format: format, Int(displayValue)))
            .contentTransition(.numericText(value: displayValue))
            .onChange(of: value) { oldValue, newValue in
                withAnimation(ClarityAnimations.countUp) {
                    displayValue = Double(newValue)
                }
            }
            .onAppear {
                withAnimation(ClarityAnimations.countUp.delay(0.1)) {
                    displayValue = Double(value)
                }
            }
    }
}

// MARK: - Progress Bar

public struct ClarityProgressBar: View {
    let progress: Double
    var color: Color = ClarityColors.accentPrimary
    var height: CGFloat = 8
    var showBackground: Bool = true

    @State private var animatedProgress: Double = 0

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                if showBackground {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(ClarityColors.textQuaternary.opacity(0.2))
                }

                // Filled portion
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * min(1, animatedProgress)))
            }
        }
        .frame(height: height)
        .onChange(of: progress) { _, newValue in
            withAnimation(ClarityAnimations.mediumSpring) {
                animatedProgress = newValue
            }
        }
        .onAppear {
            withAnimation(ClarityAnimations.mediumSpring.delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - App Row

public struct AppRowView: View {
    let name: String
    let icon: NSImage?
    let duration: String
    let progress: Double
    let color: Color

    @Environment(\.colorScheme) var colorScheme

    public var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // App icon
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ClarityColors.textQuaternary.opacity(0.3))
                    .frame(width: 32, height: 32)
            }

            // App name
            Text(name)
                .font(ClarityTypography.bodyMedium)
                .foregroundColor(colorScheme == .dark ? .white : ClarityColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Duration
            Text(duration)
                .font(ClarityTypography.mono)
                .foregroundColor(ClarityColors.textSecondary)

            // Progress bar
            ClarityProgressBar(progress: progress, color: color)
                .frame(width: 80)
        }
        .padding(.vertical, ClaritySpacing.xs)
        .contentShape(Rectangle())
        .hoverEffect(scale: 1.01, lift: 1)
    }
}

// MARK: - Trend Indicator

public struct TrendIndicator: View {
    let value: Double
    let unit: String

    var isPositive: Bool { value >= 0 }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                .font(.caption2)
            Text("\(abs(value), specifier: "%.1f")\(unit)")
                .font(ClarityTypography.caption)
        }
        .foregroundColor(isPositive ? ClarityColors.success : ClarityColors.danger)
    }
}

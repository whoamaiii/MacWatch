import SwiftUI

/// Glass morphism card container with enhanced visual effects
public struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat
    var enableHover: Bool

    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    public init(
        padding: CGFloat = ClaritySpacing.cardPadding,
        enableHover: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.enableHover = enableHover
    }

    public var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: ClarityRadius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Inner glow on hover
                        if isHovered {
                            RoundedRectangle(cornerRadius: ClarityRadius.lg)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            ClarityColors.accentPrimary.opacity(0.05),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 200
                                    )
                                )
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: ClarityRadius.lg)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? (isHovered ? 0.2 : 0.15) : (isHovered ? 0.35 : 0.25)),
                                        .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isHovered ? 1 : 0.5
                            )
                    }
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? (isHovered ? 0.4 : 0.3) : (isHovered ? 0.15 : 0.1)),
                        radius: isHovered ? 16 : 10,
                        y: isHovered ? 6 : 4
                    )
            }
            .scaleEffect(isHovered && enableHover ? 1.005 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                if enableHover {
                    isHovered = hovering
                }
            }
    }
}

/// Accent card with colored left border
public struct AccentCard<Content: View>: View {
    let content: Content
    let accentColor: Color
    var padding: CGFloat

    @Environment(\.colorScheme) var colorScheme

    public init(
        accentColor: Color = ClarityColors.accentPrimary,
        padding: CGFloat = ClaritySpacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.accentColor = accentColor
        self.padding = padding
    }

    public var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: ClarityRadius.md)
                .fill(accentColor.opacity(0.08))
        }
        .clipShape(RoundedRectangle(cornerRadius: ClarityRadius.md))
    }
}

// MARK: - Hover Effect

public struct HoverEffect: ViewModifier {
    @State private var isHovered = false

    var scale: CGFloat
    var lift: CGFloat

    public init(scale: CGFloat = 1.02, lift: CGFloat = 2) {
        self.scale = scale
        self.lift = lift
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .offset(y: isHovered ? -lift : 0)
            .shadow(
                color: .black.opacity(isHovered ? 0.15 : 0.1),
                radius: isHovered ? 16 : 10,
                y: isHovered ? 8 : 4
            )
            .animation(ClarityAnimations.smallSpring, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public extension View {
    func hoverEffect(scale: CGFloat = 1.02, lift: CGFloat = 2) -> some View {
        modifier(HoverEffect(scale: scale, lift: lift))
    }
}

// MARK: - Shimmer Effect

public struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.2),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

public extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Skeleton View

public struct SkeletonView: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = ClarityRadius.sm

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(ClarityColors.textQuaternary.opacity(0.2))
            .frame(height: height)
            .shimmer()
    }
}

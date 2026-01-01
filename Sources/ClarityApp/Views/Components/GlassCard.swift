import SwiftUI

/// Glass morphism card container
public struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat

    @Environment(\.colorScheme) var colorScheme

    public init(
        padding: CGFloat = ClaritySpacing.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
    }

    public var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: ClarityRadius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: ClarityRadius.lg)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                                        .white.opacity(colorScheme == .dark ? 0.05 : 0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: 10,
                        y: 4
                    )
            }
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

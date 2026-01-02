import SwiftUI

/// A confetti celebration effect for achievements and milestones
struct ConfettiView: View {
    @Binding var isActive: Bool
    var particleCount: Int = 50
    var colors: [Color] = [
        ClarityColors.accentPrimary,
        ClarityColors.success,
        ClarityColors.warning,
        ClarityColors.deepFocus,
        ClarityColors.entertainment,
        .pink,
        .cyan
    ]

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle)
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    triggerConfetti(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func triggerConfetti(in size: CGSize) {
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                x: size.width / 2 + CGFloat.random(in: -50...50),
                y: size.height / 2,
                color: colors.randomElement() ?? .accentColor,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                shape: ConfettiShape.allCases.randomElement() ?? .circle
            )
        }

        // Animate particles
        for i in particles.indices {
            let delay = Double.random(in: 0...0.2)
            let duration = Double.random(in: 1.5...2.5)

            withAnimation(.easeOut(duration: duration).delay(delay)) {
                particles[i].x += CGFloat.random(in: -200...200)
                particles[i].y += CGFloat.random(in: 200...400)
                particles[i].rotation += Double.random(in: 360...720)
                particles[i].opacity = 0
                particles[i].scale = CGFloat.random(in: 0.3...0.8)
            }
        }

        // Clear after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            particles = []
            isActive = false
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var color: Color
    var size: CGFloat
    var rotation: Double
    var shape: ConfettiShape
    var opacity: Double = 1
    var scale: CGFloat = 1
}

enum ConfettiShape: CaseIterable {
    case circle
    case square
    case triangle
    case star
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle

    var body: some View {
        Group {
            switch particle.shape {
            case .circle:
                Circle()
                    .fill(particle.color)
            case .square:
                Rectangle()
                    .fill(particle.color)
            case .triangle:
                Triangle()
                    .fill(particle.color)
            case .star:
                Star(corners: 5, smoothness: 0.45)
                    .fill(particle.color)
            }
        }
        .frame(width: particle.size, height: particle.size)
        .scaleEffect(particle.scale)
        .rotationEffect(.degrees(particle.rotation))
        .opacity(particle.opacity)
        .position(x: particle.x, y: particle.y)
    }
}

// MARK: - Custom Shapes

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct Star: Shape {
    let corners: Int
    let smoothness: CGFloat

    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }

        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        var currentAngle = -CGFloat.pi / 2
        let angleAdjustment = .pi * 2 / CGFloat(corners * 2)
        let innerRadius = rect.width / 2 * smoothness
        let outerRadius = rect.width / 2

        var path = Path()

        for corner in 0..<corners * 2 {
            let radius = corner.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(currentAngle) * radius,
                y: center.y + sin(currentAngle) * radius
            )

            if corner == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }

            currentAngle += angleAdjustment
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Celebration Trigger

/// A view modifier that shows confetti when triggered
struct CelebrationModifier: ViewModifier {
    @Binding var celebrate: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                ConfettiView(isActive: $celebrate)
            }
    }
}

extension View {
    func celebration(isActive: Binding<Bool>) -> some View {
        modifier(CelebrationModifier(celebrate: isActive))
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var showConfetti = false

        var body: some View {
            VStack {
                Button("Celebrate!") {
                    showConfetti = true
                }
                .padding()
            }
            .frame(width: 400, height: 400)
            .celebration(isActive: $showConfetti)
        }
    }

    return PreviewWrapper()
}

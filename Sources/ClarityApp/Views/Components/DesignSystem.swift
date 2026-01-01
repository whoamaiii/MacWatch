import SwiftUI
import ClarityShared

// MARK: - Colors

public struct ClarityColors {
    // Backgrounds
    public static let backgroundPrimary = Color(hex: "FAFAFA")
    public static let backgroundSecondary = Color(hex: "F5F5F7")
    public static let backgroundTertiary = Color.white

    // Text
    public static let textPrimary = Color(hex: "1D1D1F")
    public static let textSecondary = Color(hex: "424245")
    public static let textTertiary = Color(hex: "86868B")
    public static let textQuaternary = Color(hex: "AEAEB2")

    // Accents
    public static let accentPrimary = Color(hex: "0071E3")
    public static let focusIndigo = Color(hex: "5856D6")
    public static let success = Color(hex: "34C759")
    public static let warning = Color(hex: "FF9500")
    public static let danger = Color(hex: "FF3B30")

    // Data Visualization
    public static let deepFocus = Color(hex: "5856D6")
    public static let activeWork = Color(hex: "007AFF")
    public static let communication = Color(hex: "5AC8FA")
    public static let productivity = Color(hex: "34C759")
    public static let entertainment = Color(hex: "FF9500")
    public static let browsing = Color(hex: "FF6B6B")
    public static let music = Color(hex: "1DB954")
    public static let idle = Color(hex: "8E8E93")

    // Dark mode variants
    public static let darkBackgroundPrimary = Color.black
    public static let darkBackgroundSecondary = Color(hex: "1C1C1E")
    public static let darkBackgroundTertiary = Color(hex: "2C2C2E")
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

public struct ClarityTypography {
    public static let displayLarge = Font.system(size: 34, weight: .bold)
    public static let displayMedium = Font.system(size: 28, weight: .semibold)
    public static let title1 = Font.system(size: 22, weight: .semibold)
    public static let title2 = Font.system(size: 17, weight: .semibold)
    public static let title3 = Font.system(size: 15, weight: .semibold)
    public static let body = Font.system(size: 15, weight: .regular)
    public static let bodyMedium = Font.system(size: 15, weight: .medium)
    public static let caption = Font.system(size: 13, weight: .regular)
    public static let captionMedium = Font.system(size: 13, weight: .medium)
    public static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)
    public static let monoLarge = Font.system(size: 28, weight: .bold, design: .monospaced)
    public static let monoHero = Font.system(size: 48, weight: .bold, design: .monospaced)
}

// MARK: - Spacing

public struct ClaritySpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48

    public static let cardPadding: CGFloat = 20
    public static let cardSpacing: CGFloat = 16
    public static let sidebarWidth: CGFloat = 220
}

// MARK: - Radius

public struct ClarityRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
}

// MARK: - Animations

public struct ClarityAnimations {
    public static let micro = Animation.easeOut(duration: 0.15)
    public static let microSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let small = Animation.easeOut(duration: 0.2)
    public static let smallSpring = Animation.spring(response: 0.35, dampingFraction: 0.65)
    public static let medium = Animation.easeInOut(duration: 0.3)
    public static let mediumSpring = Animation.spring(response: 0.4, dampingFraction: 0.75)
    public static let large = Animation.easeInOut(duration: 0.4)
    public static let countUp = Animation.spring(response: 0.8, dampingFraction: 0.7)
}

// MARK: - AppCategory Color Extension

extension AppCategory {
    public var color: Color {
        Color(hex: self.colorHex)
    }
}

// MARK: - Icons

public struct ClarityIcons {
    public static let dashboard = "chart.bar.fill"
    public static let timeline = "clock.fill"
    public static let apps = "square.grid.2x2.fill"
    public static let input = "keyboard.fill"
    public static let focus = "target"
    public static let insights = "lightbulb.fill"
    public static let system = "cpu.fill"
    public static let settings = "gearshape.fill"
    public static let time = "clock"
    public static let keystrokes = "keyboard"
    public static let clicks = "cursorarrow.click"
    public static let focusScore = "flame.fill"
    public static let trendUp = "arrow.up.right"
    public static let trendDown = "arrow.down.right"
    public static let live = "circle.fill"
}

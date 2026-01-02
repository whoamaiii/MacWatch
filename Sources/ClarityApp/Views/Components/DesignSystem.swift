import SwiftUI
import AppKit
import ClarityShared

// MARK: - Colors

public struct ClarityColors {
    // Adaptive Backgrounds - automatically switch based on color scheme
    public static let backgroundPrimary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0, green: 0, blue: 0, alpha: 1) // Dark: black
            : NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1) // Light: FAFAFA
    })

    public static let backgroundSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) // Dark: 1C1C1E
            : NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1) // Light: F5F5F7
    })

    public static let backgroundTertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1) // Dark: 2C2C2E
            : NSColor(red: 1, green: 1, blue: 1, alpha: 1) // Light: white
    })

    // Adaptive Text
    public static let textPrimary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 1, green: 1, blue: 1, alpha: 1) // Dark: white
            : NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) // Light: 1D1D1F
    })

    public static let textSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1) // Dark: EBEBEB
            : NSColor(red: 0.26, green: 0.26, blue: 0.27, alpha: 1) // Light: 424245
    })

    public static let textTertiary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1) // Dark: 999999
            : NSColor(red: 0.53, green: 0.53, blue: 0.55, alpha: 1) // Light: 86868B
    })

    public static let textQuaternary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            ? NSColor(red: 0.4, green: 0.4, blue: 0.42, alpha: 1) // Dark: 66666B
            : NSColor(red: 0.68, green: 0.68, blue: 0.7, alpha: 1) // Light: AEAEB2
    })

    // Accents (same in both modes, vibrant colors)
    public static let accentPrimary = Color(hex: "0071E3")
    public static let focusIndigo = Color(hex: "5856D6")
    public static let success = Color(hex: "34C759")
    public static let warning = Color(hex: "FF9500")
    public static let danger = Color(hex: "FF3B30")

    // Data Visualization (same in both modes)
    public static let deepFocus = Color(hex: "5856D6")
    public static let activeWork = Color(hex: "007AFF")
    public static let communication = Color(hex: "5AC8FA")
    public static let productivity = Color(hex: "34C759")
    public static let entertainment = Color(hex: "FF9500")
    public static let browsing = Color(hex: "FF6B6B")
    public static let music = Color(hex: "1DB954")
    public static let idle = Color(hex: "8E8E93")
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

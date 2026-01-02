import SwiftUI
import AppKit

/// Click heatmap visualization showing where clicks occur on screen
struct ClickHeatmap: View {
    let clickPositions: [[Int]]  // [[x, y], ...]
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let originX: CGFloat
    let originY: CGFloat

    // Grid resolution for heatmap
    private let gridCols = 32
    private let gridRows = 18

    private var heatmapData: [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: gridCols), count: gridRows)

        // Guard against division by zero
        guard screenWidth > 0, screenHeight > 0 else { return grid }

        let cellWidth = screenWidth / CGFloat(gridCols)
        let cellHeight = screenHeight / CGFloat(gridRows)

        // Additional guard for cell dimensions
        guard cellWidth > 0, cellHeight > 0 else { return grid }

        for position in clickPositions {
            guard position.count >= 2 else { continue }
            let x = position[0]
            let y = position[1]
            let adjustedX = CGFloat(x) - originX
            let adjustedY = CGFloat(y) - originY

            let col = min(gridCols - 1, max(0, Int(adjustedX / cellWidth)))
            let row = min(gridRows - 1, max(0, Int(adjustedY / cellHeight)))

            grid[row][col] += 1
        }

        return grid
    }

    private var maxValue: Int {
        heatmapData.flatMap { $0 }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            // Guard against zero dimensions
            let safeWidth = max(geometry.size.width, 1)
            let safeHeight = max(geometry.size.height, 1)
            let cellWidth = safeWidth / CGFloat(gridCols)
            let cellHeight = safeHeight / CGFloat(gridRows)

            ZStack {
                // Background representing screen
                RoundedRectangle(cornerRadius: 8)
                    .fill(ClarityColors.backgroundSecondary)

                // Heatmap grid
                Canvas { context, size in
                    for row in 0..<gridRows {
                        for col in 0..<gridCols {
                            let value = heatmapData[row][col]
                            if value > 0 {
                                let intensity = Double(value) / Double(maxValue)
                                let color = heatmapColor(intensity: intensity)

                                let rect = CGRect(
                                    x: CGFloat(col) * cellWidth,
                                    y: CGFloat(row) * cellHeight,
                                    width: cellWidth,
                                    height: cellHeight
                                )

                                context.fill(
                                    Path(roundedRect: rect, cornerRadius: 2),
                                    with: .color(color)
                                )
                            }
                        }
                    }
                }

                // Screen frame overlay
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ClarityColors.textQuaternary, lineWidth: 1)

                // Notch indicator (for MacBooks)
                VStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ClarityColors.backgroundSecondary)
                        .frame(width: 60, height: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(ClarityColors.textQuaternary, lineWidth: 0.5)
                        )
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .aspectRatio(16/10, contentMode: .fit)
    }

    private func heatmapColor(intensity: Double) -> Color {
        // Cool to warm gradient: blue -> cyan -> green -> yellow -> orange -> red
        let hue: Double
        if intensity < 0.2 {
            hue = 0.6  // Blue
        } else if intensity < 0.4 {
            hue = 0.5  // Cyan
        } else if intensity < 0.6 {
            hue = 0.35 // Green-yellow
        } else if intensity < 0.8 {
            hue = 0.15 // Orange
        } else {
            hue = 0.0  // Red
        }

        let saturation = 0.6 + (intensity * 0.4)
        let brightness = 0.7 + (intensity * 0.3)
        let opacity = 0.3 + (intensity * 0.7)

        return Color(hue: hue, saturation: saturation, brightness: brightness, opacity: opacity)
    }
}

/// Compact click heatmap with legend
struct ClickHeatmapCard: View {
    let clickPositions: [[Int]]

    /// Calculates screen bounds from click data or falls back to combined screen bounds
    private var screenBounds: CGRect {
        // Try to get combined bounds of all screens
        let allScreens = NSScreen.screens
        if !allScreens.isEmpty {
            let minX = allScreens.map { $0.frame.minX }.min() ?? 0
            let minY = allScreens.map { $0.frame.minY }.min() ?? 0
            let maxX = allScreens.map { $0.frame.maxX }.max() ?? 1920
            let maxY = allScreens.map { $0.frame.maxY }.max() ?? 1080
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        // Fallback: infer from click data if available
        if !clickPositions.isEmpty {
            let xs = clickPositions.compactMap { $0.first }
            let ys = clickPositions.compactMap { $0.count > 1 ? $0[1] : nil }
            let minX = xs.min() ?? 0
            let minY = ys.min() ?? 0
            let maxX = xs.max() ?? 1920
            let maxY = ys.max() ?? 1080
            // Add 10% margin to avoid edge clipping
            let width = CGFloat(maxX - minX) * 1.1
            let height = CGFloat(maxY - minY) * 1.1
            return CGRect(x: CGFloat(minX), y: CGFloat(minY), width: width, height: height)
        }

        return CGRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    private var screenSize: CGSize {
        screenBounds.size
    }

    private var screenOrigin: CGPoint {
        screenBounds.origin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            HStack {
                Text("Click Heatmap")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Text("\(clickPositions.count) clicks")
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
            }

            if clickPositions.isEmpty {
                Text("No click data recorded yet")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ClaritySpacing.xl)
            } else {
                ClickHeatmap(
                    clickPositions: clickPositions,
                    screenWidth: screenSize.width,
                    screenHeight: screenSize.height,
                    originX: screenOrigin.x,
                    originY: screenOrigin.y
                )
                .frame(height: 200)

                // Legend
                HStack(spacing: ClaritySpacing.md) {
                    HStack(spacing: ClaritySpacing.xxs) {
                        Circle()
                            .fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.8))
                            .frame(width: 10, height: 10)
                        Text("Low")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hue: 0.6, saturation: 0.7, brightness: 0.8),
                                    Color(hue: 0.35, saturation: 0.8, brightness: 0.85),
                                    Color(hue: 0.0, saturation: 0.9, brightness: 0.9)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 80, height: 8)
                        .cornerRadius(4)

                    HStack(spacing: ClaritySpacing.xxs) {
                        Circle()
                            .fill(Color(hue: 0.0, saturation: 0.9, brightness: 0.9))
                            .frame(width: 10, height: 10)
                        Text("High")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }

                    Spacer()
                }
            }
        }
    }
}

#Preview {
    // Sample click data concentrated in common areas
    let sampleClicks: [[Int]] = {
        var clicks: [[Int]] = []

        // Top menu bar area
        for _ in 0..<50 {
            clicks.append([Int.random(in: 0...1920), Int.random(in: 0...30)])
        }

        // Dock area (bottom)
        for _ in 0..<100 {
            clicks.append([Int.random(in: 400...1500), Int.random(in: 1050...1080)])
        }

        // Center of screen (main content)
        for _ in 0..<200 {
            clicks.append([Int.random(in: 300...1600), Int.random(in: 200...800)])
        }

        // Left sidebar
        for _ in 0..<80 {
            clicks.append([Int.random(in: 0...250), Int.random(in: 100...900)])
        }

        return clicks
    }()

    GlassCard {
        ClickHeatmapCard(clickPositions: sampleClicks)
    }
    .padding()
    .frame(width: 600)
    .background(ClarityColors.backgroundPrimary)
}

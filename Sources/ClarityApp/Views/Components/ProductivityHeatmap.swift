import SwiftUI

/// A heatmap visualization showing productivity by hour and day of week
/// Grid layout: 7 rows (days) x 24 columns (hours)
struct ProductivityHeatmap: View {
    let data: [[Int]] // [dayOfWeek][hour] = seconds of activity
    var showLabels: Bool = true

    private let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let hourLabels = (0..<24).map { hour in
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    // Calculate max value for color scaling
    private var maxValue: Int {
        data.flatMap { $0 }.max() ?? 1
    }

    var body: some View {
        VStack(spacing: ClaritySpacing.xs) {
            // Hour labels at top
            if showLabels {
                HStack(spacing: 0) {
                    // Spacer for day label column
                    Text("")
                        .frame(width: 32)

                    ForEach(Array(stride(from: 0, to: 24, by: 3)), id: \.self) { hour in
                        Text(hourLabels[hour])
                            .font(.system(size: 9))
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Grid rows
            ForEach(0..<7, id: \.self) { dayIndex in
                HStack(spacing: 2) {
                    // Day label
                    if showLabels {
                        Text(dayLabels[dayIndex])
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ClarityColors.textSecondary)
                            .frame(width: 32, alignment: .trailing)
                    }

                    // Hour cells
                    ForEach(0..<24, id: \.self) { hourIndex in
                        let value = data.indices.contains(dayIndex) && data[dayIndex].indices.contains(hourIndex)
                            ? data[dayIndex][hourIndex]
                            : 0

                        HeatmapCell(value: value, maxValue: maxValue)
                    }
                }
            }

            // Legend
            HStack(spacing: ClaritySpacing.sm) {
                Spacer()
                Text("Less")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForLevel(Double(level) / 4.0))
                            .frame(width: 12, height: 12)
                    }
                }

                Text("More")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)
            }
            .padding(.top, ClaritySpacing.xs)
        }
    }

    private func colorForLevel(_ level: Double) -> Color {
        if level == 0 {
            return ClarityColors.backgroundSecondary
        }
        return ClarityColors.accentPrimary.opacity(0.2 + (level * 0.8))
    }
}

// MARK: - Heatmap Cell

private struct HeatmapCell: View {
    let value: Int
    let maxValue: Int

    @State private var isHovered = false

    private var intensity: Double {
        guard maxValue > 0 else { return 0 }
        return Double(value) / Double(maxValue)
    }

    private var color: Color {
        if value == 0 {
            return ClarityColors.backgroundSecondary
        }
        // Gradient from light blue to deep blue based on intensity
        return ClarityColors.accentPrimary.opacity(0.2 + (intensity * 0.8))
    }

    private var formattedTime: String {
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 14)
            .overlay {
                if isHovered && value > 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(ClarityColors.textPrimary.opacity(0.5), lineWidth: 1)
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .help(value > 0 ? formattedTime : "No activity")
    }
}

// MARK: - Compact Heatmap

/// A more compact version of the heatmap for smaller spaces
struct CompactProductivityHeatmap: View {
    let data: [[Int]]

    private var maxValue: Int {
        data.flatMap { $0 }.max() ?? 1
    }

    var body: some View {
        VStack(spacing: 1) {
            ForEach(0..<7, id: \.self) { dayIndex in
                HStack(spacing: 1) {
                    ForEach(0..<24, id: \.self) { hourIndex in
                        let value = data.indices.contains(dayIndex) && data[dayIndex].indices.contains(hourIndex)
                            ? data[dayIndex][hourIndex]
                            : 0

                        CompactHeatmapCell(value: value, maxValue: maxValue)
                    }
                }
            }
        }
    }
}

private struct CompactHeatmapCell: View {
    let value: Int
    let maxValue: Int

    private var intensity: Double {
        guard maxValue > 0 else { return 0 }
        return Double(value) / Double(maxValue)
    }

    private var color: Color {
        if value == 0 {
            return ClarityColors.backgroundSecondary.opacity(0.5)
        }
        return ClarityColors.accentPrimary.opacity(0.2 + (intensity * 0.8))
    }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 8)
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                Text("Productivity Heatmap")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                ProductivityHeatmap(data: sampleHeatmapData)
            }
        }
        .padding()

        GlassCard {
            VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                Text("Compact View")
                    .font(ClarityTypography.title3)
                    .foregroundColor(ClarityColors.textPrimary)

                CompactProductivityHeatmap(data: sampleHeatmapData)
            }
        }
        .padding(.horizontal)
    }
    .frame(width: 800, height: 400)
    .background(ClarityColors.backgroundPrimary)
}

// Sample data for preview
private let sampleHeatmapData: [[Int]] = {
    var data = Array(repeating: Array(repeating: 0, count: 24), count: 7)
    // Add some sample activity data
    for day in 0..<7 {
        for hour in 8..<18 {
            // More activity during weekdays (Mon-Fri = days 1-5)
            let isWeekday = day >= 1 && day <= 5
            let baseActivity = isWeekday ? 1800 : 600 // 30 min vs 10 min
            let variance = Int.random(in: -600...1200)
            data[day][hour] = max(0, baseActivity + variance)
        }
        // Some evening activity
        for hour in 19..<22 {
            data[day][hour] = Int.random(in: 0...900)
        }
    }
    return data
}()

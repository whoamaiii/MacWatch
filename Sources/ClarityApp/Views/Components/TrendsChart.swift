import SwiftUI
import ClarityShared

/// A line chart showing productivity trends over time
struct TrendsChart: View {
    let data: [TrendDataPoint]
    let metric: TrendMetric

    @State private var selectedPoint: TrendDataPoint?
    @State private var hoveredIndex: Int?

    enum TrendMetric: String, CaseIterable {
        case activeTime = "Active Time"
        case focusScore = "Focus Score"
        case keystrokes = "Keystrokes"
        case distractionTime = "Distraction"

        var color: Color {
            switch self {
            case .activeTime: return ClarityColors.accentPrimary
            case .focusScore: return ClarityColors.deepFocus
            case .keystrokes: return ClarityColors.productivity
            case .distractionTime: return ClarityColors.warning
            }
        }

        var icon: String {
            switch self {
            case .activeTime: return ClarityIcons.time
            case .focusScore: return "target"
            case .keystrokes: return ClarityIcons.keystrokes
            case .distractionTime: return "moon.zzz.fill"
            }
        }
    }

    struct TrendDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
        let label: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            // Header with metric info
            HStack {
                Image(systemName: metric.icon)
                    .font(.system(size: 14))
                    .foregroundColor(metric.color)

                Text(metric.rawValue)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                // Trend indicator
                if data.count >= 2 {
                    let trend = calculateTrend()
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(Int(trend)))%")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(trendColor(trend))
                }
            }

            // Chart
            GeometryReader { geometry in
                let chartHeight = geometry.size.height - 20
                let chartWidth = geometry.size.width
                let maxValue = data.map { $0.value }.max() ?? 1
                let minValue = data.map { $0.value }.min() ?? 0
                let range = max(maxValue - minValue, 1)

                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { i in
                            Divider()
                                .opacity(0.3)
                            if i < 3 { Spacer() }
                        }
                    }
                    .frame(height: chartHeight)

                    // Line path
                    if data.count > 1 {
                        Path { path in
                            for (index, point) in data.enumerated() {
                                let x = CGFloat(index) / CGFloat(data.count - 1) * chartWidth
                                let normalizedY = (point.value - minValue) / range
                                let y = chartHeight - (normalizedY * chartHeight)

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(
                            LinearGradient(
                                colors: [metric.color, metric.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                        // Gradient fill under line
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: chartHeight))

                            for (index, point) in data.enumerated() {
                                let x = CGFloat(index) / CGFloat(data.count - 1) * chartWidth
                                let normalizedY = (point.value - minValue) / range
                                let y = chartHeight - (normalizedY * chartHeight)

                                if index == 0 {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }

                            path.addLine(to: CGPoint(x: chartWidth, y: chartHeight))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [metric.color.opacity(0.3), metric.color.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                        let x = data.count > 1 ? CGFloat(index) / CGFloat(data.count - 1) * chartWidth : chartWidth / 2
                        let normalizedY = (point.value - minValue) / range
                        let y = chartHeight - (normalizedY * chartHeight)

                        Circle()
                            .fill(hoveredIndex == index ? metric.color : Color.white)
                            .frame(width: hoveredIndex == index ? 10 : 6, height: hoveredIndex == index ? 10 : 6)
                            .overlay(
                                Circle()
                                    .stroke(metric.color, lineWidth: 2)
                            )
                            .shadow(color: metric.color.opacity(0.3), radius: hoveredIndex == index ? 4 : 0)
                            .position(x: x, y: y)
                            .onHover { hovering in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    hoveredIndex = hovering ? index : nil
                                    selectedPoint = hovering ? point : nil
                                }
                            }
                    }

                    // Tooltip
                    if let point = selectedPoint, let index = hoveredIndex {
                        let x = data.count > 1 ? CGFloat(index) / CGFloat(data.count - 1) * chartWidth : chartWidth / 2
                        let normalizedY = (point.value - minValue) / range
                        let y = chartHeight - (normalizedY * chartHeight)

                        VStack(spacing: 2) {
                            Text(point.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(ClarityColors.textPrimary)
                            Text(formatValue(point.value))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(metric.color)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 4)
                        )
                        .position(x: min(max(x, 40), chartWidth - 40), y: max(y - 30, 20))
                    }
                }
            }
            .frame(height: 120)

            // X-axis labels
            HStack {
                if let first = data.first {
                    Text(first.label)
                        .font(.system(size: 10))
                        .foregroundColor(ClarityColors.textTertiary)
                }
                Spacer()
                if let last = data.last, data.count > 1 {
                    Text(last.label)
                        .font(.system(size: 10))
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }
        }
    }

    private func calculateTrend() -> Double {
        guard data.count >= 2 else { return 0 }
        let firstHalf = data.prefix(data.count / 2)
        let secondHalf = data.suffix(data.count / 2)

        let firstAvg = firstHalf.map { $0.value }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.value }.reduce(0, +) / Double(secondHalf.count)

        guard firstAvg > 0 else { return 0 }
        return ((secondAvg - firstAvg) / firstAvg) * 100
    }

    private func trendColor(_ trend: Double) -> Color {
        switch metric {
        case .distractionTime:
            // For distraction, down is good
            return trend <= 0 ? ClarityColors.success : ClarityColors.danger
        default:
            // For other metrics, up is good
            return trend >= 0 ? ClarityColors.success : ClarityColors.danger
        }
    }

    private func formatValue(_ value: Double) -> String {
        switch metric {
        case .activeTime:
            let hours = Int(value) / 3600
            let minutes = (Int(value) % 3600) / 60
            return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        case .focusScore:
            return "\(Int(value))%"
        case .keystrokes:
            return value.formatted()
        case .distractionTime:
            let minutes = Int(value) / 60
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        GlassCard {
            TrendsChart(
                data: [
                    .init(date: Date(), value: 14400, label: "Mon"),
                    .init(date: Date(), value: 18000, label: "Tue"),
                    .init(date: Date(), value: 16200, label: "Wed"),
                    .init(date: Date(), value: 21600, label: "Thu"),
                    .init(date: Date(), value: 19800, label: "Fri"),
                    .init(date: Date(), value: 10800, label: "Sat"),
                    .init(date: Date(), value: 7200, label: "Sun"),
                ],
                metric: .activeTime
            )
        }

        GlassCard {
            TrendsChart(
                data: [
                    .init(date: Date(), value: 65, label: "Mon"),
                    .init(date: Date(), value: 72, label: "Tue"),
                    .init(date: Date(), value: 68, label: "Wed"),
                    .init(date: Date(), value: 80, label: "Thu"),
                    .init(date: Date(), value: 75, label: "Fri"),
                    .init(date: Date(), value: 55, label: "Sat"),
                    .init(date: Date(), value: 45, label: "Sun"),
                ],
                metric: .focusScore
            )
        }
    }
    .padding()
    .frame(width: 400, height: 400)
}

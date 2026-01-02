import SwiftUI
import ClarityShared

/// Shows productivity trends over weeks and months
struct ProductivityTrendsView: View {
    @StateObject private var viewModel = ProductivityTrendsViewModel()
    @State private var selectedPeriod: TrendPeriod = .week

    enum TrendPeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                Text("Productivity Trends")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                // Period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(TrendPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else {
                // Summary cards
                HStack(spacing: ClaritySpacing.md) {
                    TrendSummaryCard(
                        title: "Avg Daily Time",
                        value: viewModel.avgActiveTime,
                        trend: viewModel.activeTimeTrend,
                        icon: ClarityIcons.time,
                        color: ClarityColors.accentPrimary
                    )

                    TrendSummaryCard(
                        title: "Avg Focus Score",
                        value: "\(viewModel.avgFocusScore)%",
                        trend: viewModel.focusScoreTrend,
                        icon: "target",
                        color: ClarityColors.deepFocus
                    )

                    TrendSummaryCard(
                        title: "Avg Keystrokes",
                        value: formatNumber(viewModel.avgKeystrokes),
                        trend: viewModel.keystrokesTrend,
                        icon: ClarityIcons.keystrokes,
                        color: ClarityColors.productivity
                    )
                }

                // Main chart
                VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                    Text("Daily Active Time")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)

                    TrendLineChart(
                        data: viewModel.dailyData,
                        color: ClarityColors.accentPrimary
                    )
                    .frame(height: 150)
                }

                // Comparison section
                if let comparison = viewModel.periodComparison {
                    Divider()

                    VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
                        Text("vs Previous \(selectedPeriod.rawValue)")
                            .font(ClarityTypography.captionMedium)
                            .foregroundColor(ClarityColors.textSecondary)

                        HStack(spacing: ClaritySpacing.lg) {
                            ComparisonMetric(
                                label: "Active Time",
                                current: comparison.currentActiveTime,
                                previous: comparison.previousActiveTime,
                                format: .time
                            )

                            ComparisonMetric(
                                label: "Focus Score",
                                current: comparison.currentFocusScore,
                                previous: comparison.previousFocusScore,
                                format: .percentage
                            )

                            ComparisonMetric(
                                label: "Sessions",
                                current: comparison.currentSessions,
                                previous: comparison.previousSessions,
                                format: .number
                            )
                        }
                    }
                }

                // Best day highlight
                if let bestDay = viewModel.bestDay {
                    Divider()

                    HStack(spacing: ClaritySpacing.md) {
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundColor(ClarityColors.warning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Best Day This \(selectedPeriod.rawValue)")
                                .font(ClarityTypography.captionMedium)
                                .foregroundColor(ClarityColors.textSecondary)

                            HStack(spacing: ClaritySpacing.md) {
                                Text(bestDay.date, style: .date)
                                    .font(ClarityTypography.bodyMedium)
                                    .foregroundColor(ClarityColors.textPrimary)

                                Text(formatSeconds(bestDay.activeSeconds))
                                    .font(ClarityTypography.mono)
                                    .foregroundColor(ClarityColors.accentPrimary)

                                Text("\(bestDay.focusScore)% focus")
                                    .font(ClarityTypography.caption)
                                    .foregroundColor(ClarityColors.textTertiary)
                            }
                        }

                        Spacer()
                    }
                }
            }
        }
        .onChange(of: selectedPeriod) { _, _ in
            Task {
                await viewModel.load(period: selectedPeriod)
            }
        }
        .task {
            await viewModel.load(period: selectedPeriod)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Trend Summary Card

struct TrendSummaryCard: View {
    let title: String
    let value: String
    let trend: Double?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Spacer()

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10))
                        Text(String(format: "%.0f%%", abs(trend)))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(trend >= 0 ? ClarityColors.success : ClarityColors.danger)
                }
            }

            Text(value)
                .font(ClarityTypography.title1)
                .foregroundColor(ClarityColors.textPrimary)

            Text(title)
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)
        }
        .padding(ClaritySpacing.md)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(ClarityRadius.md)
    }
}

// MARK: - Trend Line Chart

struct TrendLineChart: View {
    let data: [(date: Date, value: Int)]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if data.isEmpty {
                Text("No data available")
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { _ in
                            Divider()
                                .opacity(0.3)
                            Spacer()
                        }
                    }

                    // Line chart
                    Path { path in
                        guard !data.isEmpty else { return }

                        let maxValue = max(data.map { $0.value }.max() ?? 1, 1)
                        let stepX = geo.size.width / CGFloat(max(data.count - 1, 1))

                        for (index, point) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = geo.size.height - (CGFloat(point.value) / CGFloat(maxValue) * geo.size.height)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Fill gradient
                    Path { path in
                        guard !data.isEmpty else { return }

                        let maxValue = max(data.map { $0.value }.max() ?? 1, 1)
                        let stepX = geo.size.width / CGFloat(max(data.count - 1, 1))

                        path.move(to: CGPoint(x: 0, y: geo.size.height))

                        for (index, point) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = geo.size.height - (CGFloat(point.value) / CGFloat(maxValue) * geo.size.height)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                        let maxValue = max(data.map { $0.value }.max() ?? 1, 1)
                        let stepX = geo.size.width / CGFloat(max(data.count - 1, 1))
                        let x = CGFloat(index) * stepX
                        let y = geo.size.height - (CGFloat(point.value) / CGFloat(maxValue) * geo.size.height)

                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

// MARK: - Comparison Metric

struct ComparisonMetric: View {
    let label: String
    let current: Int
    let previous: Int
    let format: MetricFormat

    enum MetricFormat {
        case time
        case percentage
        case number
    }

    var body: some View {
        VStack(spacing: ClaritySpacing.xs) {
            HStack(spacing: ClaritySpacing.sm) {
                Text(formatValue(current))
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                if previous > 0 {
                    let change = Double(current - previous) / Double(previous) * 100
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                        Text(String(format: "%.0f%%", abs(change)))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(change >= 0 ? ClarityColors.success : ClarityColors.danger)
                }
            }

            Text(label)
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatValue(_ value: Int) -> String {
        switch format {
        case .time:
            let hours = value / 3600
            let minutes = (value % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        case .percentage:
            return "\(value)%"
        case .number:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }
}

// MARK: - View Model

@MainActor
class ProductivityTrendsViewModel: ObservableObject {
    @Published var dailyData: [(date: Date, value: Int)] = []
    @Published var avgActiveTime: String = "0m"
    @Published var avgFocusScore: Int = 0
    @Published var avgKeystrokes: Int = 0
    @Published var activeTimeTrend: Double?
    @Published var focusScoreTrend: Double?
    @Published var keystrokesTrend: Double?
    @Published var periodComparison: PeriodComparison?
    @Published var bestDay: BestDay?
    @Published var isLoading = true

    struct PeriodComparison {
        let currentActiveTime: Int
        let previousActiveTime: Int
        let currentFocusScore: Int
        let previousFocusScore: Int
        let currentSessions: Int
        let previousSessions: Int
    }

    struct BestDay {
        let date: Date
        let activeSeconds: Int
        let focusScore: Int
    }

    private let dataService = DataService.shared

    func load(period: ProductivityTrendsView.TrendPeriod) async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = Date()
        let daysToLoad: Int

        switch period {
        case .week: daysToLoad = 7
        case .month: daysToLoad = 30
        case .quarter: daysToLoad = 90
        }

        var data: [(Date, Int)] = []
        var totalActiveTime = 0
        var totalFocusScore = 0
        var totalKeystrokes = 0
        var daysWithData = 0
        var best: BestDay?

        for dayOffset in (0..<daysToLoad).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            let stats = await dataService.getStats(for: date)
            data.append((date, stats.activeTimeSeconds))

            if stats.activeTimeSeconds > 0 {
                totalActiveTime += stats.activeTimeSeconds
                totalFocusScore += stats.focusScore
                totalKeystrokes += stats.keystrokes
                daysWithData += 1

                if let current = best {
                    if stats.activeTimeSeconds > current.activeSeconds {
                        best = BestDay(date: date, activeSeconds: stats.activeTimeSeconds, focusScore: stats.focusScore)
                    }
                } else {
                    best = BestDay(date: date, activeSeconds: stats.activeTimeSeconds, focusScore: stats.focusScore)
                }
            }
        }

        dailyData = data
        bestDay = best

        if daysWithData > 0 {
            let avgSeconds = totalActiveTime / daysWithData
            let hours = avgSeconds / 3600
            let minutes = (avgSeconds % 3600) / 60
            avgActiveTime = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            avgFocusScore = totalFocusScore / daysWithData
            avgKeystrokes = totalKeystrokes / daysWithData
        }

        // Calculate trends (compare first half to second half)
        if data.count >= 2 {
            let midpoint = data.count / 2
            let firstHalf = data.prefix(midpoint)
            let secondHalf = data.suffix(data.count - midpoint)

            let firstAvg = firstHalf.reduce(0) { $0 + $1.1 } / max(firstHalf.count, 1)
            let secondAvg = secondHalf.reduce(0) { $0 + $1.1 } / max(secondHalf.count, 1)

            if firstAvg > 0 {
                activeTimeTrend = Double(secondAvg - firstAvg) / Double(firstAvg) * 100
            }
        }

        // Calculate period comparison
        await loadPeriodComparison(daysToLoad: daysToLoad)
    }

    private func loadPeriodComparison(daysToLoad: Int) async {
        let calendar = Calendar.current
        let today = Date()

        var currentActiveTime = 0
        var currentFocusScore = 0
        var currentDays = 0

        var previousActiveTime = 0
        var previousFocusScore = 0
        var previousDays = 0

        // Current period
        for dayOffset in 0..<daysToLoad {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let stats = await dataService.getStats(for: date)
            if stats.activeTimeSeconds > 0 {
                currentActiveTime += stats.activeTimeSeconds
                currentFocusScore += stats.focusScore
                currentDays += 1
            }
        }

        // Previous period
        for dayOffset in daysToLoad..<(daysToLoad * 2) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let stats = await dataService.getStats(for: date)
            if stats.activeTimeSeconds > 0 {
                previousActiveTime += stats.activeTimeSeconds
                previousFocusScore += stats.focusScore
                previousDays += 1
            }
        }

        periodComparison = PeriodComparison(
            currentActiveTime: currentActiveTime,
            previousActiveTime: previousActiveTime,
            currentFocusScore: currentDays > 0 ? currentFocusScore / currentDays : 0,
            previousFocusScore: previousDays > 0 ? previousFocusScore / previousDays : 0,
            currentSessions: currentDays,
            previousSessions: previousDays
        )
    }
}

#Preview {
    GlassCard {
        ProductivityTrendsView()
    }
    .padding()
    .frame(width: 600)
}

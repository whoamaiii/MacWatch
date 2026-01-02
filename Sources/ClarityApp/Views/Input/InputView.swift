import SwiftUI
import ClarityShared

/// Input view showing keyboard and mouse analytics
struct InputView: View {
    @StateObject private var viewModel = InputViewModel()
    @State private var selectedPeriod: TimePeriod = .today
    @State private var selectedTab: InputTab = .keyboard

    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    enum InputTab: String, CaseIterable {
        case keyboard = "Keyboard"
        case mouse = "Mouse"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Period selector
                periodSelector

                // Stats overview
                statsOverview

                // Tab selector
                tabSelector

                // Content based on selected tab
                if selectedTab == .keyboard {
                    keyboardContent
                } else {
                    mouseContent
                }
            }
            .padding(ClaritySpacing.lg)
        }
        .background(ClarityColors.backgroundPrimary)
        .task {
            await viewModel.load(period: selectedPeriod)
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task {
                await viewModel.load(period: newPeriod)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text("Input Analytics")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Keyboard and mouse activity")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: ClaritySpacing.xs) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedPeriod = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(selectedPeriod == period ? .white : ClarityColors.textSecondary)
                        .padding(.horizontal, ClaritySpacing.sm)
                        .padding(.vertical, ClaritySpacing.xs)
                        .background(
                            selectedPeriod == period
                                ? ClarityColors.accentPrimary
                                : ClarityColors.backgroundSecondary
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                title: "Keystrokes",
                value: formatNumber(viewModel.totalKeystrokes),
                icon: ClarityIcons.keystrokes,
                color: ClarityColors.accentPrimary
            )

            StatCard(
                title: "Clicks",
                value: formatNumber(viewModel.totalClicks),
                icon: ClarityIcons.clicks,
                color: ClarityColors.deepFocus
            )

            StatCard(
                title: "Scroll Distance",
                value: formatScrollDistance(viewModel.totalScrollDistance),
                icon: "arrow.up.arrow.down",
                color: ClarityColors.communication
            )

            StatCard(
                title: "Mouse Distance",
                value: formatMouseDistance(viewModel.totalMouseDistance),
                icon: "cursorarrow.motionlines",
                color: ClarityColors.productivity
            )
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(InputTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: ClaritySpacing.xs) {
                        Text(tab.rawValue)
                            .font(ClarityTypography.bodyMedium)
                            .foregroundColor(selectedTab == tab ? ClarityColors.accentPrimary : ClarityColors.textSecondary)

                        Rectangle()
                            .fill(selectedTab == tab ? ClarityColors.accentPrimary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, ClaritySpacing.sm)
    }

    // MARK: - Keyboard Content

    private var keyboardContent: some View {
        VStack(spacing: ClaritySpacing.lg) {
            // Keyboard stats
            GlassCard {
                VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                    Text("Keyboard Activity")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    if viewModel.totalKeystrokes == 0 {
                        Text("No keyboard activity recorded yet")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        VStack(spacing: ClaritySpacing.md) {
                            HStack(spacing: ClaritySpacing.xl) {
                                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                    Text("Total Keystrokes")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Text(formatNumber(viewModel.totalKeystrokes))
                                        .font(ClarityTypography.title1)
                                        .foregroundColor(ClarityColors.textPrimary)
                                }

                                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                    Text("Active Time")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Text(viewModel.formattedActiveTime)
                                        .font(ClarityTypography.title1)
                                        .foregroundColor(ClarityColors.textPrimary)
                                }

                                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                    Text("Avg Keys/Min")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Text("\(viewModel.keysPerMinute)")
                                        .font(ClarityTypography.title1)
                                        .foregroundColor(ClarityColors.textPrimary)
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }

            // Keyboard Heatmap
            GlassCard {
                VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                    Text("Key Frequency Heatmap")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text("Visualization of which keys you press most often")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)

                    if viewModel.keycodeFrequency.isEmpty && viewModel.totalKeystrokes == 0 {
                        Text("No keyboard activity recorded yet")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, ClaritySpacing.xl)
                    } else {
                        KeyboardHeatmap(keyData: viewModel.keycodeFrequency)
                    }
                }
            }

            // Hourly breakdown
            GlassCard {
                VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                    Text("Keystrokes by Hour")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    if viewModel.hourlyKeystrokes.isEmpty {
                        Text("No data available")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        HourlyBarChart(data: viewModel.hourlyKeystrokes, color: ClarityColors.accentPrimary)
                            .frame(height: 120)
                    }
                }
            }
        }
    }

    // MARK: - Mouse Content

    private var mouseContent: some View {
        VStack(spacing: ClaritySpacing.lg) {
            // Mouse stats
            GlassCard {
                VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                    Text("Mouse Activity")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    if viewModel.totalClicks == 0 && viewModel.totalScrollDistance == 0 {
                        Text("No mouse activity recorded yet")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        VStack(spacing: ClaritySpacing.md) {
                            HStack(spacing: ClaritySpacing.xl) {
                                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                    Text("Total Clicks")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Text(formatNumber(viewModel.totalClicks))
                                        .font(ClarityTypography.title1)
                                        .foregroundColor(ClarityColors.textPrimary)
                                }

                                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                    Text("Scroll Distance")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Text(formatScrollDistance(viewModel.totalScrollDistance))
                                        .font(ClarityTypography.title1)
                                        .foregroundColor(ClarityColors.textPrimary)
                                }

                                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                                    Text("Mouse Distance")
                                        .font(ClarityTypography.caption)
                                        .foregroundColor(ClarityColors.textTertiary)
                                    Text(formatMouseDistance(viewModel.totalMouseDistance))
                                        .font(ClarityTypography.title1)
                                        .foregroundColor(ClarityColors.textPrimary)
                                }

                                Spacer()
                            }
                        }
                    }
                }
            }

            // Click Heatmap
            GlassCard {
                ClickHeatmapCard(clickPositions: viewModel.clickPositions)
            }

            // Hourly breakdown
            GlassCard {
                VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                    Text("Clicks by Hour")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    if viewModel.hourlyClicks.isEmpty {
                        Text("No data available")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        HourlyBarChart(data: viewModel.hourlyClicks, color: ClarityColors.deepFocus)
                            .frame(height: 120)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func formatScrollDistance(_ pixels: Int) -> String {
        if pixels == 0 { return "0" }
        let meters = Double(pixels) / 3779.5 // pixels to meters (assuming 96 DPI)
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else if meters >= 1 {
            return String(format: "%.0f m", meters)
        }
        return "\(pixels) px"
    }

    private func formatMouseDistance(_ pixels: Int) -> String {
        if pixels == 0 { return "0" }
        let meters = Double(pixels) / 3779.5
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else if meters >= 1 {
            return String(format: "%.0f m", meters)
        }
        return "\(pixels) px"
    }
}

// MARK: - Hourly Bar Chart

struct HourlyBarChart: View {
    let data: [Int: Int]  // Hour -> Count
    var color: Color = ClarityColors.accentPrimary
    var label: String = "activity"
    var formatter: ((Int) -> String)? = nil

    @State private var hoveredHour: Int? = nil

    private let hours = Array(0...23)
    private var maxValue: Int {
        data.values.max() ?? 1
    }

    private var totalValue: Int {
        data.values.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: ClaritySpacing.xs) {
            // Tooltip
            if let hour = hoveredHour, let value = data[hour], value > 0 {
                HStack(spacing: ClaritySpacing.sm) {
                    Text(formatHour(hour))
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)

                    Text(formatValue(value))
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textPrimary)

                    if totalValue > 0 {
                        Text("(\(Int(Double(value) / Double(totalValue) * 100))%)")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                }
                .padding(.horizontal, ClaritySpacing.sm)
                .padding(.vertical, ClaritySpacing.xxs)
                .background(ClarityColors.backgroundSecondary)
                .cornerRadius(ClarityRadius.sm)
            } else {
                // Placeholder to maintain layout
                Text(" ")
                    .font(ClarityTypography.caption)
                    .padding(.vertical, ClaritySpacing.xxs)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(hours, id: \.self) { hour in
                    HourlyBar(
                        hour: hour,
                        value: data[hour] ?? 0,
                        maxValue: maxValue,
                        color: color,
                        isCurrentHour: hour == Calendar.current.component(.hour, from: Date()),
                        isHovered: hoveredHour == hour
                    )
                    .onHover { hovering in
                        hoveredHour = hovering ? hour : nil
                    }
                }
            }
            .frame(height: 80)

            HStack(spacing: 4) {
                ForEach(hours, id: \.self) { hour in
                    Text(hour % 6 == 0 ? formatHourShort(hour) : "")
                        .font(.system(size: 9))
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour):00"
        }
        return formatter.string(from: date)
    }

    private func formatHourShort(_ hour: Int) -> String {
        if hour == 0 { return "12a" }
        if hour < 12 { return "\(hour)a" }
        if hour == 12 { return "12p" }
        return "\(hour - 12)p"
    }

    private func formatValue(_ value: Int) -> String {
        if let formatter = formatter {
            return formatter(value)
        }
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private struct HourlyBar: View {
    let hour: Int
    let value: Int
    let maxValue: Int
    let color: Color
    let isCurrentHour: Bool
    let isHovered: Bool

    private var barHeight: CGFloat {
        guard maxValue > 0 else { return 4 }
        let percentage = CGFloat(value) / CGFloat(maxValue)
        return max(4, percentage * 80)
    }

    private var barColor: Color {
        if value == 0 {
            return ClarityColors.textQuaternary.opacity(0.3)
        } else if isCurrentHour {
            return color
        } else {
            return color.opacity(0.7)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .scaleEffect(x: isHovered ? 1.1 : 1.0, y: isHovered ? 1.05 : 1.0, anchor: .bottom)
            .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - ViewModel

@MainActor
class InputViewModel: ObservableObject {
    @Published var totalKeystrokes: Int = 0
    @Published var totalClicks: Int = 0
    @Published var totalScrollDistance: Int = 0
    @Published var totalMouseDistance: Int = 0
    @Published var totalActiveSeconds: Int = 0
    @Published var hourlyKeystrokes: [Int: Int] = [:]
    @Published var hourlyClicks: [Int: Int] = [:]
    @Published var keycodeFrequency: [Int: Int] = [:]
    @Published var clickPositions: [[Int]] = []
    @Published var isLoading = true

    private let dataService = DataService.shared

    var formattedActiveTime: String {
        let hours = totalActiveSeconds / 3600
        let minutes = (totalActiveSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var keysPerMinute: Int {
        guard totalActiveSeconds > 0 else { return 0 }
        let minutes = max(1, totalActiveSeconds / 60)
        return totalKeystrokes / minutes
    }

    func load(period: InputView.TimePeriod) async {
        isLoading = true
        defer { isLoading = false }

        let (startDate, endDate) = getDateRange(for: period)

        // Get stats from data service
        let stats = await dataService.getStats(from: startDate, to: endDate)
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks
        totalScrollDistance = stats.scrollDistance
        totalMouseDistance = stats.mouseDistance
        totalActiveSeconds = stats.activeTimeSeconds

        // Get hourly breakdowns
        hourlyKeystrokes = await dataService.getHourlyKeystrokeBreakdown(from: startDate, to: endDate)
        hourlyClicks = await dataService.getHourlyClickBreakdown(from: startDate, to: endDate)

        // Get keycode frequency for heatmap
        keycodeFrequency = await dataService.getKeycodeFrequency(from: startDate, to: endDate)

        // Get click positions for heatmap
        clickPositions = await dataService.getClickPositions(from: startDate, to: endDate)
    }

    private func getDateRange(for period: InputView.TimePeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (calendar.startOfDay(for: weekAgo), now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (calendar.startOfDay(for: monthAgo), now)
        }
    }
}

#Preview {
    InputView()
        .frame(width: 900, height: 700)
}

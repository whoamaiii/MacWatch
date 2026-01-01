import SwiftUI
import ClarityShared
import AppKit
import IOKit.ps

/// System view showing resource usage and hardware metrics
struct SystemView: View {
    @StateObject private var viewModel = SystemViewModel()
    @State private var selectedPeriod: TimePeriod = .today

    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
                // Header
                header

                // Period selector
                periodSelector

                // Real-time stats
                realTimeStats

                // Screen time by app
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Screen Time by App")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        if viewModel.topApps.isEmpty {
                            Text("No activity recorded yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            screenTimeList
                        }
                    }
                }

                HStack(spacing: ClaritySpacing.md) {
                    // Battery status
                    GlassCard {
                        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                            Text("Battery")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)

                            batteryStatus
                        }
                    }

                    // Session info
                    GlassCard {
                        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                            Text("Session Info")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)

                            sessionInfo
                        }
                    }
                }

                // Database stats
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        Text("Clarity Database")
                            .font(ClarityTypography.title2)
                            .foregroundColor(ClarityColors.textPrimary)

                        databaseStats
                    }
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
                Text("System")
                    .font(ClarityTypography.displayMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                Text("Resource usage and session info")
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

    // MARK: - Real-time Stats

    private var realTimeStats: some View {
        HStack(spacing: ClaritySpacing.md) {
            StatCard(
                title: "Active Time",
                value: viewModel.formattedActiveTime,
                icon: ClarityIcons.time,
                color: ClarityColors.accentPrimary
            )

            StatCard(
                title: "Apps Used",
                value: "\(viewModel.appsUsed)",
                icon: "app.badge",
                color: ClarityColors.deepFocus
            )

            StatCard(
                title: "Keystrokes",
                value: formatNumber(viewModel.totalKeystrokes),
                icon: ClarityIcons.keystrokes,
                color: ClarityColors.communication
            )

            StatCard(
                title: "Clicks",
                value: formatNumber(viewModel.totalClicks),
                icon: ClarityIcons.clicks,
                color: ClarityColors.productivity
            )
        }
    }

    // MARK: - Screen Time List

    private var screenTimeList: some View {
        VStack(spacing: ClaritySpacing.sm) {
            ForEach(viewModel.topApps) { app in
                HStack(spacing: ClaritySpacing.md) {
                    // App icon
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .cornerRadius(6)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(app.color.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(app.color)
                            }
                    }

                    Text(app.name)
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textPrimary)
                        .frame(width: 120, alignment: .leading)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ClarityColors.backgroundSecondary)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(app.color)
                                .frame(width: geo.size.width * app.percentage)
                        }
                    }
                    .frame(height: 8)

                    Text(app.duration)
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textSecondary)
                        .frame(width: 70, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Battery Status

    private var batteryStatus: some View {
        VStack(spacing: ClaritySpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Level")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)

                    HStack(spacing: ClaritySpacing.xs) {
                        Image(systemName: viewModel.batteryIcon)
                            .font(.system(size: 20))
                            .foregroundColor(viewModel.batteryColor)

                        Text("\(viewModel.batteryLevel)%")
                            .font(ClarityTypography.title1)
                            .foregroundColor(ClarityColors.textPrimary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: ClaritySpacing.xxs) {
                    Text("Status")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)

                    Text(viewModel.batteryStatus)
                        .font(ClarityTypography.bodyMedium)
                        .foregroundColor(viewModel.isCharging ? ClarityColors.success : ClarityColors.textPrimary)
                }
            }

            if viewModel.isOnBattery {
                Divider()

                HStack {
                    Text("Remaining")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)

                    Spacer()

                    Text(viewModel.timeRemaining)
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Session Info

    private var sessionInfo: some View {
        VStack(spacing: ClaritySpacing.md) {
            sessionRow(label: "Session Start", value: viewModel.sessionStart)
            sessionRow(label: "Total Active", value: viewModel.formattedActiveTime)
            sessionRow(label: "Focus Score", value: "\(viewModel.focusScore)%")

            Divider()

            sessionRow(label: "System Uptime", value: viewModel.systemUptime)
        }
    }

    private func sessionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textSecondary)

            Spacer()

            Text(value)
                .font(ClarityTypography.mono)
                .foregroundColor(ClarityColors.textPrimary)
        }
    }

    // MARK: - Database Stats

    private var databaseStats: some View {
        VStack(spacing: ClaritySpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Database Size")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text(viewModel.databaseSize)
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: ClaritySpacing.xxs) {
                    Text("Location")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text("~/Library/Application Support/Clarity")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack(spacing: ClaritySpacing.xl) {
                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Tracked Apps")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text("\(viewModel.totalTrackedApps)")
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Data Points")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    Text(formatNumber(viewModel.totalDataPoints))
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textPrimary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - ViewModel

@MainActor
class SystemViewModel: ObservableObject {
    @Published var totalActiveSeconds: Int = 0
    @Published var totalKeystrokes: Int = 0
    @Published var totalClicks: Int = 0
    @Published var appsUsed: Int = 0
    @Published var focusScore: Int = 0
    @Published var topApps: [DataService.AppUsageDisplay] = []

    // Battery
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var isOnBattery: Bool = false
    @Published var timeRemaining: String = "—"

    // Database
    @Published var databaseSize: String = "0 KB"
    @Published var totalTrackedApps: Int = 0
    @Published var totalDataPoints: Int = 0

    private let dataService = DataService.shared

    var formattedActiveTime: String {
        let hours = totalActiveSeconds / 3600
        let minutes = (totalActiveSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var sessionStart: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Calendar.current.startOfDay(for: Date()))
    }

    var systemUptime: String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var batteryIcon: String {
        if isCharging {
            return "battery.100.bolt"
        }
        switch batteryLevel {
        case 0...10: return "battery.0"
        case 11...25: return "battery.25"
        case 26...50: return "battery.50"
        case 51...75: return "battery.75"
        default: return "battery.100"
        }
    }

    var batteryColor: Color {
        if isCharging { return ClarityColors.success }
        if batteryLevel <= 20 { return ClarityColors.danger }
        return ClarityColors.success
    }

    var batteryStatus: String {
        if isCharging { return "Charging" }
        if !isOnBattery { return "Power Adapter" }
        return "On Battery"
    }

    func load(period: SystemView.TimePeriod) async {
        let (startDate, _) = getDateRange(for: period)

        // Get stats from data service
        let stats = await dataService.getStats(for: startDate)
        totalActiveSeconds = stats.activeTimeSeconds
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks
        focusScore = stats.focusScore

        // Get top apps
        topApps = await dataService.getTopApps(for: startDate, limit: 5)
        appsUsed = topApps.count

        // Get battery info
        updateBatteryInfo()

        // Get database stats
        updateDatabaseStats()
    }

    private func getDateRange(for period: SystemView.TimePeriod) -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .today:
            return (calendar.startOfDay(for: now), now)
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return (weekAgo, now)
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return (monthAgo, now)
        }
    }

    private func updateBatteryInfo() {
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
           let source = sources.first,
           let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {

            batteryLevel = info[kIOPSCurrentCapacityKey] as? Int ?? 100
            isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
            isOnBattery = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue

            if let timeToEmpty = info[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0 {
                let hours = timeToEmpty / 60
                let minutes = timeToEmpty % 60
                timeRemaining = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
            } else if let timeToFull = info[kIOPSTimeToFullChargeKey] as? Int, timeToFull > 0 {
                let hours = timeToFull / 60
                let minutes = timeToFull % 60
                timeRemaining = "\(hours)h \(minutes)m to full"
            } else {
                timeRemaining = "Calculating..."
            }
        }
    }

    private func updateDatabaseStats() {
        let dbManager = DatabaseManager.shared
        let sizeBytes = dbManager.databaseSize()

        if sizeBytes >= 1_000_000_000 {
            databaseSize = String(format: "%.1f GB", Double(sizeBytes) / 1_000_000_000)
        } else if sizeBytes >= 1_000_000 {
            databaseSize = String(format: "%.1f MB", Double(sizeBytes) / 1_000_000)
        } else if sizeBytes >= 1_000 {
            databaseSize = String(format: "%.1f KB", Double(sizeBytes) / 1_000)
        } else {
            databaseSize = "\(sizeBytes) bytes"
        }

        // Count tracked apps
        do {
            let apps = try AppRepository().getAll()
            totalTrackedApps = apps.count
        } catch {
            totalTrackedApps = 0
        }

        // Estimate data points (minute stats count)
        do {
            let stats = try StatsRepository().getMinuteStats(
                from: Calendar.current.date(byAdding: .year, value: -1, to: Date())!,
                to: Date()
            )
            totalDataPoints = stats.count
        } catch {
            totalDataPoints = 0
        }
    }
}

#Preview {
    SystemView()
        .frame(width: 900, height: 800)
}

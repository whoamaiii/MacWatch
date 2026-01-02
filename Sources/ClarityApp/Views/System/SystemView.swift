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

                // Process metrics (CPU/Memory)
                GlassCard {
                    VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                        HStack {
                            Text("Process Metrics")
                                .font(ClarityTypography.title2)
                                .foregroundColor(ClarityColors.textPrimary)

                            Spacer()

                            Text("Latest snapshot")
                                .font(ClarityTypography.caption)
                                .foregroundColor(ClarityColors.textTertiary)
                        }

                        if viewModel.processMetrics.isEmpty {
                            Text("No process metrics recorded yet")
                                .font(ClarityTypography.body)
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            processMetricsList
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

    // MARK: - Process Metrics List

    private var processMetricsList: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: ClaritySpacing.md) {
                Text("App")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(width: 160, alignment: .leading)

                Text("CPU")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(width: 80, alignment: .trailing)

                Text("Memory")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(width: 80, alignment: .trailing)

                Spacer()
            }
            .padding(.bottom, ClaritySpacing.xs)

            Divider()
                .padding(.bottom, ClaritySpacing.xs)

            ForEach(viewModel.processMetrics.prefix(8), id: \.pid) { metric in
                HStack(spacing: ClaritySpacing.md) {
                    // App icon and name
                    HStack(spacing: ClaritySpacing.sm) {
                        Group {
                            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: metric.bundleId) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                            } else {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(ClarityColors.textTertiary)
                                    .frame(width: 20, height: 20)
                            }
                        }

                        Text(metric.name)
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)
                            .lineLimit(1)
                    }
                    .frame(width: 160, alignment: .leading)

                    // CPU bar
                    HStack(spacing: ClaritySpacing.xs) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(ClarityColors.backgroundSecondary)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cpuColor(for: metric.cpuPercent))
                                    .frame(width: geo.size.width * min(metric.cpuPercent / 100, 1.0))
                            }
                        }
                        .frame(width: 40, height: 6)

                        Text(String(format: "%.1f%%", metric.cpuPercent))
                            .font(ClarityTypography.mono)
                            .foregroundColor(cpuColor(for: metric.cpuPercent))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)

                    // Memory
                    Text(formatMemory(metric.memoryMB))
                        .font(ClarityTypography.mono)
                        .foregroundColor(ClarityColors.textSecondary)
                        .frame(width: 80, alignment: .trailing)

                    Spacer()
                }
                .padding(.vertical, ClaritySpacing.xxs)
            }
        }
    }

    private func cpuColor(for cpu: Double) -> Color {
        switch cpu {
        case 0..<25: return ClarityColors.success
        case 25..<50: return ClarityColors.warning
        default: return ClarityColors.danger
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
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
    @Published var sessionStartDate: Date?

    // Battery
    @Published var batteryLevel: Int = 100
    @Published var isCharging: Bool = false
    @Published var isOnBattery: Bool = false
    @Published var timeRemaining: String = "—"

    // Database
    @Published var databaseSize: String = "0 KB"
    @Published var totalTrackedApps: Int = 0
    @Published var totalDataPoints: Int = 0

    // Process metrics
    @Published var processMetrics: [ProcessMetric] = []

    private let dataService = DataService.shared
    private let db = DatabaseManager.shared

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
        if let sessionStartDate {
            return formatter.string(from: sessionStartDate)
        }
        return "—"
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
        let (startDate, endDate) = getDateRange(for: period)

        // Get stats from data service
        let stats = await dataService.getStats(from: startDate, to: endDate)
        totalActiveSeconds = stats.activeTimeSeconds
        totalKeystrokes = stats.keystrokes
        totalClicks = stats.clicks
        focusScore = stats.focusScore

        // Get top apps
        topApps = await dataService.getTopApps(from: startDate, to: endDate, limit: 5)
        appsUsed = await dataService.getUniqueAppCount(from: startDate, to: endDate)

        sessionStartDate = await dataService.getFirstActivityDate(from: startDate, to: endDate)

        // Get battery info
        updateBatteryInfo()

        // Get database stats
        updateDatabaseStats()

        // Get latest process metrics
        loadProcessMetrics()
    }

    private func loadProcessMetrics() {
        do {
            // Get the most recent process metrics event using SQL
            let events: [RawEvent] = try db.read { db in
                try RawEvent.fetchAll(db, sql: """
                    SELECT * FROM raw_events
                    WHERE eventType = ?
                    ORDER BY timestamp DESC
                    LIMIT 1
                """, arguments: [EventType.processMetrics.rawValue])
            }

            if let event = events.first,
               let data = event.decode(ProcessMetricsEventData.self) {
                processMetrics = data.processes
            }
        } catch {
            // Silently fail - will show empty process list
        }
    }

    private func getDateRange(for period: SystemView.TimePeriod) -> (Date, Date) {
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
            let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            totalDataPoints = try StatsRepository().getMinuteStatsCount(from: yearAgo, to: Date())
        } catch {
            totalDataPoints = 0
        }
    }
}

#Preview {
    SystemView()
        .frame(width: 900, height: 800)
}

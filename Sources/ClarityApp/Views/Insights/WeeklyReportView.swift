import SwiftUI
import ClarityShared

/// View for displaying and exporting weekly productivity reports
struct WeeklyReportView: View {
    @ObservedObject private var reportService = WeeklyReportService.shared  // Singleton - use @ObservedObject
    @State private var selectedWeekOffset = 0

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header with week navigation
            HStack {
                Button {
                    selectedWeekOffset -= 1
                    Task { await loadReport() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text("Weekly Report")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    if let report = reportService.currentReport {
                        Text(weekRangeString(report))
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                }

                Spacer()

                Button {
                    if selectedWeekOffset < 0 {
                        selectedWeekOffset += 1
                        Task { await loadReport() }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(selectedWeekOffset < 0 ? ClarityColors.textTertiary : ClarityColors.textTertiary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(selectedWeekOffset >= 0)
            }

            if reportService.isGenerating {
                HStack {
                    Spacer()
                    VStack(spacing: ClaritySpacing.md) {
                        ProgressView()
                        Text("Generating report...")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                    Spacer()
                }
                .padding()
            } else if let report = reportService.currentReport {
                ScrollView {
                    VStack(spacing: ClaritySpacing.lg) {
                        // Summary stats
                        reportSummary(report)

                        Divider()

                        // Daily chart
                        dailyChart(report)

                        Divider()

                        // Top apps
                        topAppsSection(report)

                        Divider()

                        // Insights
                        insightsSection(report)

                        // Recommendations
                        if !report.recommendations.isEmpty {
                            Divider()
                            recommendationsSection(report)
                        }

                        // Export button
                        exportSection(report)
                    }
                }
            } else {
                Text("No report available")
                    .font(ClarityTypography.body)
                    .foregroundColor(ClarityColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .task {
            await loadReport()
        }
    }

    // MARK: - Report Sections

    private func reportSummary(_ report: WeeklyReportService.WeeklyReport) -> some View {
        HStack(spacing: ClaritySpacing.lg) {
            SummaryStatView(
                label: "Total Time",
                value: report.formattedTotalTime,
                change: report.activeTimeChange,
                icon: ClarityIcons.time,
                color: ClarityColors.accentPrimary
            )

            SummaryStatView(
                label: "Avg Focus",
                value: "\(report.avgFocusScore)%",
                change: report.focusScoreChange,
                icon: "target",
                color: ClarityColors.deepFocus
            )

            SummaryStatView(
                label: "Days Active",
                value: "\(report.daysActive)/7",
                change: nil,
                icon: "calendar",
                color: ClarityColors.success
            )

            SummaryStatView(
                label: "Focus Sessions",
                value: "\(report.focusSessions)",
                change: nil,
                icon: "brain.head.profile",
                color: ClarityColors.productivity
            )
        }
    }

    private func dailyChart(_ report: WeeklyReportService.WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            Text("Daily Activity")
                .font(ClarityTypography.captionMedium)
                .foregroundColor(ClarityColors.textSecondary)

            HStack(alignment: .bottom, spacing: ClaritySpacing.sm) {
                ForEach(report.dailyStats, id: \.0) { day in
                    VStack(spacing: 4) {
                        // Bar
                        let maxSeconds = report.dailyStats.map { $0.1 }.max() ?? 1
                        let height = CGFloat(day.1) / CGFloat(max(maxSeconds, 1)) * 100

                        RoundedRectangle(cornerRadius: 4)
                            .fill(day.1 > 0 ? ClarityColors.accentPrimary : ClarityColors.backgroundSecondary)
                            .frame(height: max(height, 4))

                        // Day label
                        Text(dayOfWeek(day.0))
                            .font(.system(size: 10))
                            .foregroundColor(ClarityColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
        }
    }

    private func topAppsSection(_ report: WeeklyReportService.WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            Text("Top Apps")
                .font(ClarityTypography.captionMedium)
                .foregroundColor(ClarityColors.textSecondary)

            VStack(spacing: ClaritySpacing.xs) {
                ForEach(Array(report.topApps.enumerated()), id: \.0) { index, app in
                    HStack {
                        Text("\(index + 1).")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(width: 20)

                        Text(app.0)
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)

                        Spacer()

                        Text(formatSeconds(app.1))
                            .font(ClarityTypography.mono)
                            .foregroundColor(ClarityColors.textSecondary)

                        Text("(\(String(format: "%.0f", app.2 * 100))%)")
                            .font(ClarityTypography.caption)
                            .foregroundColor(ClarityColors.textTertiary)
                            .frame(width: 40)
                    }
                }
            }
        }
    }

    private func insightsSection(_ report: WeeklyReportService.WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            Text("Insights")
                .font(ClarityTypography.captionMedium)
                .foregroundColor(ClarityColors.textSecondary)

            HStack(spacing: ClaritySpacing.lg) {
                if let best = report.mostProductiveDay {
                    InsightCard(
                        icon: "arrow.up.circle.fill",
                        color: ClarityColors.success,
                        title: "Most Productive",
                        value: dayOfWeek(best.0),
                        detail: formatSeconds(best.1)
                    )
                }

                if let least = report.leastProductiveDay, report.leastProductiveDay?.1 != report.mostProductiveDay?.1 {
                    InsightCard(
                        icon: "arrow.down.circle.fill",
                        color: ClarityColors.warning,
                        title: "Least Productive",
                        value: dayOfWeek(least.0),
                        detail: formatSeconds(least.1)
                    )
                }

                if !report.peakHours.isEmpty {
                    let peakStr = report.peakHours.prefix(2).map { formatHour($0) }.joined(separator: ", ")
                    InsightCard(
                        icon: "clock.fill",
                        color: ClarityColors.accentPrimary,
                        title: "Peak Hours",
                        value: peakStr,
                        detail: "Most active"
                    )
                }
            }
        }
    }

    private func recommendationsSection(_ report: WeeklyReportService.WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(ClarityColors.warning)
                Text("Recommendations")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                ForEach(report.recommendations, id: \.self) { rec in
                    HStack(alignment: .top, spacing: ClaritySpacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(ClarityColors.success)
                            .padding(.top, 2)

                        Text(rec)
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textSecondary)
                    }
                }
            }
        }
    }

    private func exportSection(_ report: WeeklyReportService.WeeklyReport) -> some View {
        HStack {
            Spacer()

            Button {
                exportReport(report)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Report")
                }
                .font(ClarityTypography.bodyMedium)
            }
            .buttonStyle(.borderedProminent)
            .tint(ClarityColors.accentPrimary)

            Button {
                copyToClipboard(report)
            } label: {
                HStack {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                }
                .font(ClarityTypography.bodyMedium)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, ClaritySpacing.md)
    }

    // MARK: - Helpers

    private func loadReport() async {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: Date()) else { return }
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))
        _ = await reportService.generateReport(for: startOfWeek)
    }

    private func weekRangeString(_ report: WeeklyReportService.WeeklyReport) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: report.weekStartDate)) - \(formatter.string(from: report.weekEndDate))"
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12AM" }
        if hour < 12 { return "\(hour)AM" }
        if hour == 12 { return "12PM" }
        return "\(hour - 12)PM"
    }

    private func exportReport(_ report: WeeklyReportService.WeeklyReport) {
        let text = reportService.exportReportAsText(report)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Clarity-Weekly-Report-\(ISO8601DateFormatter().string(from: report.weekStartDate)).txt"

        if panel.runModal() == .OK, let url = panel.url {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func copyToClipboard(_ report: WeeklyReportService.WeeklyReport) {
        let text = reportService.exportReportAsText(report)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Summary Stat View

struct SummaryStatView: View {
    let label: String
    let value: String
    let change: Double?
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: ClaritySpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(ClarityTypography.title1)
                .foregroundColor(ClarityColors.textPrimary)

            if let change = change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10))
                    Text(String(format: "%.0f%%", abs(change)))
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(change >= 0 ? ClarityColors.success : ClarityColors.danger)
            }

            Text(label)
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(spacing: ClaritySpacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)

            Text(value)
                .font(ClarityTypography.bodyMedium)
                .foregroundColor(ClarityColors.textPrimary)

            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(ClarityColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(ClaritySpacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(ClarityRadius.md)
    }
}

#Preview {
    GlassCard {
        WeeklyReportView()
    }
    .padding()
    .frame(width: 600)
}

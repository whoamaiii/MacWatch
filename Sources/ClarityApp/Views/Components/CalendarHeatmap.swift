import SwiftUI
import ClarityShared

/// A calendar-style heatmap showing productivity intensity over time
struct CalendarHeatmap: View {
    let data: [Date: Int] // Date -> activity level (0-100)
    let weeks: Int
    let metric: HeatmapMetric

    @State private var hoveredDate: Date?
    @State private var hoveredValue: Int?

    enum HeatmapMetric: String, CaseIterable {
        case activeTime = "Active Time"
        case focusScore = "Focus Score"
        case keystrokes = "Keystrokes"

        var unit: String {
            switch self {
            case .activeTime: return "hrs"
            case .focusScore: return "%"
            case .keystrokes: return "k"
            }
        }
    }

    init(data: [Date: Int], weeks: Int = 12, metric: HeatmapMetric = .activeTime) {
        self.data = data
        self.weeks = weeks
        self.metric = metric
    }

    private let calendar = Calendar.current
    private let daySize: CGFloat = 14
    private let daySpacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Month labels
            HStack(spacing: 0) {
                ForEach(monthLabels, id: \.offset) { month in
                    Text(month.name)
                        .font(.system(size: 10))
                        .foregroundColor(ClarityColors.textTertiary)
                        .frame(width: CGFloat(month.weeks) * (daySize + daySpacing), alignment: .leading)
                }
            }
            .padding(.leading, 24) // Align with grid

            HStack(alignment: .top, spacing: daySpacing) {
                // Day labels
                VStack(spacing: daySpacing) {
                    ForEach(0..<7, id: \.self) { day in
                        if day % 2 == 1 {
                            Text(dayLabel(for: day))
                                .font(.system(size: 9))
                                .foregroundColor(ClarityColors.textTertiary)
                                .frame(width: 20, height: daySize)
                        } else {
                            Text("")
                                .frame(width: 20, height: daySize)
                        }
                    }
                }

                // Heatmap grid
                HStack(spacing: daySpacing) {
                    ForEach(0..<weeks, id: \.self) { week in
                        VStack(spacing: daySpacing) {
                            ForEach(0..<7, id: \.self) { day in
                                let date = dateFor(week: week, day: day)
                                if let date = date, date <= Date() {
                                    DayCell(
                                        date: date,
                                        value: data[calendar.startOfDay(for: date)] ?? 0,
                                        isHovered: hoveredDate == date,
                                        metric: metric
                                    )
                                    .onHover { isHovered in
                                        if isHovered {
                                            hoveredDate = date
                                            hoveredValue = data[calendar.startOfDay(for: date)]
                                        } else if hoveredDate == date {
                                            hoveredDate = nil
                                            hoveredValue = nil
                                        }
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.clear)
                                        .frame(width: daySize, height: daySize)
                                }
                            }
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: ClaritySpacing.md) {
                Text("Less")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)

                HStack(spacing: 2) {
                    ForEach([0, 25, 50, 75, 100], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(colorForLevel(level))
                            .frame(width: 12, height: 12)
                    }
                }

                Text("More")
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)

                Spacer()

                // Tooltip
                if let date = hoveredDate {
                    HStack(spacing: ClaritySpacing.xs) {
                        Text(formatDate(date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ClarityColors.textPrimary)

                        if let value = hoveredValue {
                            Text(formatValue(value))
                                .font(.system(size: 11))
                                .foregroundColor(ClarityColors.textSecondary)
                        } else {
                            Text("No data")
                                .font(.system(size: 11))
                                .foregroundColor(ClarityColors.textTertiary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ClarityColors.backgroundSecondary)
                    .cornerRadius(ClarityRadius.sm)
                }
            }
        }
    }

    // MARK: - Helpers

    private var monthLabels: [(name: String, weeks: Int, offset: Int)] {
        var labels: [(name: String, weeks: Int, offset: Int)] = []
        var currentMonth: Int?
        var weekCount = 0
        var startOffset = 0

        for week in 0..<weeks {
            if let date = dateFor(week: week, day: 0) {
                let month = calendar.component(.month, from: date)
                if month != currentMonth {
                    if let current = currentMonth {
                        labels.append((monthName(current), weekCount, startOffset))
                    }
                    currentMonth = month
                    weekCount = 1
                    startOffset = week
                } else {
                    weekCount += 1
                }
            }
        }

        if let current = currentMonth {
            labels.append((monthName(current), weekCount, startOffset))
        }

        return labels
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var components = DateComponents()
        components.month = month
        if let date = calendar.date(from: components) {
            return formatter.string(from: date)
        }
        return ""
    }

    private func dayLabel(for day: Int) -> String {
        ["S", "M", "T", "W", "T", "F", "S"][day]
    }

    private func dateFor(week: Int, day: Int) -> Date? {
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)
        let weeksAgo = weeks - 1 - week

        guard let startOfWeek = calendar.date(byAdding: .day, value: -(todayWeekday - 1) - (weeksAgo * 7), to: today) else {
            return nil
        }

        return calendar.date(byAdding: .day, value: day, to: startOfWeek)
    }

    private func colorForLevel(_ level: Int) -> Color {
        if level == 0 {
            return ClarityColors.backgroundSecondary
        } else if level < 25 {
            return ClarityColors.accentPrimary.opacity(0.25)
        } else if level < 50 {
            return ClarityColors.accentPrimary.opacity(0.5)
        } else if level < 75 {
            return ClarityColors.accentPrimary.opacity(0.75)
        } else {
            return ClarityColors.accentPrimary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatValue(_ value: Int) -> String {
        switch metric {
        case .activeTime:
            let hours = value / 60
            let mins = value % 60
            return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
        case .focusScore:
            return "\(value)%"
        case .keystrokes:
            return "\(value / 1000)k"
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let value: Int
    let isHovered: Bool
    let metric: CalendarHeatmap.HeatmapMetric

    private var normalizedValue: Int {
        switch metric {
        case .activeTime:
            // Normalize to 0-100 based on 8 hours = 100%
            return min(100, (value * 100) / 480)
        case .focusScore:
            return value
        case .keystrokes:
            // Normalize to 0-100 based on 10k keystrokes = 100%
            return min(100, (value * 100) / 10000)
        }
    }

    private var color: Color {
        if value == 0 {
            return ClarityColors.backgroundSecondary
        } else if normalizedValue < 25 {
            return ClarityColors.accentPrimary.opacity(0.25)
        } else if normalizedValue < 50 {
            return ClarityColors.accentPrimary.opacity(0.5)
        } else if normalizedValue < 75 {
            return ClarityColors.accentPrimary.opacity(0.75)
        } else {
            return ClarityColors.accentPrimary
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isHovered ? ClarityColors.textPrimary : Color.clear, lineWidth: 1)
            )
    }
}

// MARK: - Calendar Heatmap View Model

@MainActor
class CalendarHeatmapViewModel: ObservableObject {
    @Published var activeTimeData: [Date: Int] = [:]
    @Published var focusScoreData: [Date: Int] = [:]
    @Published var keystrokesData: [Date: Int] = [:]
    @Published var isLoading = true

    private let dataService = DataService.shared
    private let calendar = Calendar.current

    func load(weeks: Int = 12) async {
        isLoading = true
        defer { isLoading = false }

        let today = Date()
        let daysToLoad = weeks * 7

        for dayOffset in 0..<daysToLoad {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let startOfDay = calendar.startOfDay(for: date)

            let stats = await dataService.getStats(for: date)

            activeTimeData[startOfDay] = stats.activeTimeSeconds / 60 // Convert to minutes
            focusScoreData[startOfDay] = stats.focusScore
            keystrokesData[startOfDay] = stats.keystrokes
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CalendarHeatmap(
            data: Dictionary(uniqueKeysWithValues: (0..<84).compactMap { day in
                guard let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) else { return nil }
                return (Calendar.current.startOfDay(for: date), Int.random(in: 0...100))
            }),
            weeks: 12,
            metric: .activeTime
        )
    }
    .padding()
    .frame(width: 600)
}

import SwiftUI

/// 24-hour activity timeline visualization
public struct TimelineRibbon: View {
    let segments: [TimelineSegment]
    var onSegmentTap: ((TimelineSegment) -> Void)?

    @State private var hoveredSegment: TimelineSegment?

    public var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.sm) {
            // Time labels
            HStack {
                ForEach([6, 9, 12, 15, 18, 21], id: \.self) { hour in
                    Text(formatHour(hour))
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                    if hour != 21 { Spacer() }
                }
            }

            // Activity bar
            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(segments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: segmentWidth(segment, totalWidth: geometry.size.width))
                            .opacity(hoveredSegment?.id == segment.id ? 1 : 0.85)
                            .scaleEffect(y: hoveredSegment?.id == segment.id ? 1.15 : 1)
                            .onHover { isHovered in
                                withAnimation(ClarityAnimations.micro) {
                                    hoveredSegment = isHovered ? segment : nil
                                }
                            }
                            .onTapGesture {
                                onSegmentTap?(segment)
                            }
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                // Now indicator
                GeometryReader { geometry in
                    let nowPosition = currentTimePosition(totalWidth: geometry.size.width)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .offset(x: nowPosition)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }

            // Hover tooltip
            if let segment = hoveredSegment {
                SegmentTooltip(segment: segment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.locale = Locale(identifier: "en_US_POSIX")  // Consistent AM/PM format
        guard let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) else {
            return "\(hour % 12 == 0 ? 12 : hour % 12)\(hour < 12 ? "am" : "pm")"
        }
        return formatter.string(from: date).lowercased()
    }

    private func segmentWidth(_ segment: TimelineSegment, totalWidth: CGFloat) -> CGFloat {
        let totalDaySeconds: CGFloat = 24 * 60 * 60
        let segmentSeconds = CGFloat(segment.durationSeconds)
        return max(2, (segmentSeconds / totalDaySeconds) * totalWidth)
    }

    private func currentTimePosition(totalWidth: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let secondsSinceStart = now.timeIntervalSince(startOfDay)
        let totalDaySeconds: CGFloat = 24 * 60 * 60
        return (CGFloat(secondsSinceStart) / totalDaySeconds) * totalWidth
    }
}

// MARK: - Timeline Segment

public struct TimelineSegment: Identifiable {
    public let id: UUID
    public let appName: String
    public let startTime: Date
    public let durationSeconds: Int
    public let color: Color
    public let keystrokes: Int
    public let clicks: Int

    public init(
        id: UUID = UUID(),
        appName: String,
        startTime: Date,
        durationSeconds: Int,
        color: Color,
        keystrokes: Int = 0,
        clicks: Int = 0
    ) {
        self.id = id
        self.appName = appName
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.color = color
        self.keystrokes = keystrokes
        self.clicks = clicks
    }

    public var formattedDuration: String {
        let minutes = durationSeconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    public var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let endTime = startTime.addingTimeInterval(TimeInterval(durationSeconds))
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - Segment Tooltip

struct SegmentTooltip: View {
    let segment: TimelineSegment

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                Text(segment.appName)
                    .font(ClarityTypography.title3)
                    .foregroundColor(ClarityColors.textPrimary)

                Text(segment.formattedTimeRange)
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: ClaritySpacing.xxs) {
                Text(segment.formattedDuration)
                    .font(ClarityTypography.mono)
                    .foregroundColor(ClarityColors.textPrimary)

                HStack(spacing: ClaritySpacing.xs) {
                    if segment.keystrokes > 0 {
                        Label("\(segment.keystrokes)", systemImage: "keyboard")
                    }
                    if segment.clicks > 0 {
                        Label("\(segment.clicks)", systemImage: "cursorarrow.click")
                    }
                }
                .font(ClarityTypography.caption)
                .foregroundColor(ClarityColors.textTertiary)
            }
        }
        .padding(ClaritySpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: ClarityRadius.md)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        }
    }
}

// MARK: - Preview

#Preview {
    TimelineRibbon(segments: [
        TimelineSegment(
            appName: "VS Code",
            startTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
            durationSeconds: 2 * 60 * 60,
            color: ClarityColors.deepFocus,
            keystrokes: 5420,
            clicks: 234
        ),
        TimelineSegment(
            appName: "Slack",
            startTime: Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: Date()) ?? Date(),
            durationSeconds: 30 * 60,
            color: ClarityColors.communication,
            keystrokes: 320,
            clicks: 89
        ),
        TimelineSegment(
            appName: "Arc",
            startTime: Calendar.current.date(bySettingHour: 11, minute: 30, second: 0, of: Date()) ?? Date(),
            durationSeconds: 45 * 60,
            color: ClarityColors.activeWork,
            keystrokes: 120,
            clicks: 456
        )
    ])
    .padding()
    .frame(height: 100)
}

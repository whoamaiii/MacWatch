import SwiftUI
import ClarityShared

/// View for scheduling focus sessions
struct FocusScheduleView: View {
    @ObservedObject private var scheduleService = FocusScheduleService.shared
    @State private var showingAddSession = false
    @State private var editingSession: FocusScheduleService.ScheduledSession?

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scheduled Sessions")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text("Plan your focus time in advance")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                Spacer()

                Button {
                    showingAddSession = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Schedule")
                    }
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            // Upcoming session highlight
            if let upcoming = scheduleService.upcomingSession, let nextTime = upcoming.nextOccurrence {
                UpcomingSessionCard(session: upcoming, nextTime: nextTime)
            }

            Divider()

            // Sessions list
            if scheduleService.scheduledSessions.isEmpty {
                VStack(spacing: ClaritySpacing.md) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundColor(ClarityColors.textTertiary)

                    Text("No scheduled sessions")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textSecondary)

                    Text("Schedule focus sessions to build consistent habits")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: ClaritySpacing.sm) {
                        ForEach(scheduleService.scheduledSessions) { session in
                            ScheduledSessionRow(
                                session: session,
                                onToggle: { scheduleService.toggleSession(id: session.id) },
                                onEdit: { editingSession = session },
                                onDelete: { scheduleService.deleteSession(id: session.id) }
                            )
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .sheet(isPresented: $showingAddSession) {
            EditScheduledSessionSheet(isPresented: $showingAddSession, session: nil)
        }
        .sheet(item: $editingSession) { session in
            EditScheduledSessionSheet(
                isPresented: Binding(
                    get: { editingSession != nil },
                    set: { if !$0 { editingSession = nil } }
                ),
                session: session
            )
        }
    }
}

// MARK: - Upcoming Session Card

struct UpcomingSessionCard: View {
    let session: FocusScheduleService.ScheduledSession
    let nextTime: Date

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            ZStack {
                Circle()
                    .fill(session.swiftUIColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(session.swiftUIColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Next Session")
                    .font(ClarityTypography.caption)
                    .foregroundColor(ClarityColors.textTertiary)

                Text(session.title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(ClarityColors.textPrimary)

                HStack(spacing: ClaritySpacing.sm) {
                    Text(nextTime, style: .relative)
                        .font(ClarityTypography.caption)
                        .foregroundColor(session.swiftUIColor)

                    Text("•")
                        .foregroundColor(ClarityColors.textTertiary)

                    Text(session.formattedDuration)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }

            Spacer()

            Button {
                PomodoroService.shared.workDuration = Double(session.durationMinutes * 60)
                PomodoroService.shared.start()
            } label: {
                Text("Start Now")
                    .font(ClarityTypography.captionMedium)
            }
            .buttonStyle(.borderedProminent)
            .tint(session.swiftUIColor)
            .controlSize(.small)
        }
        .padding(ClaritySpacing.md)
        .background(session.swiftUIColor.opacity(0.1))
        .cornerRadius(ClarityRadius.md)
    }
}

// MARK: - Scheduled Session Row

struct ScheduledSessionRow: View {
    let session: FocusScheduleService.ScheduledSession
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(session.swiftUIColor)
                .frame(width: 4, height: 40)

            // Session info
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(ClarityTypography.bodyMedium)
                    .foregroundColor(session.isEnabled ? ClarityColors.textPrimary : ClarityColors.textTertiary)

                HStack(spacing: ClaritySpacing.sm) {
                    Text(session.formattedTime)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textSecondary)

                    Text("•")
                        .foregroundColor(ClarityColors.textTertiary)

                    Text(session.formattedDuration)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)

                    Text("•")
                        .foregroundColor(ClarityColors.textTertiary)

                    Text(session.repeatPattern.displayName)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { session.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(ClarityColors.textTertiary)
            }
            .buttonStyle(.plain)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(ClarityColors.danger.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(ClaritySpacing.sm)
        .background(ClarityColors.backgroundSecondary.opacity(session.isEnabled ? 0.5 : 0.2))
        .cornerRadius(ClarityRadius.md)
        .opacity(session.isEnabled ? 1 : 0.6)
    }
}

// MARK: - Edit Scheduled Session Sheet

struct EditScheduledSessionSheet: View {
    @Binding var isPresented: Bool
    let session: FocusScheduleService.ScheduledSession?

    @ObservedObject private var scheduleService = FocusScheduleService.shared

    @State private var title: String = ""
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Int = 25
    @State private var repeatPattern: FocusScheduleService.RepeatPattern = .none
    @State private var reminderMinutes: Int = 5
    @State private var selectedColor: String = "purple"
    @State private var notes: String = ""

    private let colors = ["red", "orange", "yellow", "green", "blue", "purple", "pink"]
    private let durations = [15, 25, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
            // Header
            HStack {
                Text(session == nil ? "Schedule Focus Session" : "Edit Session")
                    .font(ClarityTypography.title2)
                    .foregroundColor(ClarityColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Title
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Session Title")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                TextField("e.g., Morning Deep Work", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            // Time and duration
            HStack(spacing: ClaritySpacing.lg) {
                VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                    Text("Start Time")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)

                    DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                    Text("Duration")
                        .font(ClarityTypography.captionMedium)
                        .foregroundColor(ClarityColors.textSecondary)

                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(durations, id: \.self) { mins in
                            Text(formatMinutes(mins)).tag(mins)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Repeat pattern
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Repeat")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                Picker("Repeat", selection: $repeatPattern) {
                    Text("One-time").tag(FocusScheduleService.RepeatPattern.none)
                    Text("Daily").tag(FocusScheduleService.RepeatPattern.daily)
                    Text("Weekdays").tag(FocusScheduleService.RepeatPattern.weekdays)
                    Text("Weekly").tag(FocusScheduleService.RepeatPattern.weekly)
                }
                .pickerStyle(.segmented)
            }

            // Reminder
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Remind Me")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                Picker("Reminder", selection: $reminderMinutes) {
                    Text("5 min before").tag(5)
                    Text("10 min before").tag(10)
                    Text("15 min before").tag(15)
                    Text("30 min before").tag(30)
                }
                .pickerStyle(.menu)
            }

            // Color
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Color")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(colorForString(color))
                                    .frame(width: 28, height: 28)

                                if selectedColor == color {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: ClaritySpacing.xs) {
                Text("Notes (optional)")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                TextField("What will you focus on?", text: $notes)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(session == nil ? "Schedule" : "Save Changes") {
                    saveSession()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(colorForString(selectedColor))
                .disabled(title.isEmpty)
            }
        }
        .padding(ClaritySpacing.lg)
        .frame(width: 400, height: 550)
        .background(.ultraThinMaterial)
        .onAppear {
            if let session = session {
                title = session.title
                startTime = session.startTime
                durationMinutes = session.durationMinutes
                repeatPattern = session.repeatPattern
                reminderMinutes = session.reminderMinutes
                selectedColor = session.color
                notes = session.notes ?? ""
            }
        }
    }

    private func colorForString(_ colorName: String) -> Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .purple
        }
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins >= 60 {
            let hours = mins / 60
            let remaining = mins % 60
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
        return "\(mins) min"
    }

    private func saveSession() {
        let newSession = FocusScheduleService.ScheduledSession(
            id: session?.id ?? UUID(),
            title: title,
            startTime: startTime,
            durationMinutes: durationMinutes,
            repeatPattern: repeatPattern,
            reminderMinutes: reminderMinutes,
            isEnabled: true,
            color: selectedColor,
            notes: notes.isEmpty ? nil : notes
        )

        if session != nil {
            scheduleService.updateSession(newSession)
        } else {
            scheduleService.addSession(newSession)
        }
    }
}

#Preview {
    GlassCard {
        FocusScheduleView()
    }
    .padding()
    .frame(width: 500)
}

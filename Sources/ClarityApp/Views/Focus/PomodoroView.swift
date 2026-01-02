import SwiftUI
import ClarityShared

/// Pomodoro timer view with circular progress
struct PomodoroView: View {
    @ObservedObject private var pomodoro = PomodoroService.shared
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: ClaritySpacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: ClaritySpacing.xxs) {
                    Text("Pomodoro Timer")
                        .font(ClarityTypography.title2)
                        .foregroundColor(ClarityColors.textPrimary)

                    Text(pomodoro.currentPhase.rawValue)
                        .font(ClarityTypography.caption)
                        .foregroundColor(pomodoro.currentPhase.color)
                }

                Spacer()

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Timer circle
            ZStack {
                // Background circle
                Circle()
                    .stroke(pomodoro.currentPhase.color.opacity(0.2), lineWidth: 12)

                // Progress arc
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(
                        pomodoro.currentPhase.color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: pomodoro.progress)

                // Center content
                VStack(spacing: ClaritySpacing.sm) {
                    Image(systemName: pomodoro.currentPhase.icon)
                        .font(.system(size: 28))
                        .foregroundColor(pomodoro.currentPhase.color)

                    Text(pomodoro.formattedTime)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundColor(ClarityColors.textPrimary)

                    Text(phaseLabel)
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }
            .frame(width: 200, height: 200)

            // Controls
            HStack(spacing: ClaritySpacing.lg) {
                // Reset button
                Button {
                    pomodoro.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(pomodoro.state == .idle && pomodoro.sessionsCompleted == 0)

                // Main control button
                Button {
                    handleMainAction()
                } label: {
                    ZStack {
                        Circle()
                            .fill(pomodoro.currentPhase.color)
                            .frame(width: 64, height: 64)

                        Image(systemName: mainButtonIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                // Skip button
                Button {
                    pomodoro.skip()
                } label: {
                    Image(systemName: "forward.end")
                        .font(.title2)
                        .foregroundColor(ClarityColors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(pomodoro.state == .idle)
            }

            // Session indicators
            HStack(spacing: ClaritySpacing.sm) {
                ForEach(0..<pomodoro.sessionsBeforeLongBreak, id: \.self) { index in
                    Circle()
                        .fill(index < (pomodoro.sessionsCompleted % pomodoro.sessionsBeforeLongBreak)
                              ? pomodoro.currentPhase.color
                              : ClarityColors.backgroundSecondary)
                        .frame(width: 10, height: 10)
                }
            }

            // Stats
            HStack(spacing: ClaritySpacing.xl) {
                VStack(spacing: 2) {
                    Text("\(pomodoro.sessionsCompleted)")
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                    Text("Sessions")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }

                Divider()
                    .frame(height: 30)

                VStack(spacing: 2) {
                    Text(pomodoro.formattedTotalFocusTime)
                        .font(ClarityTypography.title1)
                        .foregroundColor(ClarityColors.textPrimary)
                    Text("Focus Time")
                        .font(ClarityTypography.caption)
                        .foregroundColor(ClarityColors.textTertiary)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            PomodoroSettingsSheet(isPresented: $showSettings)
        }
    }

    private var mainButtonIcon: String {
        switch pomodoro.state {
        case .idle: return "play.fill"
        case .running: return "pause.fill"
        case .paused: return "play.fill"
        }
    }

    private var phaseLabel: String {
        switch pomodoro.state {
        case .idle: return "Ready to focus"
        case .running: return "In progress..."
        case .paused: return "Paused"
        }
    }

    private func handleMainAction() {
        switch pomodoro.state {
        case .idle: pomodoro.start()
        case .running: pomodoro.pause()
        case .paused: pomodoro.resume()
        }
    }
}

// MARK: - Settings Sheet

struct PomodoroSettingsSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var pomodoro = PomodoroService.shared

    @State private var workMinutes: Double
    @State private var shortBreakMinutes: Double
    @State private var longBreakMinutes: Double
    @State private var sessionsBeforeLong: Int

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let p = PomodoroService.shared
        self._workMinutes = State(initialValue: p.workDuration / 60)
        self._shortBreakMinutes = State(initialValue: p.shortBreakDuration / 60)
        self._longBreakMinutes = State(initialValue: p.longBreakDuration / 60)
        self._sessionsBeforeLong = State(initialValue: p.sessionsBeforeLongBreak)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClaritySpacing.lg) {
            // Header
            HStack {
                Text("Pomodoro Settings")
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

            // Duration settings
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                Text("Durations")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                durationRow(
                    title: "Focus Duration",
                    value: $workMinutes,
                    range: 5...60,
                    icon: "brain.head.profile",
                    color: ClarityColors.deepFocus
                )

                durationRow(
                    title: "Short Break",
                    value: $shortBreakMinutes,
                    range: 1...15,
                    icon: "cup.and.saucer",
                    color: ClarityColors.success
                )

                durationRow(
                    title: "Long Break",
                    value: $longBreakMinutes,
                    range: 10...30,
                    icon: "figure.walk",
                    color: ClarityColors.accentPrimary
                )

                HStack {
                    Image(systemName: "repeat")
                        .foregroundColor(ClarityColors.warning)
                        .frame(width: 24)

                    Text("Sessions before long break")
                        .font(ClarityTypography.body)
                        .foregroundColor(ClarityColors.textPrimary)

                    Spacer()

                    Stepper(value: $sessionsBeforeLong, in: 2...8) {
                        Text("\(sessionsBeforeLong)")
                            .font(ClarityTypography.mono)
                            .foregroundColor(ClarityColors.accentPrimary)
                    }
                    .frame(width: 120)
                }
            }

            Divider()

            // Auto-start settings
            VStack(alignment: .leading, spacing: ClaritySpacing.md) {
                Text("Automation")
                    .font(ClarityTypography.captionMedium)
                    .foregroundColor(ClarityColors.textSecondary)

                Toggle(isOn: $pomodoro.autoStartBreaks) {
                    HStack {
                        Image(systemName: "play.circle")
                            .foregroundColor(ClarityColors.success)
                            .frame(width: 24)
                        Text("Auto-start breaks")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $pomodoro.autoStartWork) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(ClarityColors.deepFocus)
                            .frame(width: 24)
                        Text("Auto-start work sessions")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $pomodoro.playSounds) {
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(ClarityColors.accentPrimary)
                            .frame(width: 24)
                        Text("Play sounds")
                            .font(ClarityTypography.body)
                            .foregroundColor(ClarityColors.textPrimary)
                    }
                }
                .toggleStyle(.switch)
            }

            Spacer()

            // Save button
            Button {
                saveSettings()
                isPresented = false
            } label: {
                Text("Save Settings")
                    .font(ClarityTypography.bodyMedium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ClarityColors.accentPrimary)
        }
        .padding(ClaritySpacing.lg)
        .frame(width: 400, height: 500)
        .background(.ultraThinMaterial)
    }

    private func durationRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        icon: String,
        color: Color
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(ClarityTypography.body)
                .foregroundColor(ClarityColors.textPrimary)

            Spacer()

            Text("\(Int(value.wrappedValue)) min")
                .font(ClarityTypography.mono)
                .foregroundColor(ClarityColors.accentPrimary)
                .frame(width: 60)

            Slider(value: value, in: range, step: 1)
                .frame(width: 100)
        }
    }

    private func saveSettings() {
        pomodoro.workDuration = workMinutes * 60
        pomodoro.shortBreakDuration = shortBreakMinutes * 60
        pomodoro.longBreakDuration = longBreakMinutes * 60
        pomodoro.sessionsBeforeLongBreak = sessionsBeforeLong
    }
}

// MARK: - Compact Pomodoro (for menu bar or sidebar)

struct CompactPomodoroView: View {
    @ObservedObject private var pomodoro = PomodoroService.shared

    var body: some View {
        HStack(spacing: ClaritySpacing.md) {
            // Mini progress ring
            ZStack {
                Circle()
                    .stroke(pomodoro.currentPhase.color.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(pomodoro.currentPhase.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Image(systemName: pomodoro.currentPhase.icon)
                    .font(.system(size: 10))
                    .foregroundColor(pomodoro.currentPhase.color)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(pomodoro.formattedTime)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(ClarityColors.textPrimary)

                Text(pomodoro.currentPhase.rawValue)
                    .font(.system(size: 10))
                    .foregroundColor(ClarityColors.textTertiary)
            }

            Spacer()

            // Quick controls
            Button {
                switch pomodoro.state {
                case .idle: pomodoro.start()
                case .running: pomodoro.pause()
                case .paused: pomodoro.resume()
                }
            } label: {
                Image(systemName: pomodoro.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(pomodoro.currentPhase.color)
            }
            .buttonStyle(.plain)
        }
        .padding(ClaritySpacing.sm)
        .background(ClarityColors.backgroundSecondary.opacity(0.5))
        .cornerRadius(ClarityRadius.md)
    }
}

#Preview {
    GlassCard {
        PomodoroView()
    }
    .padding()
    .frame(width: 400)
}

import Foundation
import SwiftUI
import UserNotifications
import AVFoundation

/// Pomodoro timer service for focused work sessions
@MainActor
public final class PomodoroService: ObservableObject {
    public static let shared = PomodoroService()

    // MARK: - Published Properties

    @Published public var state: TimerState = .idle
    @Published public var currentPhase: Phase = .work
    @Published public var timeRemaining: TimeInterval = 0
    @Published public var sessionsCompleted: Int = 0
    @Published public var totalFocusTimeToday: TimeInterval = 0

    // Settings
    @Published public var workDuration: TimeInterval {
        didSet { UserDefaults.standard.set(workDuration, forKey: "pomodoroWorkDuration") }
    }
    @Published public var shortBreakDuration: TimeInterval {
        didSet { UserDefaults.standard.set(shortBreakDuration, forKey: "pomodoroShortBreak") }
    }
    @Published public var longBreakDuration: TimeInterval {
        didSet { UserDefaults.standard.set(longBreakDuration, forKey: "pomodoroLongBreak") }
    }
    @Published public var sessionsBeforeLongBreak: Int {
        didSet { UserDefaults.standard.set(sessionsBeforeLongBreak, forKey: "pomodoroSessionsBeforeLong") }
    }
    @Published public var autoStartBreaks: Bool {
        didSet { UserDefaults.standard.set(autoStartBreaks, forKey: "pomodoroAutoStartBreaks") }
    }
    @Published public var autoStartWork: Bool {
        didSet { UserDefaults.standard.set(autoStartWork, forKey: "pomodoroAutoStartWork") }
    }
    @Published public var playSounds: Bool {
        didSet { UserDefaults.standard.set(playSounds, forKey: "pomodoroPlaySounds") }
    }

    // MARK: - Types

    public enum TimerState: String {
        case idle
        case running
        case paused
    }

    public enum Phase: String {
        case work = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"

        var color: Color {
            switch self {
            case .work: return ClarityColors.deepFocus
            case .shortBreak: return ClarityColors.success
            case .longBreak: return ClarityColors.accentPrimary
            }
        }

        var icon: String {
            switch self {
            case .work: return "brain.head.profile"
            case .shortBreak: return "cup.and.saucer"
            case .longBreak: return "figure.walk"
            }
        }
    }

    // MARK: - Private

    private var timer: Timer?
    private var phaseStartTime: Date?
    private var audioPlayer: AVAudioPlayer?
    private let todayKey = "pomodoroTodayDate"
    private let todayFocusKey = "pomodoroTodayFocus"
    private let sessionsKey = "pomodoroSessionsToday"

    // MARK: - Init

    private init() {
        // Load settings
        workDuration = UserDefaults.standard.object(forKey: "pomodoroWorkDuration") as? TimeInterval ?? 25 * 60
        shortBreakDuration = UserDefaults.standard.object(forKey: "pomodoroShortBreak") as? TimeInterval ?? 5 * 60
        longBreakDuration = UserDefaults.standard.object(forKey: "pomodoroLongBreak") as? TimeInterval ?? 15 * 60
        sessionsBeforeLongBreak = UserDefaults.standard.object(forKey: "pomodoroSessionsBeforeLong") as? Int ?? 4
        autoStartBreaks = UserDefaults.standard.object(forKey: "pomodoroAutoStartBreaks") as? Bool ?? false
        autoStartWork = UserDefaults.standard.object(forKey: "pomodoroAutoStartWork") as? Bool ?? false
        playSounds = UserDefaults.standard.object(forKey: "pomodoroPlaySounds") as? Bool ?? true

        timeRemaining = workDuration
        loadTodayStats()
        requestNotificationPermission()
    }

    // MARK: - Public Methods

    public func start() {
        if state == .idle {
            timeRemaining = durationForPhase(currentPhase)
        }
        state = .running
        phaseStartTime = Date()
        startTimer()
    }

    public func pause() {
        state = .paused
        timer?.invalidate()
        timer = nil
    }

    public func resume() {
        state = .running
        startTimer()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
        currentPhase = .work
        timeRemaining = workDuration
        phaseStartTime = nil
    }

    public func skip() {
        completePhase()
    }

    public func reset() {
        stop()
        sessionsCompleted = 0
        saveTodayStats()
    }

    // MARK: - Computed Properties

    public var progress: Double {
        let total = durationForPhase(currentPhase)
        guard total > 0 else { return 0 }
        return 1.0 - (timeRemaining / total)
    }

    public var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var formattedTotalFocusTime: String {
        let hours = Int(totalFocusTimeToday) / 3600
        let minutes = (Int(totalFocusTimeToday) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Private Methods

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard state == .running else { return }

        timeRemaining -= 1

        if timeRemaining <= 0 {
            completePhase()
        }
    }

    private func completePhase() {
        timer?.invalidate()
        timer = nil

        // Track focus time
        if currentPhase == .work, let startTime = phaseStartTime {
            let focusTime = Date().timeIntervalSince(startTime)
            totalFocusTimeToday += focusTime
            sessionsCompleted += 1
            saveTodayStats()
        }

        // Play sound
        if playSounds {
            playCompletionSound()
        }

        // Send notification
        sendPhaseCompleteNotification()

        // Determine next phase
        let previousPhase = currentPhase
        currentPhase = nextPhase()
        timeRemaining = durationForPhase(currentPhase)
        phaseStartTime = nil

        // Auto-start logic
        if (previousPhase == .work && autoStartBreaks) ||
           (previousPhase != .work && autoStartWork) {
            start()
        } else {
            state = .idle
        }
    }

    private func nextPhase() -> Phase {
        switch currentPhase {
        case .work:
            if sessionsCompleted > 0 && sessionsCompleted % sessionsBeforeLongBreak == 0 {
                return .longBreak
            }
            return .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }

    private func durationForPhase(_ phase: Phase) -> TimeInterval {
        switch phase {
        case .work: return workDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    private func playCompletionSound() {
        if let url = Bundle.main.url(forResource: "complete", withExtension: "wav") {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } else {
            NSSound.beep()
        }
    }

    private func sendPhaseCompleteNotification() {
        let content = UNMutableNotificationContent()

        switch currentPhase {
        case .work:
            content.title = "Focus Session Complete!"
            content.body = "Great work! Time for a \(nextPhase() == .longBreak ? "long" : "short") break."
        case .shortBreak:
            content.title = "Break Over"
            content.body = "Ready to focus again?"
        case .longBreak:
            content.title = "Long Break Over"
            content.body = "Refreshed and ready to go!"
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func loadTodayStats() {
        // Use date string comparison to avoid timezone issues
        let todayString = todayDateString()
        let savedDateString = UserDefaults.standard.string(forKey: todayKey)

        if savedDateString == todayString {
            totalFocusTimeToday = UserDefaults.standard.double(forKey: todayFocusKey)
            sessionsCompleted = UserDefaults.standard.integer(forKey: sessionsKey)
        } else {
            // New day, reset stats
            totalFocusTimeToday = 0
            sessionsCompleted = 0
            UserDefaults.standard.set(todayString, forKey: todayKey)
        }
    }

    private func saveTodayStats() {
        UserDefaults.standard.set(todayDateString(), forKey: todayKey)
        UserDefaults.standard.set(totalFocusTimeToday, forKey: todayFocusKey)
        UserDefaults.standard.set(sessionsCompleted, forKey: sessionsKey)
    }

    /// Get today's date as a stable string (YYYY-MM-DD) to avoid timezone issues
    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        return formatter.string(from: Date())
    }
}

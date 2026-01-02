import Foundation
import AVFoundation
import AppKit

/// Service for playing sound effects for achievements, sessions, and other events
@MainActor
public final class SoundEffectsService: ObservableObject {
    public static let shared = SoundEffectsService()

    @Published public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "soundEffectsEnabled")
        }
    }

    @Published public var volume: Float {
        didSet {
            UserDefaults.standard.set(volume, forKey: "soundEffectsVolume")
        }
    }

    private var audioPlayer: AVAudioPlayer?

    public enum SoundEffect: String {
        case achievementUnlocked = "achievement"
        case focusSessionStart = "focus_start"
        case focusSessionEnd = "focus_end"
        case breakReminder = "break"
        case goalReached = "goal"
        case milestone = "milestone"

        var systemSound: NSSound.Name? {
            switch self {
            case .achievementUnlocked:
                return NSSound.Name("Glass")
            case .focusSessionStart:
                return NSSound.Name("Submarine")
            case .focusSessionEnd:
                return NSSound.Name("Purr")
            case .breakReminder:
                return NSSound.Name("Ping")
            case .goalReached:
                return NSSound.Name("Hero")
            case .milestone:
                return NSSound.Name("Funk")
            }
        }
    }

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        volume = UserDefaults.standard.object(forKey: "soundEffectsVolume") as? Float ?? 0.5
    }

    /// Play a sound effect
    public func play(_ effect: SoundEffect) {
        guard isEnabled else { return }

        if let soundName = effect.systemSound,
           let sound = NSSound(named: soundName) {
            sound.volume = volume
            sound.play()
        }
    }

    /// Play a custom celebration sound for achievements
    public func playAchievementSound() {
        play(.achievementUnlocked)

        // Play a second sound after a short delay for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.play(.milestone)
        }
    }
}

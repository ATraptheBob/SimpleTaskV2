import SwiftUI
import AVFoundation

// This imports the stable, built-in haptics system
#if canImport(UIKit)
import UIKit
#endif

struct HapticAndSoundManager {
    static let shared = HapticAndSoundManager()
    
    // Audio Players
    private var successPlayer: AVAudioPlayer?
    private var deletePlayer: AVAudioPlayer?
    private var completePlayer: AVAudioPlayer?

    private init() {
        // Initialize Audio Players
        setupAudioPlayer(for: &successPlayer, resourceName: "success_sound")
        setupAudioPlayer(for: &deletePlayer, resourceName: "delete_sound")
        setupAudioPlayer(for: &completePlayer, resourceName: "complete_sound")
    }

    private func setupAudioPlayer(for player: inout AVAudioPlayer?, resourceName: String) {
        guard let soundURL = Bundle.main.url(forResource: resourceName, withExtension: "mp3") else {
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: soundURL)
            player?.prepareToPlay()
        } catch {
            print("Could not load sound \(resourceName): \(error)")
        }
    }

    // STABLE HAPTIC TRIGGERS
    func triggerHapticSuccess() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    func triggerHapticWarning() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }

    func triggerHapticSelection() {
        #if os(iOS)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }

    // SOUND TRIGGERS
    func playSuccessSound() { successPlayer?.play() }
    func playDeleteSound() { deletePlayer?.play() }
    func playCompleteSound() { completePlayer?.play() }
}

import SwiftUI
import AVFoundation

class HapticAndSoundManager {
    static let shared = HapticAndSoundManager()
    
    private init() {} // Prevents accidental duplicate managers
    
    // 1. THE FIX: Look directly into UserDefaults to see what the user chose
    private var isHapticsEnabled: Bool {
        // If the setting has never been touched, default to true
        if UserDefaults.standard.object(forKey: "enableHaptics") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enableHaptics")
    }
    
    private var isSoundEnabled: Bool {
        if UserDefaults.standard.object(forKey: "enableSounds") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "enableSounds")
    }
    
    // ---------------------------------------------------------
    // HAPTICS (Upgraded for stronger feedback)
    // ---------------------------------------------------------
    
    func triggerHapticSelection() {
        guard isHapticsEnabled else { return }
        
        // UPGRADE: Changed from standard UISelectionFeedbackGenerator
        // to a .medium impact so you actually feel the thump when tapping buttons
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func triggerHapticSuccess() {
        guard isHapticsEnabled else { return }
        
        // This provides a very distinct, strong double-tap vibration for completing tasks
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    // ---------------------------------------------------------
    // SOUNDS
    // ---------------------------------------------------------
    
    func playSuccessSound() {
        guard isSoundEnabled else { return }
        // 1001 is the standard iOS subtle pop/ding sound
        AudioServicesPlaySystemSound(1001)
    }
    
    func playCompleteSound() {
        guard isSoundEnabled else { return }
        // 1022 is a slightly more satisfying task-completion sound
        AudioServicesPlaySystemSound(1022)
    }
}

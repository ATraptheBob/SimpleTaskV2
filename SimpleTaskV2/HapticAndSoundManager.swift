import SwiftUI
import AudioToolbox // Required for clean, non-vibrating system sounds

class HapticAndSoundManager {
    static let shared = HapticAndSoundManager()
    
    private init() {}
    
    private var isHapticsEnabled: Bool {
        if UserDefaults.standard.object(forKey: "enableHaptics") == nil { return true }
        return UserDefaults.standard.bool(forKey: "enableHaptics")
    }
    
    private var isSoundEnabled: Bool {
        if UserDefaults.standard.object(forKey: "enableSounds") == nil { return true }
        return UserDefaults.standard.bool(forKey: "enableSounds")
    }
    
    // ---------------------------------------------------------
    // HAPTICS
    // ---------------------------------------------------------
    
    func triggerHapticSelection() {
        guard isHapticsEnabled else { return }
        // A very light, subtle tap (great for un-checking boxes)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func triggerHapticSuccess() {
        guard isHapticsEnabled else { return }
        // A single, forceful, instantaneous snap
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // ---------------------------------------------------------
    // SOUNDS (Zero built-in vibrations)
    // ---------------------------------------------------------
    
    func playSuccessSound() {
        guard isSoundEnabled else { return }
        // 1104: The standard iOS keyboard "Tock"
        AudioServicesPlaySystemSound(1104)
    }
    
    func playCompleteSound() {
        guard isSoundEnabled else { return }
        // 1105: A slightly higher pitched, crisp "Tink"
        AudioServicesPlaySystemSound(1105)
    }
}

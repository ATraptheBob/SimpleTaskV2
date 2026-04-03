import Foundation
import UserNotifications

// 1. We add NSObject and UNUserNotificationCenterDelegate to give this class more authority
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationManager()
    
    // We need to initialize the delegate when the manager is created
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if granted {
                print("Notification permission granted!")
            }
        }
    }
    
    func scheduleTimerNotification(durationInSeconds: TimeInterval) {
        cancelTimerNotification()
        
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete! 🧠"
        content.body = "Great work. Time to take a quick break!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: durationInSeconds, repeats: false)
        let request = UNNotificationRequest(identifier: "focus_timer_complete", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus_timer_complete"])
    }
    
    func sendTestTaskNotification(taskTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Task Completed! ✅"
        content.body = "You just finished: \(taskTitle)"
        content.sound = .default
        
        // Increased the test delay slightly just to be safe
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5.0, repeats: false)
        let request = UNNotificationRequest(identifier: "task_test_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // ---------------------------------------------------------
    // THE OVERRIDE: Forces notifications to show when app is open
    // ---------------------------------------------------------
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // This tells iOS: "Yes, I know the app is open. Show the banner and play the sound anyway."
        completionHandler([.banner, .sound, .badge])
    }
}

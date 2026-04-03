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
    
    // 1. The Morning Briefing (Runs daily at 8:00 AM)
    func scheduleMorningBriefing(activeTasks: Int, dueHabits: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_briefing"])
        
        // If nothing is due, stay silent!
        if activeTasks == 0 && dueHabits == 0 { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Good Morning! ☀️"
        content.body = "You have \(activeTasks) tasks and \(dueHabits) habits to tackle today."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_briefing", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // 2. The Streak Rescue (Runs at 9:00 PM if a streak is in danger)
    func scheduleStreakRescue(habitName: String?) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streak_rescue"])
        
        // If all habits are done, cancel the rescue!
        guard let habitName = habitName else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Save Your Streak! 🔥"
        content.body = "You haven't completed '\(habitName)' yet today. Don't lose your progress!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 21 // 9:00 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "streak_rescue", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // 3. The Break Timer (Fires exactly X seconds after break starts)
    func scheduleBreakNotification(durationInSeconds: TimeInterval) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["break_timer_complete"])
        
        let content = UNMutableNotificationContent()
        content.title = "Break is Over! ⏰"
        content.body = "Time to get back to focus. You can do this!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: durationInSeconds, repeats: false)
        let request = UNNotificationRequest(identifier: "break_timer_complete", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
}

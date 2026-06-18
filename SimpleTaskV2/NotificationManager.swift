import Foundation
import UserNotifications

protocol NotificationScheduling {
    func scheduleMorningBriefing(activeTasks: Int, dueHabits: Int)
    func scheduleEveningBriefing(completedTasks: Int, pendingTasks: Int)
    func scheduleStreakRescue(habitName: String?)
    func scheduleTaskReminders(task: AppTask)
    func cancelTaskReminders(taskId: String)
}

// 1. We add NSObject and UNUserNotificationCenterDelegate to give this class more authority
class NotificationManager: NSObject, UNUserNotificationCenterDelegate, NotificationScheduling {
    
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
    
    // 2. The Evening Briefing (Runs daily at 8:00 PM)
    func scheduleEveningBriefing(completedTasks: Int, pendingTasks: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["evening_briefing"])
        
        let content = UNMutableNotificationContent()
        content.title = "Evening Review 🌙"
        if completedTasks > 0 {
            content.body = "You completed \(completedTasks) tasks today! Ready to plan for tomorrow?"
        } else {
            content.body = "Take a moment to reflect on today and plan for tomorrow."
        }
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20 // 8:00 PM
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "evening_briefing", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    // 3. The Streak Rescue (Runs at 9:00 PM if a streak is in danger)
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
    
    // 4. Task Reminders (Standard + Nagging)
    func scheduleTaskReminders(task: AppTask) {
        let baseId = "task_\(task.id)"
        
        // Always cancel existing so we don't duplicate
        cancelTaskReminders(taskId: task.id)
        
        guard !task.isCompleted, let dueDate = task.dueDate else { return }
        
        // Don't schedule in the past
        guard dueDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = task.isUrgent ? "URGENT: \(task.title)" : task.title
        content.body = task.isUrgent ? "This task is due! Please complete it." : "This task is due."
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: baseId, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        
        // If it's urgent, keep bothering the user
        if task.isUrgent {
            let intervals = [15, 30, 60] // Minutes after due date
            for (index, offset) in intervals.enumerated() {
                let nagDate = dueDate.addingTimeInterval(TimeInterval(offset * 60))
                // Only schedule if the nag time is in the future
                guard nagDate > Date() else { continue }
                
                let nagComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nagDate)
                let nagTrigger = UNCalendarNotificationTrigger(dateMatching: nagComponents, repeats: false)
                
                let nagContent = UNMutableNotificationContent()
                nagContent.title = "URGENT REMINDER: \(task.title)"
                nagContent.body = "You still haven't marked this as completed!"
                nagContent.sound = .default // Could use a louder/critical sound if allowed
                
                let nagRequest = UNNotificationRequest(identifier: "\(baseId)_nag_\(index)", content: nagContent, trigger: nagTrigger)
                UNUserNotificationCenter.current().add(nagRequest)
            }
        }
    }
    
    func cancelTaskReminders(taskId: String) {
        let baseId = "task_\(taskId)"
        let identifiers = [baseId, "\(baseId)_nag_0", "\(baseId)_nag_1", "\(baseId)_nag_2"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

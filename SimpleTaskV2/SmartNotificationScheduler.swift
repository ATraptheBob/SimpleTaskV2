import Foundation

struct SmartNotificationScheduler {
    func schedule(allTasks: [TaskItem], allHabits: [HabitItem], notificationManager: NotificationScheduling) {
        let calendar = Calendar.current

        // 1. Calculate Active Tasks
        let activeTasks = allTasks.filter { !$0.isCompleted }.count

        // 2. Calculate Unfinished Habits
        let dueHabits = allHabits.filter { habit in
            let freq = habit.frequency ?? .daily
            if freq == .none { return true }
            guard let latestCompletion = habit.completionDates.max() else { return true }
            switch freq {
            case .daily: return !calendar.isDateInToday(latestCompletion)
            case .weekly: return !calendar.isDate(latestCompletion, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly: return !calendar.isDate(latestCompletion, equalTo: Date(), toGranularity: .month)
            case .none: return true
            }
        }

        // 3. Schedule the Briefing
        notificationManager.scheduleMorningBriefing(activeTasks: activeTasks, dueHabits: dueHabits.count)

        // 4. Find the highest streak in danger, and schedule the rescue
        if let habitToRescue = dueHabits.sorted(by: { $0.streak > $1.streak }).first, habitToRescue.streak > 0 {
            notificationManager.scheduleStreakRescue(habitName: habitToRescue.title)
        } else {
            // Cancel the rescue if all streaks are safe!
            notificationManager.scheduleStreakRescue(habitName: nil)
        }
    }
}

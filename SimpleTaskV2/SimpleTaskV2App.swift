import SwiftUI
import SwiftData

@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    // NEW: Tracks if the app is open, inactive, or in the background
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        do {
            let schema = Schema([TaskItem.self, SubtaskItem.self, HabitItem.self, PomodoroSession.self])
            guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2") else {
                fatalError("Could not find App Group folder.")
            }
            let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
            let config = ModelConfiguration(url: databaseURL)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not configure SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                InboxView().tabItem { Label("Inbox", systemImage: "tray.fill") }
                HabitsView().tabItem { Label("Habits", systemImage: "flame.fill") }
                TimerView().tabItem { Label("Focus", systemImage: "timer") }
            }
            .tint(.pink)
            .preferredColorScheme(.dark)
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
        }
        .modelContainer(container)
        // NEW: When you swipe to the Home Screen, calculate the schedules
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleSmartNotifications()
            }
        }
    }
    
    // NEW: The Brains of the Operation
    private func scheduleSmartNotifications() {
        let context = ModelContext(container)
        let calendar = Calendar.current
        
        // 1. Calculate Active Tasks
        let allTasks = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let activeTasks = allTasks.filter { !$0.isCompleted }.count
        
        // 2. Calculate Unfinished Habits
        let allHabits = (try? context.fetch(FetchDescriptor<HabitItem>())) ?? []
        let dueHabits = allHabits.filter { habit in
            !habit.completionDates.contains { date in
                switch habit.frequency ?? .daily {
                case .daily: return calendar.isDateInToday(date)
                case .weekly: return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
                case .monthly: return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
                case .none: return false
                }
            }
        }
        
        // 3. Schedule the Briefing
        NotificationManager.shared.scheduleMorningBriefing(activeTasks: activeTasks, dueHabits: dueHabits.count)
        
        // 4. Find the highest streak in danger, and schedule the rescue
        if let habitToRescue = dueHabits.sorted(by: { $0.streak > $1.streak }).first, habitToRescue.streak > 0 {
            NotificationManager.shared.scheduleStreakRescue(habitName: habitToRescue.title)
        } else {
            // Cancel the rescue if all streaks are safe!
            NotificationManager.shared.scheduleStreakRescue(habitName: nil)
        }
    }
}

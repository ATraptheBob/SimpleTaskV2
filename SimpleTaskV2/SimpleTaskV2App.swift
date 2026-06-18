import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    // NEW: Tracks if the app is open, inactive, or in the background
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    init() {
        do {
            let schema = Schema([HabitItem.self, PomodoroSession.self])
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
            // 2. CHANGE THIS LINE: Dynamically flip the system text colors
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onAppear {
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "645108702205-fdgev8hbmmtn42jjgr1fmi6v873u1ff6.apps.googleusercontent.com")
                NotificationManager.shared.requestAuthorization()
                Task {
                    let granted = await EventKitManager.shared.requestAccess()
                    if granted {
                        await EventKitManager.shared.loadData()
                        EventKitManager.shared.startSyncTimer()
                    }
                }
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Re-sync every time the app comes to the foreground
                Task {
                    await EventKitManager.shared.loadData()
                }
            case .background:
                scheduleSmartNotifications()
            default:
                break
            }
        }
    }
    
    // NEW: The Brains of the Operation
    private func scheduleSmartNotifications() {
        let context = ModelContext(container)
        // Task logic temporarily disabled pending EventKit integration
        let allTasks: [TaskItem] = [] 
        let allHabits = (try? context.fetch(FetchDescriptor<HabitItem>())) ?? []
        for habit in allHabits {
            habit.updateStreak()
        }

        let calendar = Calendar.current
        _ = allHabits.filter { habit in
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
        
        let scheduler = SmartNotificationScheduler()
        scheduler.schedule(allTasks: allTasks, allHabits: allHabits, notificationManager: NotificationManager.shared)
    }
}

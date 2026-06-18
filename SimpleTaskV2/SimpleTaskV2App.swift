import SwiftUI
import SwiftData
import GoogleSignIn

/// Defers view initialization until the view actually appears on screen.
/// Prevents SwiftUI TabView from eagerly constructing all tab bodies at launch.
struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: Content { build() }
}

@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    // NEW: Tracks if the app is open, inactive, or in the background
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode", store: UserDefaults(suiteName: "group.com.wilsonlee.SimpleTaskV2")) private var isDarkMode = true
    
    init() {
        do {
            let schema = Schema([HabitItem.self, PomodoroSession.self, QueuedTaskAction.self])
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
                LazyView(HabitsView()).tabItem { Label("Habits", systemImage: "flame.fill") }
                LazyView(TimerView()).tabItem { Label("Focus", systemImage: "timer") }
            }
            .tint(.pink)
            // 2. CHANGE THIS LINE: Dynamically flip the system text colors
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                // Configure Google Sign-In synchronously (cheap, just sets a config object)
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "645108702205-fdgev8hbmmtn42jjgr1fmi6v873u1ff6.apps.googleusercontent.com")
                
                // Yield to let the first frame render before doing heavy I/O
                await Task.yield()
                
                // Fire all independent startup tasks concurrently
                async let restoreGoogle: () = GoogleWorkspaceManager.shared.restoreSignIn()
                async let requestNotifications: () = { NotificationManager.shared.requestAuthorization() }()
                async let loadEventKit: () = performEventKitSetup()
                
                _ = await (restoreGoogle, requestNotifications, loadEventKit)
            }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Re-sync every time the app comes to the foreground
                Task {
                    await EventKitManager.shared.loadData()
                    processQueuedActions()
                }
            case .background:
                scheduleSmartNotifications()
            default:
                break
            }
        }
    }
    
    /// Requests EventKit access and loads data + starts sync timer if granted.
    private func performEventKitSetup() async {
        let granted = await EventKitManager.shared.requestAccess()
        if granted {
            await EventKitManager.shared.loadData()
            EventKitManager.shared.startSyncTimer()
        }
    }
    
    // NEW: The Brains of the Operation
    
    private func processQueuedActions() {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<QueuedTaskAction>()
        guard let queuedActions = try? context.fetch(descriptor), !queuedActions.isEmpty else { return }
        
        for action in queuedActions {
            // Find the task in EventKit
            if let taskIndex = EventKitManager.shared.reminders.firstIndex(where: { $0.id == action.taskID }) {
                var task = EventKitManager.shared.reminders[taskIndex]
                task.isCompleted = (action.actionType == "complete")
                if task.isCompleted {
                    task.completionDate = action.timestamp
                } else {
                    task.completionDate = nil
                }
                try? EventKitManager.shared.updateTask(task)
            }
            context.delete(action)
        }
        try? context.save()
    }
    
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

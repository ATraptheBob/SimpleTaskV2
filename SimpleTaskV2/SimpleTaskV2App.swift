import SwiftUI
import SwiftData
import GoogleSignIn


@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    // NEW: Tracks if the app is open, inactive, or in the background
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isDarkMode", store: UserDefaults(suiteName: "group.com.wilsonlee.SimpleTaskV2")) private var isDarkMode = true
    
    /// Controls splash → main content transition.
    /// False = show splash, True = show TabView.
    @State private var isReady = false
    
    init() {
        do {
            let schema = Schema([PomodoroSession.self, QueuedTaskAction.self, ArchivedTask.self])
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
            MainTabView()
                .tint(AppTheme.accent)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                // Configure Google Sign-In (cheap — just sets a config object)
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "645108702205-fdgev8hbmmtn42jjgr1fmi6v873u1ff6.apps.googleusercontent.com")
                
                // Yield to let the first frame render before doing heavy I/O
                await Task.yield()
                
                // Run all heavy startup I/O concurrently
                async let restoreGoogle: () = GoogleWorkspaceManager.shared.restoreSignIn()
                async let requestNotifications: () = MainActor.run { NotificationManager.shared.requestAuthorization() }
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
        
        // Hoist EventKit reminders into a dictionary for O(1) lookup
        let remindersDict = Dictionary(uniqueKeysWithValues: EventKitManager.shared.reminders.map { ($0.id, $0) })

        for action in queuedActions {
            // Find the task in EventKit
            if var task = remindersDict[action.taskID] {
                task.isCompleted = (action.actionType == "complete")
                if task.isCompleted {
                    task.completionDate = action.timestamp
                } else {
                    task.completionDate = nil
                }
                try? EventKitManager.shared.updateTask(task, commit: false)
            }
            context.delete(action)
        }
        try? EventKitManager.shared.commitChanges()
        try? context.save()
    }
    
    private func scheduleSmartNotifications() {
        let allTasks: [TaskItem] = [] 
        let allHabits = EventKitManager.shared.computedHabits
        
        let scheduler = SmartNotificationScheduler()
        scheduler.schedule(allTasks: allTasks, allHabits: allHabits, notificationManager: NotificationManager.shared)
    }
}

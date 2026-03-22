import SwiftUI
import SwiftData

@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    // Listens to the Dark Mode toggle from SettingsView
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    init() {
        do {
            let schema = Schema([
                TaskItem.self,
                SubtaskItem.self,
                HabitItem.self,
                PomodoroSession.self
            ])
            let config = ModelConfiguration()
            container = try ModelContainer(for: schema, configurations: config)
            container.mainContext.autosaveEnabled = false
        } catch {
            fatalError("Could not configure SwiftData: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                InboxView()
                    .tabItem { Label("Inbox", systemImage: "tray.fill") }
                
                HabitsView()
                    .tabItem { Label("Habits", systemImage: "flame.fill") }
                
                TimerView()
                    .tabItem { Label("Focus", systemImage: "timer") }
            }
            .tint(.pink)
            // THE FIX: Forces the entire app to respect your custom setting
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
        .modelContainer(container)
    }
}

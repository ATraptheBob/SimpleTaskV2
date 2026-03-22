import SwiftUI
import SwiftData

@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    init() {
        do {
            // 1. Define the models
            let schema = Schema([
                TaskItem.self,
                SubtaskItem.self,
                HabitItem.self,
                PomodoroSession.self
            ])
            
            // 2. Standard configuration
            let config = ModelConfiguration()
            
            // 3. Create the container
            container = try ModelContainer(for: schema, configurations: config)
            
            // 4. THE SPEED FIX: Turn off autosave on the active memory context
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
                
                ArchiveView()
                    .tabItem { Label("Archive", systemImage: "archivebox.fill") }
                
                TimerView()
                    .tabItem { Label("Focus", systemImage: "timer") }
                
                StatsView()
                    .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            }
            .tint(.pink)
            .preferredColorScheme(.dark)
        }
        .modelContainer(container) // Uses your highly-optimized custom container
    }
}

import SwiftUI
import SwiftData

@main
struct SimpleTaskV2App: App {
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                TaskItem.self,
                SubtaskItem.self,
                HabitItem.self,
                PomodoroSession.self
            ])
            
            // Shared folder for Widgets and App access
            guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2") else {
                fatalError("Could not find App Group folder.")
            }
            
            let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
            let config = ModelConfiguration(url: databaseURL)
            
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            print("Could not configure SwiftData: \(error). Falling back to in-memory store.")
            let schema = Schema([
                TaskItem.self,
                SubtaskItem.self,
                HabitItem.self,
                PomodoroSession.self
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                // Main View (Contains the Hamburger Menu for Archive/Stats/Settings)
                InboxView()
                    .tabItem {
                        Label("Inbox", systemImage: "tray.fill")
                    }
                
                HabitsView()
                    .tabItem {
                        Label("Habits", systemImage: "flame.fill")
                    }
                
                TimerView()
                    .tabItem {
                        Label("Focus", systemImage: "timer")
                    }
            }
            .tint(.pink)
            .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

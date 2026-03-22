import SwiftUI
import SwiftData

@main
struct SimpleTaskV2App: App {
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
            .tint(.pink) // Minimalist color accent
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [TaskItem.self, SubtaskItem.self, HabitItem.self, PomodoroSession.self])
    }
}

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// ---------------------------------------------------------
// 1. THE ACTION INTENT (Handles the interactive button tap)
// ---------------------------------------------------------
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    
    // We need the ID to know exactly which task to check off
    @Parameter(title: "Task ID")
    var taskID: String
    
    init() {}
    init(taskID: String) { self.taskID = taskID }
    
    func perform() async throws -> some IntentResult {
        // 1. Connect to the shared App Group database
        let schema = Schema([TaskItem.self, SubtaskItem.self, HabitItem.self, PomodoroSession.self])
        guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2") else {
            return .result()
        }
        let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
        let config = ModelConfiguration(url: databaseURL)
        
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            
            // 2. Fetch all tasks and find the one that matches the tapped ID
            let descriptor = FetchDescriptor<TaskItem>()
            let allTasks = try context.fetch(descriptor)
            
            if let task = allTasks.first(where: { $0.id.uuidString == taskID }) {
                // 3. Toggle it and save!
                task.isCompleted.toggle()
                task.completionDate = task.isCompleted ? Date() : nil
                try context.save()
            }
        } catch {
            print("Widget Intent failed to save: \(error)")
        }
        
        return .result()
    }
}

// ---------------------------------------------------------
// 2. THE DATA MODELS
// ---------------------------------------------------------
// We use a simplified struct to pass data safely into the widget timeline
struct WidgetTaskInfo: Identifiable {
    let id: String
    let title: String
    let isCompleted: Bool
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let pendingTasksCount: Int
    let pendingHabitsCount: Int
    let topTasks: [WidgetTaskInfo] // NEW: Holds the tasks for the medium widget
}

// ---------------------------------------------------------
// 3. THE TIMELINE PROVIDER
// ---------------------------------------------------------
struct Provider: TimelineProvider {
    
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), pendingTasksCount: 3, pendingHabitsCount: 2, topTasks: [
            WidgetTaskInfo(id: "1", title: "Read Chapter 4", isCompleted: false),
            WidgetTaskInfo(id: "2", title: "Submit CS Project", isCompleted: false)
        ])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), pendingTasksCount: 3, pendingHabitsCount: 2, topTasks: [])
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            do {
                let schema = Schema([TaskItem.self, SubtaskItem.self, HabitItem.self, PomodoroSession.self])
                let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2")!
                let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
                let config = ModelConfiguration(url: databaseURL)
                let container = try ModelContainer(for: schema, configurations: config)
                
                // Fetch Tasks
                let descriptorTasks = FetchDescriptor<TaskItem>()
                let allTasks = (try? container.mainContext.fetch(descriptorTasks)) ?? []
                let activeTasks = allTasks.filter { !$0.isCompleted }
                
                // Get the top 3 upcoming tasks to show in the medium widget list
                let topTasks = activeTasks.prefix(3).map {
                    WidgetTaskInfo(id: $0.id.uuidString, title: $0.title, isCompleted: $0.isCompleted)
                }
                
                // Fetch Habits
                let descriptorHabits = FetchDescriptor<HabitItem>()
                let allHabits = (try? container.mainContext.fetch(descriptorHabits)) ?? []
                let dueHabitsCount = allHabits.filter { !isHabitDone($0) }.count
                
                let entry = SimpleEntry(date: Date(), pendingTasksCount: activeTasks.count, pendingHabitsCount: dueHabitsCount, topTasks: Array(topTasks))
                
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                let entry = SimpleEntry(date: Date(), pendingTasksCount: 0, pendingHabitsCount: 0, topTasks: [])
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
                completion(timeline)
            }
        }
    }
    
    private func isHabitDone(_ habit: HabitItem) -> Bool {
        let cal = Calendar.current
        return habit.completionDates.contains { date in
            switch habit.frequency ?? .daily {
            case .daily: return cal.isDateInToday(date)
            case .weekly: return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly: return cal.isDate(date, equalTo: Date(), toGranularity: .month)
            case .none: return false
            }
        }
    }
}

// ---------------------------------------------------------
// 4. THE UI DESIGN
// ---------------------------------------------------------
struct TaskWidgetEntryView : View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemSmall {
            // THE ORIGINAL SMALL WIDGET
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bolt.fill").foregroundColor(.pink).font(.title3)
                    Text("Daily Status").font(.headline).foregroundColor(.white)
                }
                Divider().background(Color.gray.opacity(0.3))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: entry.pendingTasksCount > 0 ? "checkmark.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(entry.pendingTasksCount > 0 ? .pink : .green)
                        Text("\(entry.pendingTasksCount) Tasks Left").foregroundColor(.gray).font(.subheadline).bold()
                    }
                    HStack {
                        Image(systemName: entry.pendingHabitsCount > 0 ? "flame.fill" : "flame.fill")
                            .foregroundColor(entry.pendingHabitsCount > 0 ? .orange : .gray)
                        Text("\(entry.pendingHabitsCount) Habits Due").foregroundColor(.gray).font(.subheadline).bold()
                    }
                }
                Spacer()
            }
            .padding()
            .containerBackground(Color(white: 0.05), for: .widget)
            
        } else {
            // THE ASYMMETRIC SPLIT-SCREEN MEDIUM WIDGET
            HStack(alignment: .top, spacing: 14) {
                
                // LEFT COLUMN: Ultra-Compact Sidebar
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tasks") // Changed from "Status"
                        .font(.headline)
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.8)
                    
                    VStack(alignment: .leading, spacing: 16) { // Slightly increased vertical spacing between the two icons
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.pink)
                                .font(.subheadline) // Bumped up icon size slightly to match the bold numbers
                            
                            Text("\(entry.pendingTasksCount)") // Stripped text
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.pink)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.subheadline)
                            
                            Text("\(entry.pendingHabitsCount)") // Stripped text
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                    Spacer()
                }
                // FIX: Shrunk dramatically from 85 down to 55
                .frame(width: 55, alignment: .leading)
                
                // THE VERTICAL SEPARATOR
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // RIGHT COLUMN: Expanded Interactive Task List
                VStack(spacing: 0) {
                    if entry.topTasks.isEmpty {
                        Spacer()
                        Text("All caught up! 🎉").foregroundColor(.gray).font(.caption)
                        Spacer()
                    } else {
                        ForEach(Array(entry.topTasks.prefix(3).enumerated()), id: \.element.id) { index, task in
                            VStack(spacing: 0) {
                                HStack(alignment: .center, spacing: 12) {
                                    
                                    Button(intent: ToggleTaskIntent(taskID: task.id)) {
                                        if task.isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.pink)
                                        } else {
                                            Circle()
                                                .strokeBorder(Color.gray.opacity(0.4), lineWidth: 1.5)
                                                .frame(width: 18, height: 18)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Text(task.title)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(task.isCompleted ? .gray : .white)
                                        .strikethrough(task.isCompleted, color: .gray)
                                        .lineLimit(1)
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 10)
                                
                                if index < min(entry.topTasks.count, 3) - 1 {
                                    Divider()
                                        .background(Color.gray.opacity(0.3))
                                        .padding(.leading, 30)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .containerBackground(Color(white: 0.10), for: .widget)
        }
    }
}
// ---------------------------------------------------------
// 5. WIDGET CONFIGURATION
// ---------------------------------------------------------
struct TaskWidget: Widget {
    let kind: String = "TaskWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks & Habits")
        .description("Track your status or check off upcoming tasks.")
        // FIX: Now explicitly supports both sizes so the Medium one appears in the menu
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

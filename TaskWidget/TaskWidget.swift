import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

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
                let schema = Schema([HabitItem.self, PomodoroSession.self, QueuedTaskAction.self])
                guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2") else {
                    throw URLError(.badURL)
                }
                let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
                let config = ModelConfiguration(url: databaseURL)
                let container = try ModelContainer(for: schema, configurations: config)
                
                // Fetch Tasks
                // TODO: Fetch tasks from EventKitManager
                let activeTasks: [WidgetTaskInfo] = []
                let topTasks: [WidgetTaskInfo] = []
                
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
        switch family {
        case .accessoryRectangular:
            // LOCK SCREEN WIDGET
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: entry.pendingTasksCount > 0 ? "checklist" : "checkmark.circle.fill")
                    Text("Tasks: \(entry.pendingTasksCount)")
                        .font(.headline)
                }
                if let topTask = entry.topTasks.first {
                    HStack {
                        Button(intent: ToggleTaskIntent(taskID: topTask.id, isCompleted: topTask.isCompleted)) {
                            Image(systemName: topTask.isCompleted ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        Text(topTask.title)
                            .lineLimit(1)
                            .strikethrough(topTask.isCompleted)
                    }
                } else {
                    Text("All caught up!")
                        .foregroundColor(.gray)
                }
            }
            .containerBackground(for: .widget) {}
            
        case .systemSmall:
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
            
        case .systemMedium:
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
                .frame(width: 85, alignment: .leading)
                
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
                                    
                                    Button(intent: ToggleTaskIntent(taskID: task.id, isCompleted: task.isCompleted)) {
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
        default:
            Text("Unsupported")
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
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// ---------------------------------------------------------
// 6. WIDGET INTENTS
// ---------------------------------------------------------

struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    
    @Parameter(title: "Task ID")
    var taskID: String
    
    @Parameter(title: "Is Currently Completed")
    var isCompleted: Bool
    
    init() {}
    init(taskID: String, isCompleted: Bool) {
        self.taskID = taskID
        self.isCompleted = isCompleted
    }
    
    func perform() async throws -> some IntentResult {
        do {
            let schema = Schema([HabitItem.self, PomodoroSession.self, QueuedTaskAction.self])
            guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2") else {
                return .result()
            }
            let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
            let config = ModelConfiguration(url: databaseURL)
            let container = try ModelContainer(for: schema, configurations: config)
            
            let context = ModelContext(container)
            let action = QueuedTaskAction(taskID: taskID, actionType: isCompleted ? "uncomplete" : "complete")
            context.insert(action)
            try context.save()
        } catch {
            print("Failed to queue task action: \(error)")
        }
        return .result()
    }
}

struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"
    
    @Parameter(title: "Habit ID")
    var habitIDString: String
    
    init() {}
    init(habitID: String) { self.habitIDString = habitID }
    
    func perform() async throws -> some IntentResult {
        do {
            let schema = Schema([HabitItem.self, PomodoroSession.self, QueuedTaskAction.self])
            guard let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2") else {
                return .result()
            }
            let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
            let config = ModelConfiguration(url: databaseURL)
            let container = try ModelContainer(for: schema, configurations: config)
            
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<HabitItem>()
            let habits = try context.fetch(descriptor)
            
            if let uuid = UUID(uuidString: habitIDString), let habit = habits.first(where: { $0.id == uuid }) {
                let cal = Calendar.current
                let freq = habit.frequency ?? .daily
                var isDone = false
                
                if let latest = habit.completionDates.max() {
                    switch freq {
                    case .daily: isDone = cal.isDateInToday(latest)
                    case .weekly: isDone = cal.isDate(latest, equalTo: Date(), toGranularity: .weekOfYear)
                    case .monthly: isDone = cal.isDate(latest, equalTo: Date(), toGranularity: .month)
                    case .none: isDone = false
                    }
                }
                
                if isDone {
                    if let latest = habit.completionDates.max() {
                        habit.completionDates.removeAll(where: { $0 == latest })
                    }
                } else {
                    habit.completionDates.append(Date())
                }
                habit.updateStreak()
                try context.save()
            }
        } catch {
            print("Failed to toggle habit: \(error)")
        }
        return .result()
    }
}

struct ToggleTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Timer"
    
    init() {}
    
    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: "group.com.wilsonlee.SimpleTaskV2") else {
            return .result()
        }
        
        let targetEndTime = defaults.double(forKey: "targetEndTime")
        
        if targetEndTime > 0 {
            let remaining = targetEndTime - Date().timeIntervalSince1970
            if remaining > 0 {
                defaults.set(Int(remaining), forKey: "storedTimeRemaining")
            }
            defaults.set(0.0, forKey: "targetEndTime")
        } else {
            let stored = defaults.integer(forKey: "storedTimeRemaining")
            let timeToUse = stored > 0 ? stored : (defaults.integer(forKey: "pomodoroDuration") * 60)
            let newTarget = Date().timeIntervalSince1970 + Double(timeToUse)
            defaults.set(newTarget, forKey: "targetEndTime")
        }
        return .result()
    }
}

import WidgetKit
import SwiftUI
import SwiftData

// 1. THE TIMELINE PROVIDER
struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), pendingTasksCount: 3, pendingHabitsCount: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), pendingTasksCount: 3, pendingHabitsCount: 2)
        completion(entry)
    }

    // FIX: Wrapped in a Task to respect Swift 6 strict concurrency rules
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task { @MainActor in
            do {
                let schema = Schema([TaskItem.self, SubtaskItem.self, HabitItem.self, PomodoroSession.self])
                let sharedFolderURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.wilsonlee.SimpleTaskV2")!
                let databaseURL = sharedFolderURL.appendingPathComponent("SimpleTaskDatabase.sqlite")
                let config = ModelConfiguration(url: databaseURL)
                let container = try ModelContainer(for: schema, configurations: config)
                
                let descriptorTasks = FetchDescriptor<TaskItem>()
                let allTasks = (try? container.mainContext.fetch(descriptorTasks)) ?? []
                let activeTasksCount = allTasks.filter { !$0.isCompleted }.count
                
                let descriptorHabits = FetchDescriptor<HabitItem>()
                let allHabits = (try? container.mainContext.fetch(descriptorHabits)) ?? []
                let dueHabitsCount = allHabits.filter { !isHabitDone($0) }.count

                let entry = SimpleEntry(date: Date(), pendingTasksCount: activeTasksCount, pendingHabitsCount: dueHabitsCount)
                
                // Tells the widget to ask for an update every 15 minutes
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                // Failsafe just in case the database is temporarily locked
                let entry = SimpleEntry(date: Date(), pendingTasksCount: 0, pendingHabitsCount: 0)
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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let pendingTasksCount: Int
    let pendingHabitsCount: Int
}

// 2. THE UI DESIGN
struct TaskWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.pink)
                    .font(.title3)
                Text("Daily Status")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: entry.pendingTasksCount > 0 ? "circle" : "checkmark.circle.fill")
                        .foregroundColor(entry.pendingTasksCount > 0 ? .pink : .green)
                    Text("\(entry.pendingTasksCount) Tasks Left")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .bold()
                }
                
                HStack {
                    Image(systemName: entry.pendingHabitsCount > 0 ? "flame" : "flame.fill")
                        .foregroundColor(entry.pendingHabitsCount > 0 ? .orange : .gray)
                    Text("\(entry.pendingHabitsCount) Habits Due")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                        .bold()
                }
            }
            Spacer()
        }
        .padding()
        .containerBackground(Color(white: 0.05), for: .widget)
    }
}

// FIX: The @main tag was removed from here because TaskWidgetBundle handles it!
struct TaskWidget: Widget {
    let kind: String = "TaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Status")
        .description("Keep track of your pending tasks and habits.")
        // UPDATE THIS LINE:
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

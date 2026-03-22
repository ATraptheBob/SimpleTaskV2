import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @State private var showingAddSheet = false

    // The Magic Filter: Keeps incomplete tasks + tasks completed within the last 24h
    var activeTasks: [TaskItem] {
        allTasks.filter { task in
            if !task.isCompleted { return true }
            if let compDate = task.completionDate {
                return Date().timeIntervalSince(compDate) < 86400
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                List {
                    ForEach(activeTasks) { task in
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                                .foregroundColor(task.isCompleted ? .gray : .pink)
                                .onTapGesture { toggleTask(task) }
                            
                            VStack(alignment: .leading) {
                                Text(task.title)
                                    .foregroundColor(task.isCompleted ? .gray : .white)
                                    .strikethrough(task.isCompleted)
                                Text(task.dueDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Inbox")
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddTaskView() // Use your existing AddTaskView here
            }
        }
    }

    private func toggleTask(_ task: TaskItem) {
        withAnimation {
            if task.isCompleted {
                task.isCompleted = false
                task.completionDate = nil
            } else {
                if task.repeatInterval != .none {
                    // Reschedule logic
                    var components = DateComponents()
                    switch task.repeatInterval {
                    case .daily: components.day = 1
                    case .weekly: components.day = 7
                    case .monthly: components.month = 1
                    case .none: break
                    }
                    if let nextDate = Calendar.current.date(byAdding: components, to: task.dueDate) {
                        task.dueDate = nextDate
                    }
                } else {
                    task.isCompleted = true
                    task.completionDate = Date() // Timestamps the completion
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets { modelContext.delete(activeTasks[index]) }
    }
}

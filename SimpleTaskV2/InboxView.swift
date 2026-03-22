import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false

    var activeTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted || ( $0.completionDate != nil && Date().timeIntervalSince($0.completionDate!) < 86400) }
    }
    
    // Finds habits that haven't been completed for their required time period
    var dueHabits: [HabitItem] {
        allHabits.filter { habit in
            guard let lastDate = habit.lastCompletedDate else { return true }
            let cal = Calendar.current
            switch habit.frequency {
            case .daily: return !cal.isDateInToday(lastDate)
            case .weekly: return !cal.isDate(lastDate, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly: return !cal.isDate(lastDate, equalTo: Date(), toGranularity: .month)
            case .none: return true
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                List {
                    if !dueHabits.isEmpty {
                        Section(header: Text("Due Habits").foregroundColor(.orange)) {
                            ForEach(dueHabits) { habit in
                                HStack {
                                    Text(habit.title).foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "circle.dashed").foregroundColor(.orange)
                                }
                                .listRowBackground(Color(white: 0.1))
                            }
                        }
                    }
                    
                    Section(header: Text("Tasks").foregroundColor(.pink)) {
                        ForEach(activeTasks) { task in
                            TaskRow(task: task)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            for i in indexSet { modelContext.delete(activeTasks[i]) }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Inbox")
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddTaskView() }
        }
    }
}

// Handles the nested subtask UI
struct TaskRow: View {
    @Bindable var task: TaskItem
    @State private var isExpanded = false
    @State private var newSubtaskTitle = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .gray : .pink)
                    .onTapGesture {
                        withAnimation { task.isCompleted.toggle(); task.completionDate = task.isCompleted ? Date() : nil }
                    }
                
                Text(task.title)
                    .foregroundColor(task.isCompleted ? .gray : .white)
                    .strikethrough(task.isCompleted)
                
                Spacer()
                
                // Expand button for nested tasks
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading) {
                    ForEach(task.subtasks) { subtask in
                        HStack {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle" : "circle")
                                .onTapGesture { subtask.isCompleted.toggle() }
                            Text(subtask.title).strikethrough(subtask.isCompleted)
                        }
                        .foregroundColor(.gray)
                        .padding(.leading, 30)
                        .padding(.top, 4)
                    }
                    
                    // Quick add subtask inline
                    HStack {
                        Image(systemName: "arrow.turn.down.right").foregroundColor(.gray)
                        TextField("Add step...", text: $newSubtaskTitle)
                            .onSubmit {
                                if !newSubtaskTitle.isEmpty {
                                    task.subtasks.append(SubtaskItem(title: newSubtaskTitle))
                                    newSubtaskTitle = ""
                                }
                            }
                    }
                    .padding(.leading, 30)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

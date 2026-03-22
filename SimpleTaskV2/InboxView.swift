import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    @State private var showingAddSheet = false

    var activeTasks: [TaskItem] {
        allTasks.filter { !$0.isCompleted || ($0.completionDate != nil && Date().timeIntervalSince($0.completionDate!) < 86400) }
    }
    
    // Finds due habits by checking the new completionDates array
    var dueHabits: [HabitItem] {
        allHabits.filter { !isHabitDone($0) }
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
                                    Image(systemName: "circle")
                                        .foregroundColor(.orange)
                                        .onTapGesture { toggleHabit(habit) }
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
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Inbox")
            .toolbar { Button(action: { showingAddSheet = true }) { Image(systemName: "plus") } }
            .sheet(isPresented: $showingAddSheet) { AddTaskView() }
        }
    }

    // Helper functions for the Inbox Habits
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

    private func toggleHabit(_ habit: HabitItem) {
        withAnimation { habit.completionDates.append(Date()) }
    }
}

// Optimized TaskRow with smooth expansion
struct TaskRow: View {
    @Bindable var task: TaskItem
    @State private var isExpanded = false
    @State private var newSubtaskTitle = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .gray : .pink)
                    .onTapGesture { withAnimation { task.isCompleted.toggle(); task.completionDate = task.isCompleted ? Date() : nil } }
                
                Text(task.title).foregroundColor(task.isCompleted ? .gray : .white).strikethrough(task.isCompleted)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .foregroundColor(.gray)
                    .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() } }
            }
            .padding(.vertical, 8)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(task.subtasks) { subtask in
                        HStack {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle").foregroundColor(subtask.isCompleted ? .green : .gray)
                                .onTapGesture { withAnimation { subtask.isCompleted.toggle() } }
                            Text(subtask.title).font(.subheadline).strikethrough(subtask.isCompleted)
                        }
                        .padding(.leading, 24)
                    }
                    
                    HStack {
                        Image(systemName: "plus.circle").foregroundColor(.gray)
                        TextField("New step...", text: $newSubtaskTitle)
                            .font(.subheadline)
                            .onSubmit {
                                if !newSubtaskTitle.isEmpty {
                                    withAnimation { task.subtasks.append(SubtaskItem(title: newSubtaskTitle)); newSubtaskTitle = "" }
                                }
                            }
                    }
                    .padding(.leading, 24)
                }
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

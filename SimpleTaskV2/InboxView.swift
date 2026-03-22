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
            .toolbar {
                // THE NEW TOP-LEFT MENU
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink(destination: ArchiveView()) {
                            Label("Archive", systemImage: "archivebox")
                        }
                        NavigationLink(destination: StatsView()) {
                            Label("Statistics", systemImage: "chart.bar")
                        }
                        NavigationLink(destination: SettingsView()) {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                // Existing Add Button
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddTaskView() }
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

    private func toggleHabit(_ habit: HabitItem) {
        withAnimation { habit.completionDates.append(Date()) }
    }
}

// THE FIX: Uses DisclosureGroup for buttery smooth native iOS animations
struct TaskRow: View {
    @Bindable var task: TaskItem
    @State private var isExpanded = false
    @State private var newSubtaskTitle = ""
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(task.subtasks) { subtask in
                    HStack {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                            .onTapGesture { withAnimation { subtask.isCompleted.toggle() } }
                        Text(subtask.title).font(.subheadline).strikethrough(subtask.isCompleted).foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                }
                
                HStack {
                    Image(systemName: "plus.circle").foregroundColor(.gray)
                    TextField("New step...", text: $newSubtaskTitle)
                        .font(.subheadline)
                        .onSubmit {
                            if !newSubtaskTitle.isEmpty {
                                withAnimation {
                                    task.subtasks.append(SubtaskItem(title: newSubtaskTitle))
                                    newSubtaskTitle = ""
                                }
                            }
                        }
                }
                .padding(.leading, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        } label: {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .gray : .pink)
                    .font(.title3)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            task.isCompleted.toggle()
                            task.completionDate = task.isCompleted ? Date() : nil
                        }
                    }
                
                Text(task.title)
                    .foregroundColor(task.isCompleted ? .gray : .white)
                    .strikethrough(task.isCompleted)
            }
            .padding(.vertical, 4)
        }
        .tint(.gray) // Colors the expand chevron to match your dark mode UI
    }
}

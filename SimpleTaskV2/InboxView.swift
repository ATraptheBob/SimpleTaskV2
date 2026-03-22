import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false // Controls the bubble animation

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
                
                // LAYER 1: THE INBOX
                VStack(spacing: 0) {
                    // Custom Header Row
                    HStack {
                        Spacer().frame(width: 44) // Placeholder for the absolute button
                        Spacer()
                        Text("Inbox").font(.title2).bold()
                        Spacer()
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus").font(.title2).foregroundColor(.pink)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    List {
                        if !dueHabits.isEmpty {
                            Section(header: Text("Due Habits").foregroundColor(.orange)) {
                                ForEach(dueHabits) { habit in
                                    HStack {
                                        Text(habit.title).foregroundColor(.white)
                                        Spacer()
                                        Image(systemName: "circle").foregroundColor(.orange)
                                            .onTapGesture { toggleHabit(habit) }
                                    }
                                    .listRowBackground(Color(white: 0.1))
                                }
                            }
                        }
                        
                        Section(header: Text("Tasks").foregroundColor(.pink)) {
                            ForEach(activeTasks) { task in
                                TaskRow(task: task).listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                // LAYER 2: THE BUBBLE OUT MENU
                ZStack {
                    // The expanding colored circle
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isMenuOpen ? 45 : 0.001) // 45x scale covers the entire screen
                        .position(x: 35, y: 30) // Anchored to the button's location
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
                        .ignoresSafeArea()
                    
                    // The Centered Options
                    if isMenuOpen {
                        VStack(alignment: .center, spacing: 50) {
                            NavigationLink(destination: ArchiveView()) { MenuLink(title: "Archive", icon: "archivebox") }
                            NavigationLink(destination: StatsView()) { MenuLink(title: "Statistics", icon: "chart.bar") }
                            NavigationLink(destination: SettingsView()) { MenuLink(title: "Settings", icon: "gearshape") }
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2).delay(0.1)))
                    }
                }
                .allowsHitTesting(isMenuOpen) // Prevents the invisible bubble from stealing touches
                
                // LAYER 3: THE ABSOLUTE BUTTON (Always on top)
                VStack {
                    HStack {
                        HamburgerButton(isOpen: $isMenuOpen)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
            }
            .navigationBarHidden(true) // Turns off Apple's default toolbar
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

// THE HAMBURGER ANIMATION
struct HamburgerButton: View {
    @Binding var isOpen: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isOpen.toggle() }
        }) {
            VStack(spacing: 6) {
                Capsule()
                    .fill(isOpen ? Color.pink : Color.gray)
                    .frame(width: 24, height: 3)
                    .rotationEffect(.degrees(isOpen ? 45 : 0))
                    .offset(y: isOpen ? 9 : 0)
                
                Capsule()
                    .fill(Color.gray)
                    .frame(width: 24, height: 3)
                    .opacity(isOpen ? 0 : 1)
                
                Capsule()
                    .fill(isOpen ? Color.pink : Color.gray)
                    .frame(width: 24, height: 3)
                    .rotationEffect(.degrees(isOpen ? -45 : 0))
                    .offset(y: isOpen ? -9 : 0)
            }
        }
        .frame(width: 44, height: 44, alignment: .leading)
    }
}

// HELPER FOR MENU TEXT
struct MenuLink: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon).foregroundColor(.pink).font(.title)
            Text(title).foregroundColor(.white).font(.system(size: 32, weight: .bold, design: .rounded))
        }
    }
}

// SMOOTH SUBTASK EXPANSION
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
                
                Text(task.title).foregroundColor(task.isCompleted ? .gray : .white).strikethrough(task.isCompleted)
            }
            .padding(.vertical, 4)
        }
        .tint(.gray)
    }
}

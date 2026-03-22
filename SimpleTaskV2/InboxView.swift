import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    private let hapticSound = HapticAndSoundManager.shared

    // THE AUTO-SORT FILTER
    // Keeps incomplete tasks at the top, pushes completed tasks to the bottom
    var activeTasks: [TaskItem] {
        let filtered = allTasks.filter { !$0.isCompleted || ($0.completionDate != nil && Date().timeIntervalSince($0.completionDate!) < 86400) }
        
        return filtered.sorted { task1, task2 in
            if task1.isCompleted == task2.isCompleted {
                return task1.dueDate < task2.dueDate // Sort by date if both are same status
            }
            return !task1.isCompleted && task2.isCompleted // Incomplete always comes first
        }
    }
    
    var dueHabits: [HabitItem] {
        allHabits.filter { !isHabitDone($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // LAYER 0: THE CLEAN MINIMALIST BACKGROUND
                Color(white: 0.05).ignoresSafeArea()
                
                // LAYER 1: THE INBOX LIST
                VStack(spacing: 0) {
                    // Header Row
                    HStack {
                        Spacer().frame(width: 44)
                        Spacer()
                        Text("Inbox").font(.title2).bold().foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            hapticSound.triggerHapticSelection()
                            showingAddSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.pink)
                                .padding(10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
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
                                    .listRowBackground(Color(white: 0.1)) // Subtle contrast for habits
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                        
                        Section(header: Text("Tasks").foregroundColor(.pink)) {
                            ForEach(activeTasks) { task in
                                TaskRowView(task: task)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                // LAYER 2: THE OPAQUE BUBBLE MENU
                ZStack {
                    // Solid, opaque dark gray to prevent text bleeding through
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isMenuOpen ? 45 : 0.001)
                        .position(x: 35, y: 30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
                        .ignoresSafeArea()
                    
                    if isMenuOpen {
                        VStack(alignment: .center, spacing: 50) {
                            NavigationLink(destination: ArchiveView()) { MenuLink(title: "Archive", icon: "archivebox") }
                                .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                            NavigationLink(destination: StatsView()) { MenuLink(title: "Statistics", icon: "chart.bar") }
                                .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                            NavigationLink(destination: SettingsView()) { MenuLink(title: "Settings", icon: "gearshape") }
                                .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2).delay(0.1)))
                    }
                }
                .allowsHitTesting(isMenuOpen)
                
                // LAYER 3: THE ABSOLUTE BUTTON
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
            .navigationBarHidden(true)
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
        hapticSound.triggerHapticSelection()
        hapticSound.playSuccessSound()
        withAnimation { habit.completionDates.append(Date()) }
    }
}

// THE HAMBURGER ANIMATION
struct HamburgerButton: View {
    @Binding var isOpen: Bool
    
    var body: some View {
        Button(action: {
            HapticAndSoundManager.shared.triggerHapticSelection()
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

struct MenuLink: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon).foregroundColor(.pink).font(.largeTitle).frame(width: 50)
            Text(title).foregroundColor(.white).font(.system(size: 32, weight: .bold, design: .rounded))
        }
    }
}

// CLEANED UP TASK ROW WITH NATIVE SF SYMBOLS
struct TaskRowView: View {
    @Bindable var task: TaskItem
    @State private var isExpanded = false
    @State private var newSubtaskTitle = ""
    private let hapticSound = HapticAndSoundManager.shared
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(task.subtasks) { subtask in
                    HStack {
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                            .onTapGesture {
                                hapticSound.triggerHapticSelection()
                                withAnimation { subtask.isCompleted.toggle() }
                                if subtask.isCompleted { hapticSound.playSuccessSound() }
                            }
                        Text(subtask.title)
                            .font(.subheadline)
                            .strikethrough(subtask.isCompleted)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                }
                
                HStack {
                    Image(systemName: "plus.circle").foregroundColor(.gray)
                    TextField("New step...", text: $newSubtaskTitle)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .onSubmit {
                            if !newSubtaskTitle.isEmpty {
                                hapticSound.triggerHapticSuccess()
                                hapticSound.playSuccessSound()
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
                // Reverted back to the clean, native iOS squares
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .gray : .pink)
                    .font(.title3)
                    .onTapGesture {
                        hapticSound.triggerHapticSelection()
                        // Animation triggers the list re-sort so the task slides down
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            task.isCompleted.toggle()
                            task.completionDate = task.isCompleted ? Date() : nil
                        }
                        if task.isCompleted { hapticSound.playCompleteSound() }
                    }
                
                Text(task.title)
                    .foregroundColor(task.isCompleted ? .gray : .white)
                    .strikethrough(task.isCompleted)
            }
            .padding(.vertical, 8)
        }
        .tint(.gray)
    }
}

import SwiftUI
import SwiftData
import PhotosUI
import WidgetKit

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    
    @State private var selectedTask: TaskItem?
    @State private var habitToEdit: HabitItem?
    
    private let hapticSound = HapticAndSoundManager.shared
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    @AppStorage("archiveSetting") private var archiveSetting: String = "Midnight"

    var activeTasks: [TaskItem] {
        let filtered = allTasks.filter { task in
            if !task.isCompleted { return true }
            if let completionDate = task.completionDate {
                if archiveSetting == "24 Hours" {
                    return Date().timeIntervalSince(completionDate) < 86400
                } else if archiveSetting == "Midnight" {
                    return Calendar.current.isDateInToday(completionDate)
                } else {
                    return false
                }
            }
            return false
        }
        
        return filtered.sorted { t1, t2 in
            if t1.isCompleted == t2.isCompleted {
                if t1.order == t2.order { return t1.dueDate < t2.dueDate }
                return t1.order < t2.order
            }
            return !t1.isCompleted
        }
    }
    
    var dueHabits: [HabitItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        
        return allHabits.filter { habit in
            let isScheduledToday = habit.activeDays.contains(weekday) || (habit.activeDays.isEmpty && habit.frequency != .none)
            let isCompletedToday = habit.completionDates.contains { calendar.isDateInToday($0) }
            return isScheduledToday && !isCompletedToday
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color.black : Color.white).ignoresSafeArea()
                
                // 1. MAIN CONTENT LAYER
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)
                    
                    HStack {
                        Text("Inbox")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? .white : .black)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    if activeTasks.isEmpty && dueHabits.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 50)).foregroundColor(.pink.opacity(0.8))
                            Text("All caught up!").font(.title3.bold()).foregroundColor(isDarkMode ? .white : .black)
                            Text("Enjoy your free time.").foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List {
                            if !dueHabits.isEmpty {
                                Section(header: Text("Today's Habits").foregroundColor(.orange).bold()) {
                                    ForEach(dueHabits) { habit in
                                        HStack {
                                            let isCompletedToday = habit.completionDates.contains { Calendar.current.isDateInToday($0) }
                                            Image(systemName: isCompletedToday ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(isCompletedToday ? .orange : .gray)
                                                .font(.title2)
                                                .contentShape(Circle())
                                                .onTapGesture { toggleHabit(habit) }
                                            
                                            HStack {
                                                Text(habit.title).foregroundColor(isDarkMode ? .white : .black)
                                                Spacer()
                                                
                                                // FIX: Only render the HStack (Text AND Flame) if streak > 0
                                                if habit.streak > 0 {
                                                    HStack(spacing: 4) {
                                                        Text("\(habit.streak)")
                                                            .font(.caption)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(.orange)
                                                        Image(systemName: "flame.fill").foregroundColor(.orange).font(.caption)
                                                    }
                                                }
                                            }
                                            .contentShape(Rectangle())
                                            .onTapGesture { habitToEdit = habit }
                                        }
                                        // Note: Swipe firmly all the way across the screen to auto-execute!
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            if leftSwipeAction != .none {
                                                Button { handleHabitSwipe(option: leftSwipeAction, habit: habit) } label: { Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon) }.tint(leftSwipeAction.color)
                                            }
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            if rightSwipeAction != .none {
                                                Button { handleHabitSwipe(option: rightSwipeAction, habit: habit) } label: { Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon) }.tint(rightSwipeAction.color)
                                            }
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.visible)
                                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                    }
                                }
                            }
                            
                            if !activeTasks.isEmpty {
                                Section(header: Text("Tasks").foregroundColor(.pink).bold()) {
                                    ForEach(activeTasks) { task in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(task.isCompleted ? .pink : .gray)
                                                    .font(.title2)
                                                    .contentShape(Circle())
                                                    .onTapGesture { toggleTask(task) }
                                                
                                                HStack {
                                                    Text(task.title)
                                                        .strikethrough(task.isCompleted)
                                                        .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                                                    Spacer()
                                                    if !task.isCompleted {
                                                        let isOverdue = Calendar.current.startOfDay(for: task.dueDate) < Calendar.current.startOfDay(for: Date())
                                                        
                                                        Text(task.dueDate.formatted(.dateTime.month().day()))
                                                            .font(.caption2)
                                                            .foregroundColor(isOverdue ? .red.opacity(0.7) : (isDarkMode ? .gray.opacity(0.8) : .gray))
                                                    }
                                                }
                                                .contentShape(Rectangle())
                                                .onTapGesture { selectedTask = task }
                                            }
                                            
                                            if !task.subtasks.isEmpty {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    ForEach(task.subtasks) { subtask in
                                                        HStack {
                                                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                                                .foregroundColor(subtask.isCompleted ? .pink : .gray)
                                                                .font(.caption)
                                                                .contentShape(Circle())
                                                                .onTapGesture {
                                                                    withAnimation {
                                                                        subtask.isCompleted.toggle()
                                                                        try? modelContext.save()
                                                                    }
                                                                }
                                                            
                                                            Text(subtask.title)
                                                                .font(.subheadline)
                                                                .strikethrough(subtask.isCompleted)
                                                                .foregroundColor(subtask.isCompleted ? .gray : (isDarkMode ? .gray : .black.opacity(0.7)))
                                                            
                                                            Spacer()
                                                        }
                                                    }
                                                }
                                                .padding(.leading, 32)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            if leftSwipeAction != .none {
                                                Button { handleTaskSwipe(option: leftSwipeAction, task: task) } label: { Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon) }.tint(leftSwipeAction.color)
                                            }
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            if rightSwipeAction != .none {
                                                Button { handleTaskSwipe(option: rightSwipeAction, task: task) } label: { Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon) }.tint(rightSwipeAction.color)
                                            }
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.visible)
                                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                    }
                                    .onMove(perform: moveTask)
                                }
                            }
                            
                            Color.clear
                                .frame(height: 80)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                
                // 2. CLICK-OUTSIDE INTERCEPTOR
                if isMenuOpen {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                isMenuOpen = false
                            }
                        }
                        .zIndex(1)
                }
                
                // 3. THE BUBBLE OVERLAY MENU
                // FIX: Structurally mirroring the Top App Bar to guarantee 100% perfect origin matching
                VStack {
                    HStack {
                        // Invisible anchor that is exactly the same size/position as the Hamburger Button
                        Color.clear
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .fill(isDarkMode ? Color(white: 0.1) : Color(white: 0.92))
                                    .frame(width: 2500, height: 2500)
                                    .scaleEffect(isMenuOpen ? 1 : 0, anchor: .center)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isMenuOpen)
                            )
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .ignoresSafeArea(edges: .bottom) // Allows it to cover the bottom screen, but respect top notch
                .allowsHitTesting(false)
                .zIndex(2)
                
                // 4. THE MENU LINKS
                if isMenuOpen {
                    VStack(alignment: .center, spacing: 35) {
                        Text("Menu")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .padding(.bottom, 10)
                        
                        NavigationLink(destination: ArchiveView()) { MenuLink(title: "Archive", icon: "archivebox") }
                            .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                        NavigationLink(destination: StatsView()) { MenuLink(title: "Analytics", icon: "chart.bar.xaxis") }
                            .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                        NavigationLink(destination: SettingsView()) { MenuLink(title: "Settings", icon: "gearshape") }
                            .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.opacity.animation(.easeInOut.delay(0.15)))
                    .zIndex(3)
                }
                
                // 5. TOP APP BAR
                VStack {
                    HStack {
                        HamburgerButton(isOpen: $isMenuOpen)
                        
                        Spacer()
                        
                        Button(action: {
                            hapticSound.triggerHapticSelection()
                            showingAddSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.pink)
                                .clipShape(Circle())
                                .shadow(color: .pink.opacity(0.4), radius: 5, x: 0, y: 3)
                        }
                        .opacity(isMenuOpen ? 0 : 1)
                        .animation(.easeInOut, value: isMenuOpen)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .zIndex(4)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                AddTaskView().presentationDetents([.large])
            }
            .sheet(item: $selectedTask) { task in
                AddTaskView(taskToEdit: task).presentationDetents([.large])
            }
            .sheet(item: $habitToEdit) { habit in
                AddHabitView(habitToEdit: habit).presentationDetents([.large])
            }
        }
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        var sortedTasks = activeTasks
        sortedTasks.move(fromOffsets: source, toOffset: destination)
        for (index, task) in sortedTasks.enumerated() { task.order = index }
        try? modelContext.save()
    }
    
    private func toggleTask(_ task: TaskItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            task.isCompleted.toggle()
            if task.isCompleted {
                task.completionDate = Date()
                hapticSound.triggerHapticSuccess(); hapticSound.playCompleteSound()
            } else {
                task.completionDate = nil
                hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound()
            }
            try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func toggleHabit(_ habit: HabitItem) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let isCompletedToday = habit.completionDates.contains { calendar.isDateInToday($0) }
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isCompletedToday {
                habit.completionDates.removeAll { calendar.isDate($0, equalTo: today, toGranularity: .day) }
                hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound()
            } else {
                habit.completionDates.append(Date())
                hapticSound.triggerHapticSuccess(); hapticSound.playCompleteSound()
            }
            try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func handleTaskSwipe(option: SwipeOption, task: TaskItem) {
        switch option {
        case .edit: selectedTask = task
        case .delete: withAnimation { modelContext.delete(task); try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() }
        case .toggle: toggleTask(task)
        case .none: break
        }
    }
    
    private func handleHabitSwipe(option: SwipeOption, habit: HabitItem) {
        switch option {
        case .edit: habitToEdit = habit
        case .delete: withAnimation { modelContext.delete(habit); try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() }
        case .toggle: toggleHabit(habit)
        case .none: break
        }
    }
}

struct HamburgerButton: View {
    @Binding var isOpen: Bool
    @AppStorage("isDarkMode") private var isDarkMode = true
    var body: some View {
        Button(action: {
            HapticAndSoundManager.shared.triggerHapticSelection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isOpen.toggle() }
        }) {
            VStack(spacing: 6) {
                Capsule().fill(isOpen ? Color.pink : (isDarkMode ? Color.gray : Color.black)).frame(width: 24, height: 3).rotationEffect(.degrees(isOpen ? 45 : 0)).offset(y: isOpen ? 9 : 0)
                Capsule().fill(isDarkMode ? Color.gray : Color.black).frame(width: 24, height: 3).opacity(isOpen ? 0 : 1)
                Capsule().fill(isOpen ? Color.pink : (isDarkMode ? Color.gray : Color.black)).frame(width: 24, height: 3).rotationEffect(.degrees(isOpen ? -45 : 0)).offset(y: isOpen ? -9 : 0)
            }
        }
        .frame(width: 44, height: 44, alignment: .leading)
    }
}

struct MenuLink: View {
    let title: String
    let icon: String
    @AppStorage("isDarkMode") private var isDarkMode = true
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.pink)
                .frame(width: 32)
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(isDarkMode ? .white : .black)
        }
        .frame(width: 180, alignment: .leading)
    }
}

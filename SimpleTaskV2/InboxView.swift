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
                                Section(header: Text("Today's Habits").foregroundColor(.orange).bold().padding(.leading, 8)) {
                                    ForEach(dueHabits) { habit in
                                        VStack(spacing: 0) {
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
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 16)
                                            .customSwipeActions(
                                                left: leftSwipeAction,
                                                right: rightSwipeAction,
                                                onLeft: { handleHabitSwipe(option: leftSwipeAction, habit: habit) },
                                                onRight: { handleHabitSwipe(option: rightSwipeAction, habit: habit) }
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            
                                            Divider().padding(.leading, 50)
                                        }
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                    }
                                }
                            }
                            
                            if !activeTasks.isEmpty {
                                Section(header: Text("Tasks").foregroundColor(.pink).bold().padding(.leading, 8).padding(.top, 10)) {
                                    ForEach(activeTasks) { task in
                                        VStack(spacing: 0) {
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
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .customSwipeActions(
                                                left: leftSwipeAction,
                                                right: rightSwipeAction,
                                                onLeft: { handleTaskSwipe(option: leftSwipeAction, task: task) },
                                                onRight: { handleTaskSwipe(option: rightSwipeAction, task: task) }
                                            )
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            
                                            Divider().padding(.leading, 50)
                                        }
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
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
                VStack {
                    HStack {
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
                .ignoresSafeArea(edges: .bottom)
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

// ---------------------------------------------------------
// CUSTOM SWIPE GESTURE MODIFIER
// ---------------------------------------------------------
struct SwipeRowModifier: ViewModifier {
    let leftOption: SwipeOption
    let rightOption: SwipeOption
    let onLeftSwipe: () -> Void
    let onRightSwipe: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var triggered = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    private let triggerThreshold: CGFloat = 40
    
    func body(content: Content) -> some View {
        ZStack {
            // Background Layer (The Cutout)
            GeometryReader { geo in
                ZStack {
                    if offset > 0 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(leftOption.color)
                            .overlay(
                                HStack {
                                    Image(systemName: leftOption.icon)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                        .scaleEffect(offset > triggerThreshold ? 1.2 : 0.8)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: offset > triggerThreshold)
                                        .padding(.leading, 20)
                                    Spacer()
                                }
                            )
                    }
                    
                    if offset < 0 {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(rightOption.color)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Image(systemName: rightOption.icon)
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                        .scaleEffect(offset < -triggerThreshold ? 1.2 : 0.8)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: offset < -triggerThreshold)
                                        .padding(.trailing, 20)
                                }
                            )
                    }
                }
            }
            
            // Foreground Layer (The Sliding Row)
            content
                // FIX 2: Reverted background to match exactly with the app theme so it is completely flush
                .background(isDarkMode ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .offset(x: offset)
                .gesture(
                    // FIX 1: minimumDistance of 30 allows vertical scrolling to dominate before dragging starts
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            let drag = value.translation.width
                            offset = drag > 0 ? pow(drag, 0.9) : -pow(-drag, 0.9)
                            
                            if offset > triggerThreshold && !triggered && leftOption != .none {
                                HapticAndSoundManager.shared.triggerHapticSelection()
                                triggered = true
                            } else if offset < -triggerThreshold && !triggered && rightOption != .none {
                                HapticAndSoundManager.shared.triggerHapticSelection()
                                triggered = true
                            } else if abs(offset) < triggerThreshold {
                                triggered = false
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                if offset > triggerThreshold && leftOption != .none {
                                    onLeftSwipe()
                                } else if offset < -triggerThreshold && rightOption != .none {
                                    onRightSwipe()
                                }
                                offset = 0
                                triggered = false
                            }
                        }
                )
        }
    }
}

extension View {
    func customSwipeActions(left: SwipeOption, right: SwipeOption, onLeft: @escaping () -> Void, onRight: @escaping () -> Void) -> some View {
        self.modifier(SwipeRowModifier(leftOption: left, rightOption: right, onLeftSwipe: onLeft, onRightSwipe: onRight))
    }
}

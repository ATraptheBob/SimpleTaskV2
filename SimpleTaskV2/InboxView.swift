import SwiftUI
import SwiftData
import PhotosUI
import WidgetKit

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    // The query can only sort on Comparable properties (like String, Date, Int).
    // isCompleted is a Bool, which is NOT Comparable in SwiftData, so we cannot sort by it directly in the query.
    // However, we CAN sort by order, then dueDate, taking 2/3 of the work off the in-memory sort.
    @Query(sort: [
        SortDescriptor(\TaskItem.order, order: .forward),
        SortDescriptor(\TaskItem.dueDate, order: .forward)
    ]) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    
    @State private var expandedTaskId: UUID? = nil
    @State private var habitToEdit: HabitItem?
    
    // Calendar Popup States
    @State private var taskToReschedule: TaskItem?
    @State private var tempDate: Date = Date()
    
    private let hapticSound = HapticAndSoundManager.shared
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .date
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    @AppStorage("archiveSetting") private var archiveSetting: String = "Midnight"

    var activeTasks: [TaskItem] {
        let now = Date()
        let calendar = Calendar.current

        let filtered = allTasks.filter { task in
            if !task.isCompleted { return true }
            guard let completionDate = task.completionDate else { return false }

            if archiveSetting == "24 Hours" {
                return now.timeIntervalSince(completionDate) < 86400
            } else if archiveSetting == "Midnight" {
                return calendar.isDateInToday(completionDate)
            }
            return false
        }
        
        return filtered.sorted { t1, t2 in
            if t1.isCompleted != t2.isCompleted {
                return !t1.isCompleted
            }
            if t1.order != t2.order {
                return t1.order < t2.order
            }
            if let d1 = t1.dueDate, let d2 = t2.dueDate { return d1 < d2 }
            if t1.dueDate != nil { return true }
            if t2.dueDate != nil { return false }
            return false
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
                                            TaskRowView(
                                                task: task,
                                                isExpanded: expandedTaskId == task.id,
                                                isDarkMode: isDarkMode,
                                                toggleTask: { toggleTask(task) },
                                                onToggleExpand: {
                                                    if expandedTaskId == task.id {
                                                        expandedTaskId = nil
                                                    } else {
                                                        expandedTaskId = task.id
                                                    }
                                                },
                                                onOpenCalendar: {
                                                    tempDate = task.dueDate ?? Date()
                                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                                        taskToReschedule = task
                                                    }
                                                }
                                            )
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
                                .accessibilityLabel("Add New Task")
                        }
                        .opacity(isMenuOpen ? 0 : 1)
                        .animation(.easeInOut, value: isMenuOpen)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .zIndex(4)
                
                // 6. THE CALENDAR POPUP LAYER
                if let task = taskToReschedule {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                task.dueDate = tempDate
                                try? modelContext.save()
                                taskToReschedule = nil
                            }
                        }
                        .zIndex(5)
                    
                    VStack(spacing: 20) {
                        Text("Due Date")
                            .font(.title2.bold())
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        DatePicker("", selection: $tempDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.purple)
                            .labelsHidden()
                        
                        HStack(spacing: 15) {
                            Button(action: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    task.dueDate = nil
                                    try? modelContext.save()
                                    taskToReschedule = nil
                                }
                            }) {
                                Text("Clear Date")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(isDarkMode ? Color(white: 0.15) : Color(white: 0.95))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    task.dueDate = Date()
                                    try? modelContext.save()
                                    taskToReschedule = nil
                                }
                            }) {
                                Text("Today")
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.purple)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(24)
                    .background(isDarkMode ? Color(white: 0.1) : Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
                    .padding(.horizontal, 30)
                    .zIndex(6)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .scale(scale: 0.98).combined(with: .opacity)
                    ))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                AddTaskView().presentationDetents([.large])
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
                habit.updateStreak()
                hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound()
            } else {
                habit.completionDates.append(Date())
                habit.updateStreak()
                hapticSound.triggerHapticSuccess(); hapticSound.playCompleteSound()
            }
            try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func handleTaskSwipe(option: SwipeOption, task: TaskItem) {
        switch option {
        case .edit:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if expandedTaskId == task.id {
                    expandedTaskId = nil
                } else {
                    expandedTaskId = task.id
                }
            }
        case .delete:
            withAnimation {
                modelContext.delete(task)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
        case .toggle:
            toggleTask(task)
        case .date:
            tempDate = task.dueDate ?? Date()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                taskToReschedule = task
            }
        case .none: break
        }
    }
    
    private func handleHabitSwipe(option: SwipeOption, habit: HabitItem) {
        switch option {
        case .edit: habitToEdit = habit
        case .delete: withAnimation { modelContext.delete(habit); try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() }
        case .toggle: toggleHabit(habit)
        case .date: break
        case .none: break
        }
    }

}

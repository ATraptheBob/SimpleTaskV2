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
                if t1.order == t2.order {
                    if let d1 = t1.dueDate, let d2 = t2.dueDate { return d1 < d2 }
                    else if t1.dueDate != nil { return true }
                    else if t2.dueDate != nil { return false }
                    return false
                }
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

// ---------------------------------------------------------
// REFACTORED INLINE TASK CARD
// ---------------------------------------------------------
struct TaskRowView: View {
    @Bindable var task: TaskItem
    var isExpanded: Bool
    var isDarkMode: Bool
    var toggleTask: () -> Void
    var onToggleExpand: () -> Void
    var onOpenCalendar: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    // FIX: Using an Edit Mode toggle specifically for Notes
    @State private var isEditingNotes = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // HEADER ROW (Always visible)
            HStack(alignment: .top) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .pink : .gray)
                    .font(.title2)
                    .contentShape(Circle())
                    .onTapGesture { toggleTask() }
                
                VStack(alignment: .leading, spacing: 4) {
                    if isExpanded {
                        TextField("Task Title", text: $task.title)
                            .font(.body)
                            .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(task.isCompleted)
                    } else {
                        Text(task.title)
                            .font(.body)
                            .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(task.isCompleted)
                    }
                    
                    if !task.isCompleted, let date = task.dueDate {
                        let isOverdue = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
                        Text(date.formatted(.dateTime.month().day()))
                            .font(.caption2)
                            .foregroundColor(isOverdue ? .red.opacity(0.7) : (isDarkMode ? .gray.opacity(0.8) : .gray))
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle()) // Confines the expand tap to the header ONLY
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isExpanded {
                        isEditingNotes = false // Reset notes to view mode
                        try? modelContext.save()
                        onToggleExpand()
                    } else {
                        onToggleExpand()
                    }
                }
            }
            
            // EXPANDED DETAILS
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. SUBTASKS (Top Priority)
                    if !task.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(task.subtasks) { subtask in
                                SubtaskRowView(
                                    subtask: subtask,
                                    isDarkMode: isDarkMode,
                                    onDelete: {
                                        withAnimation {
                                            if let idx = task.subtasks.firstIndex(of: subtask) {
                                                task.subtasks.remove(at: idx)
                                                modelContext.delete(subtask)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.leading, 32)
                    }
                    
                    // 2. NOTES (Always Visible, with Edit Button)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes").font(.caption.bold()).foregroundColor(.gray)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isEditingNotes.toggle()
                                    if !isEditingNotes { try? modelContext.save() }
                                }
                            }) {
                                Text(isEditingNotes ? "Done" : (task.notes.isEmpty ? "Add" : "Edit"))
                                    .font(.caption.bold())
                                    .foregroundColor(isEditingNotes ? .green : .gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(isDarkMode ? Color(white: 0.25) : Color(white: 0.85))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain) // FIX: Isolates tap target
                        }
                        
                        if isEditingNotes {
                            TextField("Add markdown notes or links...", text: $task.notes, axis: .vertical)
                                .font(.callout)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(12)
                                .background(isDarkMode ? Color.black.opacity(0.4) : Color.white.opacity(0.8))
                                .cornerRadius(12)
                        } else {
                            if task.notes.isEmpty {
                                Text("No notes provided.")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)
                                    .onTapGesture { withAnimation { isEditingNotes = true } }
                            } else {
                                // FIX: .init() allows standard URLs to be natively formatted as clickable links!
                                Text(.init(task.notes))
                                    .font(.callout)
                                    .tint(.blue)
                                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(isDarkMode ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                    // 3. IMAGE
                    if let data = task.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .cornerRadius(12)
                            .contextMenu {
                                Button("Remove Image", role: .destructive) {
                                    withAnimation {
                                        task.imageData = nil
                                        try? modelContext.save()
                                    }
                                }
                            }
                    }
                    
                    // 4. MICROBUTTONS ROW (Isolated Buttons)
                    HStack(spacing: 16) {
                        Spacer()
                        
                        Button(action: onOpenCalendar) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.purple)
                                .frame(width: 32, height: 32)
                                .background(isDarkMode ? Color(white: 0.25) : Color(white: 0.85))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain) // FIX: Prevents mass-activation
                        
                        Button(action: {
                            withAnimation { task.subtasks.append(SubtaskItem(title: "")) }
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(isDarkMode ? Color(white: 0.25) : Color(white: 0.85))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain) // FIX: Prevents mass-activation
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Image(systemName: task.imageData == nil ? "photo" : "photo.badge.checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.green)
                                .frame(width: 32, height: 32)
                                .background(isDarkMode ? Color(white: 0.25) : Color(white: 0.85))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain) // FIX: Prevents mass-activation
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            task.imageData = data
                                            try? modelContext.save()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isExpanded ? (isDarkMode ? Color(white: 0.15) : Color(white: 0.95)) : Color.clear)
        .cornerRadius(isExpanded ? 16 : 0)
    }
}

// ---------------------------------------------------------
// INLINE SUBTASK ROW
// ---------------------------------------------------------
struct SubtaskRowView: View {
    @Bindable var subtask: SubtaskItem
    var isDarkMode: Bool
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(subtask.isCompleted ? .pink : .gray)
                .font(.caption)
                .onTapGesture {
                    withAnimation { subtask.isCompleted.toggle() }
                }
            
            TextField("Step", text: $subtask.title)
                .font(.subheadline)
                .strikethrough(subtask.isCompleted)
                .foregroundColor(subtask.isCompleted ? .gray : (isDarkMode ? .gray : .black.opacity(0.7)))
            
            Spacer()
            
            if subtask.title.isEmpty || subtask.isCompleted {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .onTapGesture { onDelete() }
            }
        }
        .padding(.vertical, 4)
    }
}

// ---------------------------------------------------------
// OTHER EXISTING COMPONENTS
// ---------------------------------------------------------
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
            
            content
                .background(isDarkMode ? Color.black : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .offset(x: offset)
                .gesture(
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

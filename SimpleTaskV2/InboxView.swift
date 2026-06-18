import SwiftUI
import EventKit
import SwiftData
import PhotosUI
import WidgetKit
internal import Combine

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var eventKitManager = EventKitManager.shared
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    
    // Morning Briefing State
    @State private var showingMorningApproval = false
    @State private var morningBriefing: MorningBriefing? = nil
    @State private var isFetchingBriefing = false
    
    @State private var expandedTaskId: String? = nil
    @State private var habitToEdit: HabitItem?
    
    // Calendar Popup States
    @State private var taskToReschedule: AppTask?
    @State private var tempDate: Date = Date()
    
    // List Reorder
    @StateObject private var calendarOrderManager = CalendarOrderManager()
    @State private var isReorderingLists = false
    @State private var reorderableCalendarIds: [String] = []
    
    private let hapticSound = HapticAndSoundManager.shared
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .date
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    @AppStorage("archiveSetting") private var archiveSetting: String = "Midnight"

    var activeTasks: [AppTask] {
        let now = Date()
        let calendar = Calendar.current

        let filtered = eventKitManager.reminders.filter { task in
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
            // EventKit tasks are returned mostly ordered, but we can rely on due date
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
            let isScheduledToday = habit.activeDays.contains(weekday) || (habit.activeDays.isEmpty && habit.frequency != RepeatInterval.none)
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
                        
                        Button(action: {
                            let calendars = eventKitManager.getCalendars()
                            let sorted = calendarOrderManager.sort(calendars)
                            reorderableCalendarIds = sorted.map { $0.calendarIdentifier }
                            isReorderingLists = true
                        }) {
                            Image(systemName: "list.bullet.indent")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 8)
                        
                        if isFetchingBriefing {
                            ProgressView()
                                .tint(.pink)
                        } else {
                            Button(action: fetchMorningBriefing) {
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundColor(.pink)
                            }
                        }
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
                                let groupedTasks = Dictionary(grouping: activeTasks, by: { $0.reminder.calendar })
                                let allCalendars = groupedTasks.keys.compactMap { $0 }
                                let sortedCalendars = calendarOrderManager.sort(allCalendars).filter { !calendarOrderManager.isHidden($0.calendarIdentifier) }
                                
                                ForEach(sortedCalendars, id: \.calendarIdentifier) { calendar in
                                    Section(header: 
                                        Text(calendar.title)
                                            .foregroundColor(Color(cgColor: calendar.cgColor))
                                            .bold()
                                            .padding(.leading, 8)
                                            .padding(.top, 10)
                                    ) {
                                        ForEach(groupedTasks[calendar] ?? []) { task in
                                            VStack(spacing: 0) {
                                                let binding = Binding(
                                                    get: { task },
                                                    set: { updatedTask in
                                                        if let index = eventKitManager.reminders.firstIndex(where: { $0.id == updatedTask.id }) {
                                                            eventKitManager.reminders[index] = updatedTask
                                                        }
                                                    }
                                                )
                                                
                                                TaskRowView(
                                                    task: binding,
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
                                    }
                                }
                            }
                            
                            Color.clear
                                .frame(height: 80)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable {
                            await eventKitManager.loadData()
                        }
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
                                if var t = taskToReschedule {
                                    t.dueDate = tempDate
                                    try? eventKitManager.updateTask(t)
                                    taskToReschedule = nil
                                }
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
                                if var t = taskToReschedule {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        t.dueDate = nil
                                        try? eventKitManager.updateTask(t)
                                        taskToReschedule = nil
                                    }
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
                                if var t = taskToReschedule {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                        t.dueDate = tempDate
                                        try? eventKitManager.updateTask(t)
                                        taskToReschedule = nil
                                    }
                                }
                            }) {
                                Text("Reschedule")
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
            .fullScreenCover(isPresented: $showingMorningApproval) {
                if let briefing = morningBriefing {
                    MorningApprovalView(briefing: briefing, isPresented: $showingMorningApproval)
                }
            }
            .sheet(isPresented: $isReorderingLists) {
                ReorderListsSheet(
                    calendarIds: $reorderableCalendarIds,
                    calendars: eventKitManager.getCalendars(),
                    isDarkMode: isDarkMode,
                    onSave: { newOrder in
                        calendarOrderManager.updateOrder(from: newOrder)
                    },
                    isHidden: { id in
                        calendarOrderManager.isHidden(id)
                    },
                    toggleHidden: { id in
                        calendarOrderManager.toggleHidden(id)
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }
    
    private func fetchMorningBriefing() {
        Task {
            isFetchingBriefing = true
            do {
                var fetchedEmails: [String] = []
                if GoogleWorkspaceManager.shared.isSignedIn {
                    let emailJson = try await GoogleWorkspaceManager.shared.fetchRecentImportantEmails()
                    fetchedEmails = [emailJson] // Or parse if you implement real Gmail API
                }
                
                let briefing = try await GeminiManager.shared.generateMorningBriefing(
                    events: eventKitManager.events,
                    reminders: eventKitManager.reminders.map { $0.reminder },
                    emails: fetchedEmails
                )
                DispatchQueue.main.async {
                    self.morningBriefing = briefing
                    self.showingMorningApproval = true
                    self.isFetchingBriefing = false
                }
            } catch {
                print("Failed to fetch briefing: \(error)")
                DispatchQueue.main.async { self.isFetchingBriefing = false }
            }
        }
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        // Disabled for EventKit
    }
    
    private func toggleTask(_ task: AppTask) {
        var mutableTask = task
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            mutableTask.isCompleted.toggle()
            if mutableTask.isCompleted {
                mutableTask.completionDate = Date()
                hapticSound.triggerHapticSuccess(); hapticSound.playCompleteSound()
            } else {
                mutableTask.completionDate = nil
                hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound()
            }
            try? eventKitManager.updateTask(mutableTask)
            WidgetCenter.shared.reloadAllTimelines()
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
    
    private func handleTaskSwipe(option: SwipeOption, task: AppTask) {
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
                try? eventKitManager.deleteTask(task)
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

class CalendarOrderManager: ObservableObject {
    @AppStorage("calendarOrder") var calendarOrderString: String = ""
    @AppStorage("hiddenCalendars") var hiddenCalendarsString: String = ""
    
    var order: [String] {
        get {
            calendarOrderString.split(separator: ",").map(String.init)
        }
        set {
            calendarOrderString = newValue.joined(separator: ",")
        }
    }
    
    var hiddenIds: Set<String> {
        get {
            Set(hiddenCalendarsString.split(separator: ",").map(String.init))
        }
        set {
            hiddenCalendarsString = newValue.joined(separator: ",")
        }
    }
    
    func sort(_ calendars: [EKCalendar]) -> [EKCalendar] {
        let currentOrder = order
        return calendars.sorted { cal1, cal2 in
            let idx1 = currentOrder.firstIndex(of: cal1.calendarIdentifier) ?? Int.max
            let idx2 = currentOrder.firstIndex(of: cal2.calendarIdentifier) ?? Int.max
            if idx1 == idx2 {
                return cal1.title < cal2.title
            }
            return idx1 < idx2
        }
    }
    
    func updateOrder(from ids: [String]) {
        order = ids
        objectWillChange.send()
    }
    
    func toggleHidden(_ id: String) {
        var currentHidden = hiddenIds
        if currentHidden.contains(id) {
            currentHidden.remove(id)
        } else {
            currentHidden.insert(id)
        }
        hiddenIds = currentHidden
        objectWillChange.send()
    }
    
    func isHidden(_ id: String) -> Bool {
        hiddenIds.contains(id)
    }
}

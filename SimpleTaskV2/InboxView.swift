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
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @State private var expandedTaskId: String? = nil
    @State private var habitToEdit: HabitItem?
    
    // AI States
    @State private var showingAIActions = false
    @State private var showingEveningApproval = false
    @State private var eveningBriefing: EveningBriefing?
    @State private var showingQuickCapture = false
    @State private var quickCaptureText = ""
    @State private var searchText = ""
    
    // Voice Capture State
    @StateObject private var voiceManager = VoiceCaptureManager()
    @State private var isVoiceCapturing = false
    @State private var isPressDown = false
    @State private var isParsingVoiceTask = false
    @State private var voiceTaskPlaceholderText = ""
    
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
        let cal = Calendar.current
        let now = Date()
        
        let tasks = eventKitManager.reminders.filter { task in
            if !searchText.isEmpty && !task.title.localizedCaseInsensitiveContains(searchText) {
                return false
            }

            if archiveSetting == "Midnight" {
                return !task.isCompleted || cal.isDateInToday(task.completionDate ?? Date.distantPast)
            } else if archiveSetting == "24 Hours" {
                return !task.isCompleted || now.timeIntervalSince(task.completionDate ?? Date.distantPast) < 86400
            }

            return true
        }
        
        return tasks.sorted { t1, t2 in
            if t1.isCompleted != t2.isCompleted {
                return !t1.isCompleted
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
            let isScheduledToday = habit.activeDays.contains(weekday) || (habit.activeDays.isEmpty && habit.frequency != RepeatInterval.none)
            guard isScheduledToday else { return false } // Short-circuit: skip date check if not scheduled
            let isCompletedToday = habit.completionDates.contains { calendar.isDateInToday($0) }
            return !isCompletedToday
        }
    }

    var body: some View {
        // PERFORMANCE OPTIMIZATION:
        // `activeTasks` (O(N log N)) and `dueHabits` (O(N)) are expensive computed properties.
        // We cache them locally once per body evaluation to prevent them from executing
        // 4-5 redundant times during high-frequency renders (like when typing in `searchText`).
        // Impact: Reduces CPU work for sorting/filtering by ~80% per keystroke search.
        let currentActiveTasks = activeTasks
        let currentDueHabits = dueHabits

        return NavigationStack {
            ZStack {
                DynamicBackgroundView()
                
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
                            Button(action: { showingAIActions = true }) {
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundColor(.pink)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search tasks...", text: $searchText)
                            .foregroundColor(isDarkMode ? .white : .black)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(10)
                    .background(isDarkMode ? Color(white: 0.15) : Color(white: 0.95))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    if !currentActiveTasks.isEmpty {
                        let now = Date()
                        let overdueCount = currentActiveTasks.filter { !$0.isCompleted && ($0.dueDate ?? Date.distantFuture) < now }.count
                        if overdueCount > 0 {
                            Button(action: { runAutoReschedule() }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.right.circle.fill").foregroundColor(.pink)
                                    Text("\(overdueCount) Overdue")
                                        .font(.subheadline.bold())
                                        .foregroundColor(isDarkMode ? .white : .black)
                                    Spacer()
                                    Text("Auto-Reschedule")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.pink)
                                        .cornerRadius(8)
                                }
                                .padding(12)
                                .background(isDarkMode ? Color(white: 0.15) : Color(white: 0.95))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        }
                    }
                    
                    if currentActiveTasks.isEmpty && currentDueHabits.isEmpty && !isParsingVoiceTask {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 50)).foregroundColor(.pink.opacity(0.8))
                            Text("All caught up!").font(.title3.bold()).foregroundColor(isDarkMode ? .white : .black)
                            Text("Enjoy your free time.").foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List {
                            if isParsingVoiceTask {
                                Section(header: Text("Processing AI Task").foregroundColor(.pink).bold().padding(.leading, 8)) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.pink)
                                            .font(.title2)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(voiceTaskPlaceholderText)
                                                .foregroundColor(isDarkMode ? .white : .black)
                                                .lineLimit(1)
                                                .font(.body)
                                            Text("Gemini is structuring your task...")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        ProgressView()
                                            .tint(.pink)
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            
                            if !currentDueHabits.isEmpty {
                                Section(header: Text("Today's Habits").foregroundColor(.orange).bold().padding(.leading, 8)) {
                                    ForEach(currentDueHabits) { habit in
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
                            
                            if !currentActiveTasks.isEmpty {
                                let groupedTasks = Dictionary(grouping: currentActiveTasks, by: { $0.reminder.calendar })
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
                // 3. THE MATERIAL OVERLAY
                if isMenuOpen {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(2)
                }
                
                // 4. THE MENU LINKS
                if isMenuOpen {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Menu")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .padding(.bottom, 20)
                            .padding(.horizontal, 8)
                        
                        NavigationLink(destination: ArchiveView()) {
                            MenuLink(title: "Archive", icon: "archivebox", subtitle: "View completed and deleted tasks", badgeCount: nil)
                        }
                        .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                        NavigationLink(destination: StatsView()) {
                            MenuLink(title: "Analytics", icon: "chart.bar.xaxis", subtitle: "Your productivity trends and habits", badgeCount: nil)
                        }
                        .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                        NavigationLink(destination: SettingsView()) {
                            MenuLink(title: "Settings", icon: "gearshape", subtitle: "Preferences and API setup", badgeCount: nil)
                        }
                        .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(3)
                }
                
                // 5. TOP APP BAR
                VStack {
                    HStack {
                        HamburgerButton(isOpen: $isMenuOpen)
                        
                        Spacer()
                        
                        addButton
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
                                    NotificationManager.shared.scheduleTaskReminders(task: t)
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
                                        NotificationManager.shared.cancelTaskReminders(taskId: t.id)
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
                                        NotificationManager.shared.scheduleTaskReminders(task: t)
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
                
                if isVoiceCapturing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .zIndex(7)
                    
                    VoiceCaptureOverlayView(voiceManager: voiceManager, isDarkMode: isDarkMode)
                        .zIndex(8)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                AddTaskView().presentationDetents([.large])
            }
            .sheet(item: $habitToEdit) { habit in
                AddHabitView(habitToEdit: habit).presentationDetents([.large])
            }
            .sheet(isPresented: $showingAIActions) {
                AIActionsSheet(
                    isPresented: $showingAIActions,
                    onMorningBrief: fetchMorningBriefing,
                    onEveningBrief: fetchEveningBriefing,
                    onLabelImportance: runLabelImportance,
                    onPredictDuration: runPredictDurations,
                    onPlanMyDay: runPlanMyDay,
                    onQuickCapture: { showingQuickCapture = true },
                    onSmartContext: runSmartContext,
                    onAutoReschedule: runAutoReschedule
                )
            }
            .fullScreenCover(isPresented: Binding(
                get: { showingEveningApproval && eveningBriefing != nil },
                set: { if !$0 { showingEveningApproval = false } }
            )) {
                if let briefing = eveningBriefing {
                    EveningReviewView(isPresented: $showingEveningApproval, briefing: briefing)
                }
            }
            .alert("Quick Capture", isPresented: $showingQuickCapture) {
                TextField("e.g. Call mom at 5pm and buy milk", text: $quickCaptureText)
                Button("Cancel", role: .cancel) { quickCaptureText = "" }
                Button("Add") { runQuickCapture(text: quickCaptureText) }
            } message: {
                Text("Type a task or multiple tasks in natural language.")
            }
            .fullScreenCover(isPresented: $showingMorningApproval) {
                if let briefing = morningBriefing {
                    MorningApprovalView(briefing: briefing, isPresented: $showingMorningApproval)
                }
            }
            .alert(isPresented: $showingError) {
                Alert(title: Text("AI Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
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
    
    private var addButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 40, height: 40)
            .background(Color.pink)
            .clipShape(Circle())
            .shadow(color: isVoiceCapturing ? .pink : .pink.opacity(0.4), radius: isVoiceCapturing ? 15 : 5, x: 0, y: 3)
            .scaleEffect(isVoiceCapturing ? 1.3 : (isPressDown ? 0.9 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isVoiceCapturing)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressDown)
            .accessibilityLabel("Add New Task")
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4)
                    .onEnded { _ in
                        isVoiceCapturing = true
                        HapticAndSoundManager.shared.triggerHapticSuccess()
                        voiceManager.requestAuthorization { granted in
                            if granted { try? voiceManager.startRecording() }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressDown {
                            isPressDown = true
                            HapticAndSoundManager.shared.triggerHapticSelection()
                        }
                    }
                    .onEnded { _ in
                        isPressDown = false
                        if isVoiceCapturing {
                            isVoiceCapturing = false
                            voiceManager.stopRecording()
                            HapticAndSoundManager.shared.triggerHapticSuccess()
                            
                            if !voiceManager.transcribedText.isEmpty && voiceManager.transcribedText != "Listening..." {
                                processVoiceCapture()
                            }
                        } else {
                            HapticAndSoundManager.shared.triggerHapticSelection()
                            showingAddSheet = true
                        }
                    }
            )
            .opacity(isMenuOpen ? 0 : 1)
    }
    
    private func processVoiceCapture() {
        let text = voiceManager.transcribedText
        guard !text.isEmpty, text != "Listening..." else { return }
        
        isFetchingBriefing = true
        isParsingVoiceTask = true
        voiceTaskPlaceholderText = text
        Task {
            do {
                let parsedTasks = try await GeminiManager.shared.parseVoiceTasks(transcription: text)
                await MainActor.run {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    
                    for parsed in parsedTasks {
                        let reminder = eventKitManager.createNewReminder()
                        reminder.title = parsed.title
                        
                        if let notes = parsed.notes {
                            reminder.notes = notes
                        }
                        
                        var newTask = AppTask(reminder: reminder)
                        if let dateStr = parsed.dueDateString, let date = formatter.date(from: dateStr) {
                            newTask.dueDate = date
                        }
                        
                        if parsed.isImportant {
                            reminder.priority = 1
                        }
                        
                        try? eventKitManager.saveTask(newTask)
                    }
                    self.isFetchingBriefing = false
                    self.isParsingVoiceTask = false
                    self.voiceManager.transcribedText = ""
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.isParsingVoiceTask = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.voiceManager.transcribedText = ""
                }
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
                DispatchQueue.main.async { 
                    self.isFetchingBriefing = false 
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func fetchEveningBriefing() {
        isFetchingBriefing = true
        Task {
            do {
                let events = eventKitManager.events.filter { Calendar.current.isDateInToday($0.startDate) }
                let completed = eventKitManager.reminders.filter { $0.isCompleted && Calendar.current.isDateInToday($0.completionDate ?? Date()) }
                let pending = eventKitManager.reminders.filter { !$0.isCompleted }
                
                let briefing = try await GeminiManager.shared.generateEveningBriefing(events: events, completedReminders: completed.map { $0.reminder }, pendingReminders: pending.map { $0.reminder })
                
                await MainActor.run {
                    self.eveningBriefing = briefing
                    self.isFetchingBriefing = false
                    self.showingEveningApproval = true
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func runLabelImportance() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = eventKitManager.reminders.filter { !$0.isCompleted }
                let labels = try await GeminiManager.shared.labelImportance(reminders: pending.map { $0.reminder })
                
                await MainActor.run {
                    for label in labels {
                        if var task = pending.first(where: { $0.id == label.reminderId }) {
                            task.aiImportance = label.importance
                            try? eventKitManager.updateTask(task, commit: false)
                        }
                    }
                    try? eventKitManager.commitChanges()
                    self.isFetchingBriefing = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func runPredictDurations() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = eventKitManager.reminders.filter { !$0.isCompleted && $0.approximateDuration == nil }
                let predictions = try await GeminiManager.shared.predictDurations(reminders: pending.map { $0.reminder })
                
                await MainActor.run {
                    for pred in predictions {
                        if var task = pending.first(where: { $0.id == pred.reminderId }) {
                            task.approximateDuration = "\(pred.estimatedMinutes)m"
                            try? eventKitManager.updateTask(task, commit: false)
                        }
                    }
                    try? eventKitManager.commitChanges()
                    self.isFetchingBriefing = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func runQuickCapture(text: String) {
        guard !text.isEmpty else { return }
        quickCaptureText = ""
        isFetchingBriefing = true
        Task {
            do {
                let tasks = try await GeminiManager.shared.parseNaturalLanguage(input: text)
                await MainActor.run {
                    for task in tasks {
                        let notes = "\(task.reason)\n\n<!-- {\"duration\": \"\(task.durationMinutes)m\"} -->"
                        try? eventKitManager.addTask(title: task.title, notes: notes)
                    }
                    self.isFetchingBriefing = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func runPlanMyDay() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = eventKitManager.reminders.filter { !$0.isCompleted }
                let schedule = try await GeminiManager.shared.planMyDay(reminders: pending.map { $0.reminder })
                
                await MainActor.run {
                    let calendar = Calendar.current
                    let today = Date()
                    
                    for pred in schedule {
                        if var task = pending.first(where: { $0.id == pred.reminderId }) {
                            let timeParts = pred.scheduledTime.split(separator: ":")
                            if timeParts.count == 2,
                               let hour = Int(timeParts[0]),
                               let minute = Int(timeParts[1]) {
                                
                                if let newDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) {
                                    task.dueDate = newDate
                                    try? eventKitManager.updateTask(task, commit: false)
                                    NotificationManager.shared.scheduleTaskReminders(task: task)
                                }
                            }
                        }
                    }
                    try? eventKitManager.commitChanges()
                    self.isFetchingBriefing = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func runSmartContext() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = eventKitManager.reminders.filter { !$0.isCompleted && $0.dueDate == nil }
                guard !pending.isEmpty else {
                    await MainActor.run { self.isFetchingBriefing = false }
                    return
                }
                
                let schedule = try await GeminiManager.shared.smartContextReminders(reminders: pending.map { $0.reminder })
                
                await MainActor.run {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    
                    for pred in schedule {
                        if var task = pending.first(where: { $0.id == pred.reminderId }) {
                            if let newDate = formatter.date(from: pred.scheduledDateString) {
                                task.dueDate = newDate
                                try? eventKitManager.updateTask(task, commit: false)
                                NotificationManager.shared.scheduleTaskReminders(task: task)
                            }
                        }
                    }
                    try? eventKitManager.commitChanges()
                    self.isFetchingBriefing = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private func runAutoReschedule() {
        isFetchingBriefing = true
        Task {
            do {
                let now = Date()
                let overdue = eventKitManager.reminders.filter { !$0.isCompleted && ($0.dueDate ?? Date.distantFuture) < now }
                guard !overdue.isEmpty else {
                    await MainActor.run { self.isFetchingBriefing = false }
                    return
                }
                
                let events = eventKitManager.events.filter { Calendar.current.isDateInToday($0.startDate) }
                let schedule = try await GeminiManager.shared.autoRescheduleOverdue(overdueReminders: overdue.map { $0.reminder }, events: events)
                
                await MainActor.run {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    
                    for pred in schedule {
                        if var task = overdue.first(where: { $0.id == pred.reminderId }) {
                            if let newDate = formatter.date(from: pred.scheduledDateString) {
                                task.dueDate = newDate
                                // Batched to avoid N+1 query performance bottleneck
                                try? eventKitManager.updateTask(task, commit: false)
                                NotificationManager.shared.scheduleTaskReminders(task: task)
                            }
                        }
                    }
                    try? eventKitManager.commitChanges()
                    self.isFetchingBriefing = false
                }
            } catch {
                await MainActor.run {
                    self.isFetchingBriefing = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
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
                NotificationManager.shared.cancelTaskReminders(taskId: mutableTask.id)
            } else {
                mutableTask.completionDate = nil
                hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound()
                NotificationManager.shared.scheduleTaskReminders(task: mutableTask)
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
                NotificationManager.shared.cancelTaskReminders(taskId: task.id)
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

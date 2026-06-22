import Foundation
import EventKit
import SwiftUI
internal import Combine

class EventKitManager: ObservableObject {
    static let shared = EventKitManager()
    let store = EKEventStore()
    
    @Published var isAccessGranted = false
    @Published var reminders: [AppTask] = []
    @Published var events: [EKEvent] = []
    
    var completedReminders: [AppTask] {
        reminders.filter { $0.isCompleted }
    }
    
    @AppStorage("syncIntervalMinutes") var syncIntervalMinutes: Int = 30
    
    private var syncTimer: Timer?
    private var storeChangedObserver: Any?
    
    init() {
        // Listen for changes made in Apple Reminders or other apps
        storeChangedObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isAccessGranted else { return }
            Task { @MainActor in
                await self.loadData()
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
        if let observer = storeChangedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                let remindersGranted = try await store.requestFullAccessToReminders()
                let calendarGranted = try await store.requestFullAccessToEvents()
                let granted = remindersGranted && calendarGranted
                await MainActor.run { self.isAccessGranted = granted }
                return granted
            } else {
                let remindersGranted = try await store.requestAccess(to: .reminder)
                let calendarGranted = try await store.requestAccess(to: .event)
                let granted = remindersGranted && calendarGranted
                await MainActor.run { self.isAccessGranted = granted }
                return granted
            }
        } catch {
            print("Error requesting EventKit access: \(error)")
            return false
        }
    }
    
    @MainActor
    func loadData() async {
        guard isAccessGranted else { return }
        do {
            let fetchedTasks = try await fetchTasks()
            self.reminders = fetchedTasks
            self.events = fetchTodayCalendarEvents()
        } catch {
            print("Failed to load data: \(error)")
        }
    }
    
    /// Start the periodic sync timer. Call from the main thread.
    func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
        guard syncIntervalMinutes > 0 else { return }
        let interval = TimeInterval(syncIntervalMinutes * 60)
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.loadData()
            }
        }
    }
    
    /// Restart the timer (e.g. after the user changes the interval).
    func restartSyncTimer() {
        startSyncTimer()
    }
    
    // MARK: - Reminders
    
    func fetchTasks() async throws -> [AppTask] {
        guard isAccessGranted else { return [] }
        
        let predicate = store.predicateForReminders(in: nil)
        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else {
                    continuation.resume(returning: [])
                    return
                }
                
                var topLevelTasks: [AppTask] = []
                var childTasks: [String: [AppTask]] = [:] // parentID -> children
                
                for reminder in reminders {
                    let task = AppTask(reminder: reminder)
                    if let parentID = task.parentID {
                        childTasks[parentID, default: []].append(task)
                    } else {
                        topLevelTasks.append(task)
                    }
                }
                
                for i in 0..<topLevelTasks.count {
                    let parentID = topLevelTasks[i].id
                    if let children = childTasks[parentID] {
                        topLevelTasks[i].subtasks = children
                    }
                }
                
                continuation.resume(returning: topLevelTasks)
            }
        }
    }
    
    func saveTask(_ task: AppTask, commit: Bool = true) throws {
        try store.save(task.reminder, commit: commit)
        if let index = reminders.firstIndex(where: { $0.id == task.id }) {
            DispatchQueue.main.async { self.reminders[index] = task }
        } else {
            DispatchQueue.main.async { self.reminders.append(task) }
        }
    }
    
    func updateTask(_ task: AppTask, commit: Bool = true) throws {
        try saveTask(task, commit: commit)
    }

    func commitChanges() throws {
        try store.commit()
    }
    
    func deleteTask(_ task: AppTask) throws {
        try store.remove(task.reminder, commit: true)
        DispatchQueue.main.async {
            self.reminders.removeAll(where: { $0.id == task.id })
        }
    }
    
    func getCalendars() -> [EKCalendar] {
        return store.calendars(for: .reminder)
    }

    func createNewReminder() -> EKReminder {
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = store.defaultCalendarForNewReminders()
        return reminder
    }
    
    func addTask(title: String, notes: String? = nil, dueDate: Date? = nil, calendar: EKCalendar? = nil, commit: Bool = true) throws -> AppTask {
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar ?? store.defaultCalendarForNewReminders()
        reminder.title = title
        reminder.notes = notes
        if let dueDate = dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }
        let task = AppTask(reminder: reminder)
        try saveTask(task, commit: commit)
        return task
    }
    
    // MARK: - Subtasks
    
    func addSubtask(title: String, to parent: AppTask, commit: Bool = true) throws -> AppTask {
        let reminder = EKReminder(eventStore: store)
        // Subtasks must typically share the same calendar
        reminder.calendar = parent.reminder.calendar
        reminder.title = title
        
        var subtask = AppTask(reminder: reminder)
        subtask.setParent(parent)
        
        try store.save(reminder, commit: commit)
        return subtask
    }
    
    // MARK: - Calendar
    
    func fetchTodayCalendarEvents() -> [EKEvent] {
        guard isAccessGranted else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
        return events
    }
    
    // MARK: - Habits
    
    var computedHabits: [ComputedHabit] {
        var grouped: [String: [AppTask]] = [:]
        for reminder in reminders where reminder.isHabit {
            if let habitID = reminder.habitID {
                grouped[habitID, default: []].append(reminder)
            }
        }
        
        var results: [ComputedHabit] = []
        for (habitID, tasks) in grouped {
            let sortedTasks = tasks.sorted {
                ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast)
            }
            guard let primaryTask = sortedTasks.first else { continue }
            
            let completions = tasks.filter { $0.isCompleted }.compactMap { $0.completionDate }
            let incompleteTask = sortedTasks.first { !$0.isCompleted }
            
            let taskToUse = incompleteTask ?? primaryTask
            var alarmTime: Date? = nil
            if taskToUse.reminder.alarms?.isEmpty == false {
                alarmTime = taskToUse.dueDate
            }
            
            let habit = ComputedHabit(
                habitID: habitID,
                title: primaryTask.title,
                frequency: primaryTask.habitFrequency ?? .daily,
                activeDays: primaryTask.activeDays,
                completionDates: completions,
                incompleteTask: taskToUse,
                alarmTime: alarmTime
            )
            results.append(habit)
        }
        return results.sorted { $0.title < $1.title }
    }
    
    func addOrUpdateHabit(
        habitID: String? = nil,
        title: String,
        frequency: RepeatInterval,
        activeDays: [Int],
        alarmTime: Date? = nil,
        commit: Bool = true
    ) throws {
        let id = habitID ?? UUID().uuidString
        
        var task: AppTask
        if let existing = reminders.first(where: { $0.habitID == id && !$0.isCompleted }) {
            task = existing
        } else {
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = store.defaultCalendarForNewReminders()
            task = AppTask(reminder: reminder)
            task.dueDate = Calendar.current.startOfDay(for: Date())
        }
        
        task.title = title
        task.isHabit = true
        task.habitID = id
        task.habitFrequency = frequency
        task.activeDays = activeDays
        
        let cal = Calendar.current
        if let alarmTime = alarmTime {
            let hour = cal.component(.hour, from: alarmTime)
            let minute = cal.component(.minute, from: alarmTime)
            var currentDue = task.dueDate ?? cal.startOfDay(for: Date())
            currentDue = cal.date(bySettingHour: hour, minute: minute, second: 0, of: cal.startOfDay(for: currentDue)) ?? currentDue
            task.dueDate = currentDue
            
            task.reminder.alarms = [EKAlarm(relativeOffset: 0)]
            task.reminder.priority = Int(EKReminderPriority.high.rawValue)
        } else {
            if let currentDue = task.dueDate {
                task.dueDate = cal.startOfDay(for: currentDue)
            }
            task.reminder.alarms = nil
            task.reminder.priority = Int(EKReminderPriority.none.rawValue)
        }
        
        let recurrenceRule: EKRecurrenceRule
        switch frequency {
        case .daily:
            if activeDays.count == 7 {
                recurrenceRule = EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
            } else {
                let daysOfTheWeek = activeDays.map { EKRecurrenceDayOfWeek(EKWeekday(rawValue: $0) ?? .sunday) }
                recurrenceRule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, daysOfTheWeek: daysOfTheWeek, daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: nil)
            }
        case .weekly:
            recurrenceRule = EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .monthly:
            recurrenceRule = EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .none:
            task.reminder.recurrenceRules = nil
            try updateTask(task, commit: commit)
            return
        }
        
        task.reminder.recurrenceRules = [recurrenceRule]
        try updateTask(task, commit: commit)
    }

    func deleteHabit(habitID: String) throws {
        let tasksToDelete = reminders.filter { $0.habitID == habitID }
        for task in tasksToDelete {
            try store.remove(task.reminder, commit: false)
        }
        try store.commit()
        DispatchQueue.main.async {
            self.reminders.removeAll(where: { $0.habitID == habitID })
        }
    }
    
    func toggleHabitCompletion(habitID: String) throws {
        let habitTasks = reminders.filter { $0.habitID == habitID }
        let calendar = Calendar.current
        
        if let completedToday = habitTasks.first(where: { $0.isCompleted && calendar.isDateInToday($0.completionDate ?? Date.distantPast) }) {
            try store.remove(completedToday.reminder, commit: false)
            if var incomplete = habitTasks.first(where: { !$0.isCompleted }) {
                incomplete.dueDate = completedToday.dueDate ?? Date()
                try updateTask(incomplete, commit: true)
            } else {
                try store.commit()
            }
            DispatchQueue.main.async {
                self.reminders.removeAll(where: { $0.id == completedToday.id })
            }
        } else if var incomplete = habitTasks.first(where: { !$0.isCompleted }) {
            incomplete.isCompleted = true
            incomplete.completionDate = Date()
            try updateTask(incomplete, commit: true)
        }
    }
}

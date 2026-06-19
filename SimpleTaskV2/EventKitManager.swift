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
                if let reminders = reminders {
                    let appTasks = reminders.map { AppTask(reminder: $0) }
                    continuation.resume(returning: appTasks)
                } else {
                    continuation.resume(returning: [])
                }
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
    
    func addTask(title: String, notes: String? = nil, dueDate: Date? = nil, calendar: EKCalendar? = nil) throws {
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar ?? store.defaultCalendarForNewReminders()
        reminder.title = title
        reminder.notes = notes
        if let dueDate = dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
        }
        try saveTask(AppTask(reminder: reminder))
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
}

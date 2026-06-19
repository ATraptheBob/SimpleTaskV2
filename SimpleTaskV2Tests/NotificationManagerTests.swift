import XCTest
import UserNotifications
import EventKit
@testable import SimpleTaskV2

final class NotificationManagerTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Clear pending notifications before each test
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    override func tearDown() async throws {
        // Clear pending notifications after each test
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        try await super.tearDown()
    }

    func testScheduleMorningBriefing_WithTasksAndHabits_SchedulesNotification() async throws {
        // Arrange
        let activeTasks = 3
        let dueHabits = 2

        // Act
        NotificationManager.shared.scheduleMorningBriefing(activeTasks: activeTasks, dueHabits: dueHabits)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()

        guard let request = pendingRequests.first(where: { $0.identifier == "morning_briefing" }) else {
            XCTFail("Morning briefing notification was not scheduled")
            return
        }

        XCTAssertEqual(request.content.title, "Good Morning! ☀️")
        XCTAssertEqual(request.content.body, "You have 3 tasks and 2 habits to tackle today.")

        // Check trigger
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger is not UNCalendarNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.dateComponents.hour, 8)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(trigger.repeats)
    }

    func testScheduleMorningBriefing_WithZeroTasksAndZeroHabits_DoesNotScheduleNotification() async throws {
        // Arrange
        let activeTasks = 0
        let dueHabits = 0

        // Act
        NotificationManager.shared.scheduleMorningBriefing(activeTasks: activeTasks, dueHabits: dueHabits)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let request = pendingRequests.first(where: { $0.identifier == "morning_briefing" })

        XCTAssertNil(request, "Morning briefing should not be scheduled when there are no tasks and no habits")
    }

    func testScheduleStreakRescue_WithHabitName_SchedulesNotification() async throws {
        // Arrange
        let habitName = "Read 10 Pages"

        // Act
        NotificationManager.shared.scheduleStreakRescue(habitName: habitName)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()

        guard let request = pendingRequests.first(where: { $0.identifier == "streak_rescue" }) else {
            XCTFail("Streak rescue notification was not scheduled")
            return
        }

        XCTAssertEqual(request.content.title, "Save Your Streak! 🔥")
        XCTAssertEqual(request.content.body, "You haven't completed '\(habitName)' yet today. Don't lose your progress!")

        // Check trigger
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger is not UNCalendarNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertFalse(trigger.repeats)
    }

    func testScheduleStreakRescue_WithNilHabitName_DoesNotScheduleNotification() async throws {
        // Arrange
        let habitName: String? = nil

        // Act
        NotificationManager.shared.scheduleStreakRescue(habitName: habitName)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let request = pendingRequests.first(where: { $0.identifier == "streak_rescue" })

        XCTAssertNil(request, "Streak rescue should not be scheduled when habit name is nil")
    }

    func testScheduleEveningBriefing_SchedulesNotification() async throws {
        // Arrange
        let completedTasks = 5
        let pendingTasks = 2

        // Act
        NotificationManager.shared.scheduleEveningBriefing(completedTasks: completedTasks, pendingTasks: pendingTasks)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()

        guard let request = pendingRequests.first(where: { $0.identifier == "eveningBriefing" }) else {
            XCTFail("Evening briefing notification was not scheduled")
            return
        }

        XCTAssertEqual(request.content.title, "Evening Review")
        XCTAssertEqual(request.content.body, "You completed 5 tasks today. You have 2 tasks pending.")

        // Check trigger
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger is not UNCalendarNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.dateComponents.hour, 20)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(trigger.repeats)
    }

    func testScheduleBreakNotification_SchedulesNotification() async throws {
        // Arrange
        let durationInSeconds: TimeInterval = 300.0

        // Act
        NotificationManager.shared.scheduleBreakNotification(durationInSeconds: durationInSeconds)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()

        guard let request = pendingRequests.first(where: { $0.identifier == "breakTimer" }) else {
            XCTFail("Break notification was not scheduled")
            return
        }

        XCTAssertEqual(request.content.title, "Break Time Over")
        XCTAssertEqual(request.content.body, "Time to get back to work!")

        // Check trigger
        guard let trigger = request.trigger as? UNTimeIntervalNotificationTrigger else {
            XCTFail("Trigger is not UNTimeIntervalNotificationTrigger")
            return
        }

        XCTAssertEqual(trigger.timeInterval, durationInSeconds)
        XCTAssertFalse(trigger.repeats)
    }

    func testScheduleTaskReminders_WithDueDate_SchedulesNotification() async throws {
        // Arrange
        let eventStore = EKEventStore()
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Buy groceries"

        // Let's set a due date in the future
        let dueDate = Date().addingTimeInterval(3600) // 1 hour from now
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)

        let task = AppTask(reminder: reminder)

        // Act
        NotificationManager.shared.scheduleTaskReminders(task: task)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()

        guard let request = pendingRequests.first(where: { $0.identifier == task.id }) else {
            XCTFail("Task reminder notification was not scheduled")
            return
        }

        XCTAssertEqual(request.content.title, "Task Reminder")
        XCTAssertEqual(request.content.body, "Buy groceries")

        // Check trigger
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger is not UNCalendarNotificationTrigger")
            return
        }

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        XCTAssertEqual(trigger.dateComponents.year, triggerDate.year)
        XCTAssertEqual(trigger.dateComponents.month, triggerDate.month)
        XCTAssertEqual(trigger.dateComponents.day, triggerDate.day)
        XCTAssertEqual(trigger.dateComponents.hour, triggerDate.hour)
        XCTAssertEqual(trigger.dateComponents.minute, triggerDate.minute)
        XCTAssertFalse(trigger.repeats)
    }

    func testScheduleTaskReminders_WithoutDueDate_DoesNotScheduleNotification() async throws {
        // Arrange
        let eventStore = EKEventStore()
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "No due date task"
        let task = AppTask(reminder: reminder)

        // Act
        NotificationManager.shared.scheduleTaskReminders(task: task)

        // Allow time for center to process
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let request = pendingRequests.first(where: { $0.identifier == task.id })

        XCTAssertNil(request, "Task reminder should not be scheduled when there is no due date")
    }
}

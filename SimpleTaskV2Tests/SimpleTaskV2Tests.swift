//
//  SimpleTaskV2Tests.swift
//  SimpleTaskV2Tests
//
//  Created by Wilson Lee on 3/22/26.
//

import XCTest
@testable import SimpleTaskV2

class MockNotificationManager: NotificationScheduling {
    var scheduledMorningBriefingActiveTasks: Int?
    var scheduledMorningBriefingDueHabits: Int?
    var scheduledStreakRescueHabitName: String?
    var morningBriefingCallCount = 0
    var streakRescueCallCount = 0

    func scheduleMorningBriefing(activeTasks: Int, dueHabits: Int) {
        scheduledMorningBriefingActiveTasks = activeTasks
        scheduledMorningBriefingDueHabits = dueHabits
        morningBriefingCallCount += 1
    }

    func scheduleStreakRescue(habitName: String?) {
        scheduledStreakRescueHabitName = habitName
        streakRescueCallCount += 1
    }

    func scheduleEveningBriefing(completedTasks: Int, pendingTasks: Int) {}
    func scheduleTaskReminders(task: AppTask) {}
    func cancelTaskReminders(taskId: String) {}
}

final class SimpleTaskV2Tests: XCTestCase {

    var scheduler: SmartNotificationScheduler!
    var mockNotificationManager: MockNotificationManager!

    override func setUpWithError() throws {
        scheduler = SmartNotificationScheduler()
        mockNotificationManager = MockNotificationManager()
    }

    override func tearDownWithError() throws {
        scheduler = nil
        mockNotificationManager = nil
    }

    func testSchedule_noTasksOrHabits() throws {
        scheduler.schedule(allTasks: [], allHabits: [], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.morningBriefingCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingActiveTasks, 0)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingDueHabits, 0)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 0)
        XCTAssertNil(mockNotificationManager.scheduledStreakRescueHabitName)
    }

    func testSchedule_withActiveTasks() throws {
        let task1 = TaskItem(title: "Task 1", isCompleted: false)
        let task2 = TaskItem(title: "Task 2", isCompleted: true)
        let task3 = TaskItem(title: "Task 3", isCompleted: false)

        scheduler.schedule(allTasks: [task1, task2, task3], allHabits: [], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.morningBriefingCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingActiveTasks, 2)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingDueHabits, 0)
    }

    func testSchedule_withDueHabitsAndStreak() throws {
        let habit1 = HabitItem(title: "Habit 1")
        // Fake streak by adding a recent completion that makes the streak logic work.
        // For our test purposes, the streak logic depends on past completions.
        // It's easier to just mock or let the logic calculate it.
        // Wait, HabitItem's streak is computed from completionDates.
        // Let's set completionDates to yesterday to give it a streak of 1.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        habit1.completionDates = [yesterday]
        habit1.updateStreak() // Needs to be updated for habit1

        let habit2 = HabitItem(title: "Habit 2")
        // Give habit 2 a streak of 2
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        habit2.completionDates = [yesterday, twoDaysAgo]
        habit2.updateStreak() // Needs to be updated for habit2

        let habit3 = HabitItem(title: "Habit 3")
        // 0 streak, no completions

        // All habits are due today because they have no completion for today

        scheduler.schedule(allTasks: [], allHabits: [habit1, habit2, habit3], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.morningBriefingCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingActiveTasks, 0)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingDueHabits, 3)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledStreakRescueHabitName, "Habit 1")
    }

    func testSchedule_withDueHabitsAndZeroStreak() throws {
        let habit1 = HabitItem(title: "Habit 1")
        // 0 streak, no completions

        let habit2 = HabitItem(title: "Habit 2")
        // 0 streak, no completions

        scheduler.schedule(allTasks: [], allHabits: [habit1, habit2], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.morningBriefingCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingActiveTasks, 0)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingDueHabits, 2)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 0)
        XCTAssertNil(mockNotificationManager.scheduledStreakRescueHabitName)
    }

    func testSchedule_allTasksCompleted_allHabitsDone() throws {
        let task = TaskItem(title: "Completed Task", isCompleted: true)

        let habit = HabitItem(title: "Done Habit")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        habit.completionDates = [yesterday, Date()]
        habit.updateStreak()

        scheduler.schedule(allTasks: [task], allHabits: [habit], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.morningBriefingCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingActiveTasks, 0)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingDueHabits, 0)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 0)
    }

    func testSchedule_multipleHabitsAtRisk_schedulesOnlyFirst() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let habit1 = HabitItem(title: "Habit 1")
        habit1.completionDates = [yesterday]
        habit1.updateStreak()

        let habit2 = HabitItem(title: "Habit 2")
        habit2.completionDates = [yesterday]
        habit2.updateStreak()

        scheduler.schedule(allTasks: [], allHabits: [habit1, habit2], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledStreakRescueHabitName, "Habit 1")
    }

    func testSchedule_habitWithStreakButDone() throws {
        let habit1 = HabitItem(title: "Habit 1")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        habit1.completionDates = [yesterday, Date()]
        habit1.updateStreak()

        scheduler.schedule(allTasks: [], allHabits: [habit1], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 0)
    }
}

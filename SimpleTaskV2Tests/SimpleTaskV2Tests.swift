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

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 1)
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

        let habit2 = HabitItem(title: "Habit 2")
        // Give habit 2 a streak of 2
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        habit2.completionDates = [yesterday, twoDaysAgo]

        let habit3 = HabitItem(title: "Habit 3")
        // 0 streak, no completions

        // All habits are due today because they have no completion for today

        scheduler.schedule(allTasks: [], allHabits: [habit1, habit2, habit3], notificationManager: mockNotificationManager)

        XCTAssertEqual(mockNotificationManager.morningBriefingCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingActiveTasks, 0)
        XCTAssertEqual(mockNotificationManager.scheduledMorningBriefingDueHabits, 3)

        XCTAssertEqual(mockNotificationManager.streakRescueCallCount, 1)
        XCTAssertEqual(mockNotificationManager.scheduledStreakRescueHabitName, "Habit 2")
    }
}

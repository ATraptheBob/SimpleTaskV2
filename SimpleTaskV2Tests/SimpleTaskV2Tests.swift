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

}

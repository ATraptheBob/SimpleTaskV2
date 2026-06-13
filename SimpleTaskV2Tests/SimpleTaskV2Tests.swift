//
//  SimpleTaskV2Tests.swift
//  SimpleTaskV2Tests
//
//  Created by Wilson Lee on 3/22/26.
//

import XCTest
import UserNotifications
@testable import SimpleTaskV2

final class SimpleTaskV2Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

    func testScheduleStreakRescue_WithHabitName_SchedulesNotification() async throws {
        // Arrange
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let habitName = "Reading"

        // Act
        NotificationManager.shared.scheduleStreakRescue(habitName: habitName)

        // Wait briefly for the notification center to update its pending requests
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert
        let pendingRequests = await center.pendingNotificationRequests()
        let request = pendingRequests.first(where: { $0.identifier == "streak_rescue" })

        XCTAssertNotNil(request, "Streak rescue notification should be scheduled.")
        XCTAssertEqual(request?.content.title, "Save Your Streak! 🔥")
        XCTAssertEqual(request?.content.body, "You haven't completed 'Reading' yet today. Don't lose your progress!")

        if let trigger = request?.trigger as? UNCalendarNotificationTrigger {
            XCTAssertEqual(trigger.dateComponents.hour, 21)
            XCTAssertEqual(trigger.dateComponents.minute, 0)
            XCTAssertFalse(trigger.repeats, "Streak rescue should not repeat.")
        } else {
            XCTFail("Trigger should be a UNCalendarNotificationTrigger")
        }
    }

    func testScheduleStreakRescue_WithNilHabitName_RemovesExistingAndDoesNotScheduleNew() async throws {
        // Arrange
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        NotificationManager.shared.scheduleStreakRescue(habitName: "Reading")
        try await Task.sleep(nanoseconds: 100_000_000)
        var pendingRequests = await center.pendingNotificationRequests()
        XCTAssertTrue(pendingRequests.contains(where: { $0.identifier == "streak_rescue" }), "Initial notification should be scheduled.")

        // Act
        NotificationManager.shared.scheduleStreakRescue(habitName: nil)

        // Wait briefly
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        pendingRequests = await center.pendingNotificationRequests()
        XCTAssertFalse(pendingRequests.contains(where: { $0.identifier == "streak_rescue" }), "Streak rescue notification should be removed and not rescheduled.")
    }
}

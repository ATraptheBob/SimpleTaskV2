import XCTest
import EventKit
@testable import SimpleTaskV2

final class AppTaskTests: XCTestCase {

    var eventStore: EKEventStore!

    override func setUpWithError() throws {
        eventStore = EKEventStore()
    }

    override func tearDownWithError() throws {
        eventStore = nil
    }

    func testSetMetadata() {
        let reminder = EKReminder(eventStore: eventStore)
        var appTask = AppTask(reminder: reminder)

        // Initial state
        XCTAssertNil(appTask.approximateDuration)

        // Set metadata
        appTask.approximateDuration = "15m"

        XCTAssertEqual(appTask.approximateDuration, "15m")
        XCTAssertEqual(appTask.reminder.notes, "<!-- {\"duration\":\"15m\"} -->")

        // Add existing notes (matching the exact expected single \n string output requested in the issue)
        appTask.reminder.notes = "Here are some notes\n<!-- {\"duration\":\"15m\"} -->"
        appTask.approximateDuration = "30m"

        XCTAssertEqual(appTask.approximateDuration, "30m")
        XCTAssertEqual(appTask.reminder.notes, "Here are some notes\n<!-- {\"duration\":\"30m\"} -->")

        // Remove metadata
        appTask.approximateDuration = nil
        XCTAssertNil(appTask.approximateDuration)
        XCTAssertEqual(appTask.reminder.notes, "Here are some notes")
    }

    func testIsUrgent() {
        let reminder = EKReminder(eventStore: eventStore)
        var appTask = AppTask(reminder: reminder)

        // Test getter
        reminder.priority = 1
        XCTAssertTrue(appTask.isUrgent)

        reminder.priority = 4
        XCTAssertTrue(appTask.isUrgent)

        reminder.priority = 5
        XCTAssertFalse(appTask.isUrgent)

        reminder.priority = 0 // Priority none (0)
        XCTAssertFalse(appTask.isUrgent)

        // Test setter to true
        reminder.priority = 5
        appTask.isUrgent = true
        XCTAssertEqual(reminder.priority, 1)

        // Test setter to false (priority < 5)
        reminder.priority = 2
        appTask.isUrgent = false
        XCTAssertEqual(reminder.priority, 5)

        // Test setter to false (priority >= 5)
        reminder.priority = 7
        appTask.isUrgent = false
        XCTAssertEqual(reminder.priority, 7)
    }

    func testIsUrgentEdgeCases() {
        let reminder = EKReminder(eventStore: eventStore)
        var appTask = AppTask(reminder: reminder)

        reminder.priority = 2
        XCTAssertTrue(appTask.isUrgent)

        reminder.priority = 3
        XCTAssertTrue(appTask.isUrgent)

        reminder.priority = 9
        XCTAssertFalse(appTask.isUrgent)
    }
}

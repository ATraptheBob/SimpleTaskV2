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

    func testIsUrgent_get_whenPriorityIsHigh_returnsTrue() {
        let reminder = EKReminder(eventStore: eventStore)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 1
        XCTAssertTrue(task.isUrgent)

        task.reminder.priority = 4
        XCTAssertTrue(task.isUrgent)
    }

    func testIsUrgent_get_whenPriorityIsLowOrNone_returnsFalse() {
        let reminder = EKReminder(eventStore: eventStore)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 0
        XCTAssertFalse(task.isUrgent)

        task.reminder.priority = 5
        XCTAssertFalse(task.isUrgent)

        task.reminder.priority = 9
        XCTAssertFalse(task.isUrgent)
    }

    func testIsUrgent_setTrue_setsPriorityToOne() {
        let reminder = EKReminder(eventStore: eventStore)
        var task = AppTask(reminder: reminder)
        task.reminder.priority = 0

        task.isUrgent = true

        XCTAssertEqual(task.reminder.priority, 1)
    }

    func testIsUrgent_setFalse_whenPriorityLessThanFive_setsPriorityToFive() {
        let reminder = EKReminder(eventStore: eventStore)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 1
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 5)

        task.reminder.priority = 0
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 5)
    }

    func testIsUrgent_setFalse_whenPriorityGreaterThanOrEqualFive_leavesPriorityUnchanged() {
        let reminder = EKReminder(eventStore: eventStore)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 5
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 5)

        task.reminder.priority = 9
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 9)
    }
}

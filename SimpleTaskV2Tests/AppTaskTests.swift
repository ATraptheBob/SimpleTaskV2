import XCTest
import EventKit
@testable import SimpleTaskV2

final class AppTaskTests: XCTestCase {
    var store: EKEventStore!

    override func setUpWithError() throws {
        store = EKEventStore()
    }

    override func tearDownWithError() throws {
        store = nil
    }

    func testIsUrgent_get_whenPriorityIsHigh_returnsTrue() {
        let reminder = EKReminder(eventStore: store)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 1
        XCTAssertTrue(task.isUrgent)

        task.reminder.priority = 4
        XCTAssertTrue(task.isUrgent)
    }

    func testIsUrgent_get_whenPriorityIsLowOrNone_returnsFalse() {
        let reminder = EKReminder(eventStore: store)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 0
        XCTAssertFalse(task.isUrgent)

        task.reminder.priority = 5
        XCTAssertFalse(task.isUrgent)

        task.reminder.priority = 9
        XCTAssertFalse(task.isUrgent)
    }

    func testIsUrgent_setTrue_setsPriorityToOne() {
        let reminder = EKReminder(eventStore: store)
        var task = AppTask(reminder: reminder)
        task.reminder.priority = 0

        task.isUrgent = true

        XCTAssertEqual(task.reminder.priority, 1)
    }

    func testIsUrgent_setFalse_whenPriorityLessThanFive_setsPriorityToFive() {
        let reminder = EKReminder(eventStore: store)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 1
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 5)

        task.reminder.priority = 0
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 5)
    }

    func testIsUrgent_setFalse_whenPriorityGreaterThanOrEqualFive_leavesPriorityUnchanged() {
        let reminder = EKReminder(eventStore: store)
        var task = AppTask(reminder: reminder)

        task.reminder.priority = 5
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 5)

        task.reminder.priority = 9
        task.isUrgent = false
        XCTAssertEqual(task.reminder.priority, 9)
    }
}

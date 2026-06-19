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
}

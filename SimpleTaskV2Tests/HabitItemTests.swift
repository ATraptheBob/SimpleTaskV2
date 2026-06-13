import XCTest
@testable import SimpleTaskV2

final class HabitItemTests: XCTestCase {

    var habit: HabitItem!

    override func setUpWithError() throws {
        habit = HabitItem(title: "Test Habit")
    }

    override func tearDownWithError() throws {
        habit = nil
    }

    func testIsDone_Daily_DoneToday() {
        habit.frequency = .daily
        habit.completionDates = [Date()]
        XCTAssertTrue(habit.isDone)
    }

    func testIsDone_Daily_NotDoneToday() {
        habit.frequency = .daily
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        habit.completionDates = [yesterday]
        XCTAssertFalse(habit.isDone)
    }

    func testIsDone_Weekly_DoneThisWeek() {
        habit.frequency = .weekly
        habit.completionDates = [Date()]
        XCTAssertTrue(habit.isDone)
    }

    func testIsDone_Weekly_NotDoneThisWeek() {
        habit.frequency = .weekly
        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        habit.completionDates = [lastWeek]
        XCTAssertFalse(habit.isDone)
    }

    func testIsDone_Monthly_DoneThisMonth() {
        habit.frequency = .monthly
        habit.completionDates = [Date()]
        XCTAssertTrue(habit.isDone)
    }

    func testIsDone_Monthly_NotDoneThisMonth() {
        habit.frequency = .monthly
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        habit.completionDates = [lastMonth]
        XCTAssertFalse(habit.isDone)
    }

    func testIsDone_None() {
        habit.frequency = RepeatInterval.none
        habit.completionDates = [Date()]
        XCTAssertFalse(habit.isDone)
    }

    func testIsDone_EmptyCompletions() {
        habit.frequency = .daily
        habit.completionDates = []
        XCTAssertFalse(habit.isDone)
    }
}

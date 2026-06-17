import XCTest
import SwiftData
@testable import SimpleTaskV2

@MainActor
final class HabitItemTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: HabitItem.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testIsDone_EmptyCompletionDates() {
        let habit = HabitItem(title: "Test Habit", frequency: .daily)
        context.insert(habit)
        XCTAssertFalse(habit.isDone, "Habit should not be done if completionDates is empty")
    }

    func testIsDone_FrequencyNone() {
        let habit = HabitItem(title: "Test Habit", frequency: .none)
        habit.completionDates = [Date()]
        context.insert(habit)
        XCTAssertFalse(habit.isDone, "Habit with frequency .none should never be done")
    }

    func testIsDone_DailyFrequency() {
        let habit = HabitItem(title: "Daily Habit", frequency: .daily)
        context.insert(habit)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        habit.completionDates = [yesterday]
        XCTAssertFalse(habit.isDone, "Daily habit completed yesterday should not be done today")

        habit.completionDates = [yesterday, Date()]
        XCTAssertTrue(habit.isDone, "Daily habit completed today should be done")
    }

    func testIsDone_WeeklyFrequency() {
        let habit = HabitItem(title: "Weekly Habit", frequency: .weekly)
        context.insert(habit)

        let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!

        habit.completionDates = [lastWeek]
        XCTAssertFalse(habit.isDone, "Weekly habit completed last week should not be done this week")

        habit.completionDates = [lastWeek, Date()]
        XCTAssertTrue(habit.isDone, "Weekly habit completed this week should be done")
    }

    func testIsDone_MonthlyFrequency() {
        let habit = HabitItem(title: "Monthly Habit", frequency: .monthly)
        context.insert(habit)

        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        habit.completionDates = [lastMonth]
        XCTAssertFalse(habit.isDone, "Monthly habit completed last month should not be done this month")

        habit.completionDates = [lastMonth, Date()]
        XCTAssertTrue(habit.isDone, "Monthly habit completed this month should be done")
    }
}

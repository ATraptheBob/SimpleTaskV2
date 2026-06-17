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

    // MARK: - updateStreak() Tests

    func testUpdateStreak_EmptyCompletions() {
        let habit = HabitItem(title: "Habit")
        habit.completionDates = []
        habit.updateStreak()
        XCTAssertEqual(habit.streak, 0, "Streak should be 0 when there are no completion dates")
    }

    func testUpdateStreak_GapMoreThanOneDay() {
        let habit = HabitItem(title: "Habit")
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        habit.completionDates = [twoDaysAgo]
        habit.updateStreak()
        XCTAssertEqual(habit.streak, 0, "Streak should be 0 when latest completion is more than 1 day ago")
    }

    func testUpdateStreak_ContinuousFromToday() {
        let habit = HabitItem(title: "Habit")
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        habit.completionDates = [today, yesterday, twoDaysAgo]
        habit.updateStreak()
        XCTAssertEqual(habit.streak, 3, "Streak should count all continuous days starting from today")
    }

    func testUpdateStreak_ContinuousFromYesterday() {
        let habit = HabitItem(title: "Habit")
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        habit.completionDates = [yesterday, twoDaysAgo]
        habit.updateStreak()
        XCTAssertEqual(habit.streak, 2, "Streak should count continuous days even if the latest is yesterday")
    }

    func testUpdateStreak_WithGapInMiddle() {
        let habit = HabitItem(title: "Habit")
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!

        habit.completionDates = [today, yesterday, threeDaysAgo]
        habit.updateStreak()
        XCTAssertEqual(habit.streak, 2, "Streak should break when there is a gap greater than 1 day between completions")
    }
}

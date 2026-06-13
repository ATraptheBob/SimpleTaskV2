//
//  SimpleTaskV2Tests.swift
//  SimpleTaskV2Tests
//
//  Created by Wilson Lee on 3/22/26.
//

import XCTest
@testable import SimpleTaskV2

final class HabitItemStreakTests: XCTestCase {

    var calendar: Calendar!
    var today: Date!

    override func setUpWithError() throws {
        calendar = Calendar.current
        today = calendar.startOfDay(for: Date())
    }

    override func tearDownWithError() throws {
        calendar = nil
        today = nil
    }

    func testStreak_withNoCompletionDates_returnsZero() {
        let habit = HabitItem(title: "Read")
        XCTAssertEqual(habit.streak, 0)
    }

    func testStreak_withOnlyToday_returnsOne() {
        let habit = HabitItem(title: "Read")
        habit.completionDates = [today]
        XCTAssertEqual(habit.streak, 1)
    }

    func testStreak_withOnlyYesterday_returnsOne() {
        let habit = HabitItem(title: "Read")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        habit.completionDates = [yesterday]
        XCTAssertEqual(habit.streak, 1)
    }

    func testStreak_withTwoDaysAgo_returnsZero() {
        let habit = HabitItem(title: "Read")
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        habit.completionDates = [twoDaysAgo]
        XCTAssertEqual(habit.streak, 0)
    }

    func testStreak_withConsecutiveDaysEndingToday_returnsStreak() {
        let habit = HabitItem(title: "Read")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        habit.completionDates = [today, yesterday, twoDaysAgo]
        XCTAssertEqual(habit.streak, 3)
    }

    func testStreak_withConsecutiveDaysEndingYesterday_returnsStreak() {
        let habit = HabitItem(title: "Read")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        habit.completionDates = [yesterday, twoDaysAgo, threeDaysAgo]
        XCTAssertEqual(habit.streak, 3)
    }

    func testStreak_withGapInCompletions_returnsStreakUntilGap() {
        let habit = HabitItem(title: "Read")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today)!

        // streak should only count today, yesterday, 2 days ago = 3
        habit.completionDates = [today, yesterday, twoDaysAgo, fourDaysAgo, fiveDaysAgo]
        XCTAssertEqual(habit.streak, 3)
    }

    func testStreak_withUnsortedDates_returnsCorrectStreak() {
        let habit = HabitItem(title: "Read")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        habit.completionDates = [yesterday, today, twoDaysAgo]
        XCTAssertEqual(habit.streak, 3)
    }
}

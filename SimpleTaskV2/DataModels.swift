import Foundation
import SwiftData

enum RepeatInterval: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var dueDate: Date
    var isCompleted: Bool
    var completionDate: Date?
    var repeatInterval: RepeatInterval?
    
    // NEW: Notes and Image attachments
    var notes: String
    @Attribute(.externalStorage) var imageData: Data?
    
    @Relationship(deleteRule: .cascade) var subtasks: [SubtaskItem] = []
    
    init(title: String, dueDate: Date = .now, isCompleted: Bool = false, repeatInterval: RepeatInterval = .none, notes: String = "", imageData: Data? = nil) {
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.repeatInterval = repeatInterval
        self.notes = notes
        self.imageData = imageData
    }
}

@Model
final class SubtaskItem {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var isCompleted: Bool
    
    init(title: String, isCompleted: Bool = false) {
        self.title = title
        self.isCompleted = isCompleted
    }
}

@Model
final class HabitItem {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var frequency: RepeatInterval?
    var completionDates: [Date] = []
    
    // The mathematically perfect streak calculator
    var streak: Int {
        guard !completionDates.isEmpty else { return 0 }
        
        let cal = Calendar.current
        let now = Date()
        
        // 1. Convert all dates into "Absolute Time Blocks" (Days, Weeks, or Months since year 1)
        let periods: [Int] = completionDates.compactMap { date in
            switch frequency ?? .daily {
            case .daily: return cal.ordinality(of: .day, in: .era, for: date)
            case .weekly: return cal.ordinality(of: .weekOfYear, in: .era, for: date)
            case .monthly: return cal.ordinality(of: .month, in: .era, for: date)
            case .none: return cal.ordinality(of: .day, in: .era, for: date)
            }
        }
        
        // 2. Remove duplicate check-ins on the same day/week and sort them newest to oldest
        let uniquePeriods = Array(Set(periods)).sorted(by: >)
        
        // 3. Find out what the "Current" time block is right now
        let currentPeriod: Int
        switch frequency ?? .daily {
        case .daily: currentPeriod = cal.ordinality(of: .day, in: .era, for: now) ?? 0
        case .weekly: currentPeriod = cal.ordinality(of: .weekOfYear, in: .era, for: now) ?? 0
        case .monthly: currentPeriod = cal.ordinality(of: .month, in: .era, for: now) ?? 0
        case .none: currentPeriod = cal.ordinality(of: .day, in: .era, for: now) ?? 0
        }
        
        guard let latestCompletion = uniquePeriods.first else { return 0 }
        
        // 4. If the most recent completion is older than "Yesterday" (or last week/month), the streak is dead.
        if latestCompletion < (currentPeriod - 1) {
            return 0
        }
        
        // 5. Count backwards safely to find the consecutive streak
        var currentStreak = 0
        var expectedPeriod = latestCompletion
        
        for period in uniquePeriods {
            if period == expectedPeriod {
                currentStreak += 1
                expectedPeriod -= 1 // Move the target back by 1 block
            } else {
                break // We hit a gap!
            }
        }
        
        return currentStreak
    }
    
    init(title: String, frequency: RepeatInterval = .daily) {
        self.title = title
        self.frequency = frequency
    }
    
    var isDone: Bool {
        let cal = Calendar.current
        return completionDates.contains { date in
            switch frequency ?? .daily {
            case .daily: return cal.isDateInToday(date)
            case .weekly: return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly: return cal.isDate(date, equalTo: Date(), toGranularity: .month)
            case .none: return false
            }
        }
    }
}

@Model
final class PomodoroSession {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var durationMinutes: Int
    var subject: String // NEW: Tracks what you were studying
    
    init(durationMinutes: Int, subject: String = "General", date: Date = .now) {
        self.durationMinutes = durationMinutes
        self.subject = subject
        self.date = date
    }
}

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
    var dueDate: Date? // FIX: Now completely optional
    var isCompleted: Bool
    var completionDate: Date?
    var repeatInterval: RepeatInterval?
    
    var notes: String
    @Attribute(.externalStorage) var imageData: Data?
    
    @Relationship(deleteRule: .cascade) var subtasks: [SubtaskItem] = []
    
    var order: Int = 0 // Tracks drag-and-drop ordering
    
    init(title: String, dueDate: Date? = nil, isCompleted: Bool = false, repeatInterval: RepeatInterval = .none, notes: String = "", imageData: Data? = nil) {
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
    
    var activeDays: [Int] = []
    
    var streak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pastCompletions = completionDates.map { calendar.startOfDay(for: $0) }.sorted(by: >)
        guard let latestCompletion = pastCompletions.first else { return 0 }
        
        let daysSinceLast = calendar.dateComponents([.day], from: latestCompletion, to: today).day ?? 0
        if daysSinceLast > 1 { return 0 }
        
        var currentStreak = 0
        var expectedDate = latestCompletion
        for date in pastCompletions {
            if date == expectedDate {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else { break }
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
    var subject: String
    
    init(durationMinutes: Int, subject: String = "General", date: Date = .now) {
        self.durationMinutes = durationMinutes
        self.subject = subject
        self.date = date
    }
}

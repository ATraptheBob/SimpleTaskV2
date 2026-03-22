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
    
    var streak: Int {
        return completionDates.count
    }
    
    init(title: String, frequency: RepeatInterval = .daily) {
        self.title = title
        self.frequency = frequency
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

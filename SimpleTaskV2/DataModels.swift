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
    var repeatInterval: RepeatInterval
    
    // The new Subtask relationship. 'Cascade' means if you delete the main task, the subtasks delete too.
    @Relationship(deleteRule: .cascade) var subtasks: [SubtaskItem] = []
    
    init(title: String, dueDate: Date = .now, isCompleted: Bool = false, repeatInterval: RepeatInterval = .none) {
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.repeatInterval = repeatInterval
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
    var completionDates: [Date] = [] // V3: Stores every completion for toggling
    
    // Streak logic: counts consecutive days/weeks/months
    var streak: Int {
        return completionDates.count // Simple version for now
    }
    
    init(title: String, frequency: RepeatInterval = .daily) {
        self.title = title
        self.frequency = frequency
    }
}

// New model to feed your Statistics screen
@Model
final class PomodoroSession {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var durationMinutes: Int
    
    init(durationMinutes: Int, date: Date = .now) {
        self.durationMinutes = durationMinutes
        self.date = date
    }
}

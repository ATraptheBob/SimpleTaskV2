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
    @Attribute(.unique) var id: UUID
    var title: String
    var dueDate: Date
    var isCompleted: Bool
    var completionDate: Date? // Tracks exactly when you checked it off
    var repeatInterval: RepeatInterval
    
    init(id: UUID = UUID(), title: String, dueDate: Date = .now, isCompleted: Bool = false, repeatInterval: RepeatInterval = .none) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.repeatInterval = repeatInterval
    }
}

@Model
final class HabitItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var streak: Int
    var lastCompletedDate: Date?
    
    init(id: UUID = UUID(), title: String, streak: Int = 0) {
        self.id = id
        self.title = title
        self.streak = streak
    }
}

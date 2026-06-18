import Foundation
import SwiftData

enum RepeatInterval: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

import EventKit

struct AppTask: Identifiable {
    var id: String { reminder.calendarItemIdentifier }
    var reminder: EKReminder
    
    var title: String {
        get { reminder.title }
        set { reminder.title = newValue }
    }
    
    var dueDate: Date? {
        get {
            guard let components = reminder.dueDateComponents else { return nil }
            return Calendar.current.date(from: components)
        }
        set {
            if let date = newValue {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                if reminder.startDateComponents == nil {
                    reminder.startDateComponents = reminder.dueDateComponents
                }
            } else {
                reminder.dueDateComponents = nil
            }
        }
    }
    
    var isCompleted: Bool {
        get { reminder.isCompleted }
        set { reminder.isCompleted = newValue }
    }
    
    var completionDate: Date? {
        get { reminder.completionDate }
        set { reminder.completionDate = newValue }
    }
    
    var notes: String {
        get { reminder.notes ?? "" }
        set { reminder.notes = newValue }
    }
    
    // Parses a hidden JSON payload at the end of the notes field: <!-- {"duration": "15m"} -->
    var approximateDuration: String? {
        get {
            guard let notes = reminder.notes,
                  let range = notes.range(of: "<!-- \\{.*\\} -->", options: .regularExpression),
                  let jsonData = String(notes[range]).replacingOccurrences(of: "<!-- ", with: "").replacingOccurrences(of: " -->", with: "").data(using: .utf8) else {
                return nil
            }
            let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
            return dict?["duration"]
        }
        set {
            var currentNotes = reminder.notes ?? ""
            if let range = currentNotes.range(of: "<!-- \\{.*\\} -->", options: .regularExpression) {
                currentNotes.removeSubrange(range)
            }
            if let newValue = newValue {
                let json = "<!-- {\"duration\": \"\(newValue)\"} -->"
                currentNotes = currentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                if !currentNotes.isEmpty {
                    currentNotes += "\n\n"
                }
                currentNotes += json
            }
            reminder.notes = currentNotes
        }
    }
}

@Model
final class HabitItem {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var frequency: RepeatInterval?
    var completionDates: [Date] = []
    
    var activeDays: [Int] = []
    
    var streak: Int = 0

    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pastCompletions = completionDates.map { calendar.startOfDay(for: $0) }.sorted(by: >)
        guard let latestCompletion = pastCompletions.first else {
            streak = 0
            return
        }
        
        let daysSinceLast = calendar.dateComponents([.day], from: latestCompletion, to: today).day ?? 0
        if daysSinceLast > 1 {
            streak = 0
            return
        }
        
        var currentStreak = 0
        var expectedDate = latestCompletion
        for date in pastCompletions {
            if date == expectedDate {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate)!
            } else { break }
        }
        streak = currentStreak
    }
    
    init(title: String, frequency: RepeatInterval = .daily) {
        self.title = title
        self.frequency = frequency
    }
    
    var isDone: Bool {
        let cal = Calendar.current
        let freq = frequency ?? .daily
        if freq == .none { return false }
        guard let latestCompletion = completionDates.max() else { return false }
        switch freq {
        case .daily: return cal.isDateInToday(latestCompletion)
        case .weekly: return cal.isDate(latestCompletion, equalTo: Date(), toGranularity: .weekOfYear)
        case .monthly: return cal.isDate(latestCompletion, equalTo: Date(), toGranularity: .month)
        case .none: return false
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

// TEMPORARY SCAFFOLDING TO ALLOW UI TO COMPILE DURING TRANSITION
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var dueDate: Date?
    var isCompleted: Bool = false
    var completionDate: Date?
    var repeatInterval: RepeatInterval?
    var notes: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    @Relationship(deleteRule: .cascade) var subtasks: [SubtaskItem] = []
    var order: Int = 0
    init(title: String = "", dueDate: Date? = nil, repeatInterval: RepeatInterval? = nil, notes: String = "", imageData: Data? = nil) {
        self.title = title
        self.dueDate = dueDate
        self.repeatInterval = repeatInterval
        self.notes = notes
        self.imageData = imageData
    }
}

@Model
final class SubtaskItem {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var isCompleted: Bool = false
    init(title: String = "") {
        self.title = title
    }
}

// MARK: - AI Models

struct SuggestedTask: Codable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let durationMinutes: Int
    let reason: String
}

struct MorningBriefing: Codable {
    let aiMessage: String
    let suggestedTasks: [SuggestedTask]
    let prioritizedReminderIds: [String]
}

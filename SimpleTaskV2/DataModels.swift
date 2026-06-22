import Foundation
import SwiftData

enum RepeatInterval: String, Codable, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

import EventKit
import ActivityKit

public struct PomodoroAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var timerEndTime: Date?
        public var isBreak: Bool
        public var subject: String
        
        public init(timerEndTime: Date?, isBreak: Bool, subject: String) {
            self.timerEndTime = timerEndTime
            self.isBreak = isBreak
            self.subject = subject
        }
    }

    public var sessionDuration: Int
    
    public init(sessionDuration: Int) {
        self.sessionDuration = sessionDuration
    }
}

struct AppTask: Identifiable {
    var id: String { reminder.calendarItemIdentifier }
    var reminder: EKReminder
    
    // MARK: - Subtasks
    var subtasks: [AppTask] = []
    
    var parentID: String? {
        reminder.value(forKey: "parentID") as? String
    }
    
    mutating func setParent(_ parent: AppTask) {
        reminder.setValue(parent.id, forKey: "parentID")
    }
    
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
    
    // MARK: - Hidden JSON Metadata in Notes
    // Stores metadata as a hidden HTML comment: <!-- {"duration": "15m", "importance": "high"} -->
    
    private var metadataDict: [String: String]? {
        guard let notes = reminder.notes,
              let range = notes.range(of: "<!-- \\{.*\\} -->", options: .regularExpression),
              let jsonData = String(notes[range]).replacingOccurrences(of: "<!-- ", with: "").replacingOccurrences(of: " -->", with: "").data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
    }
    
    private mutating func setMetadata(key: String, value: String?) {
        var dict = metadataDict ?? [:]
        dict[key] = value
        
        var currentNotes = reminder.notes ?? ""
        if let range = currentNotes.range(of: "<!-- \\{.*\\} -->", options: .regularExpression) {
            currentNotes.removeSubrange(range)
        }
        currentNotes = currentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !dict.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if !currentNotes.isEmpty {
                currentNotes += "\n\n"
            }
            currentNotes += "<!-- \(jsonString) -->"
        }
        reminder.notes = currentNotes
    }
    
    var approximateDuration: String? {
        get { metadataDict?["duration"] }
        set { setMetadata(key: "duration", value: newValue) }
    }
    
    var aiImportance: String? {
        get {
            switch reminder.priority {
            case 1...4: return "high"
            case 5: return "medium"
            case 6...9: return "low"
            default: return nil
            }
        }
        set {
            switch newValue?.lowercased() {
            case "high": reminder.priority = Int(EKReminderPriority.high.rawValue)
            case "medium": reminder.priority = Int(EKReminderPriority.medium.rawValue)
            case "low": reminder.priority = Int(EKReminderPriority.low.rawValue)
            default: reminder.priority = Int(EKReminderPriority.none.rawValue)
            }
        }
    }
    
    var isUrgent: Bool {
        get { metadataDict?["urgent"] == "true" }
        set { setMetadata(key: "urgent", value: newValue ? "true" : nil) }
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

// ---------------------------------------------------------
// WIDGET QUEUE (For seamless Lock Screen interactions)
// ---------------------------------------------------------
@Model
final class QueuedTaskAction {
    @Attribute(.unique) var id: UUID = UUID()
    var taskID: String
    var actionType: String // e.g. "complete", "uncomplete"
    var timestamp: Date
    
    init(taskID: String, actionType: String) {
        self.taskID = taskID
        self.actionType = actionType
        self.timestamp = Date()
    }
}

// ---------------------------------------------------------
// ARCHIVED TASKS (For "Trash" and Restore functionality)
// ---------------------------------------------------------
@Model
final class ArchivedTask {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var originalCalendarIdentifier: String?
    var notes: String?
    var dueDate: Date?
    var deletionDate: Date
    
    init(title: String, originalCalendarIdentifier: String?, notes: String? = nil, dueDate: Date? = nil) {
        self.title = title
        self.originalCalendarIdentifier = originalCalendarIdentifier
        self.notes = notes
        self.dueDate = dueDate
        self.deletionDate = Date()
    }
}

// MARK: - AI Models

struct SuggestedTask: Codable, Identifiable {
    var id: UUID = UUID()
    let title: String
    let durationMinutes: Int
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case title, durationMinutes, reason
    }
    
    init(title: String, durationMinutes: Int, reason: String) {
        self.title = title
        self.durationMinutes = durationMinutes
        self.reason = reason
        self.id = UUID()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        self.reason = try container.decode(String.self, forKey: .reason)
        self.id = UUID()
    }
}

struct MorningBriefing: Codable {
    let aiMessage: String
    let suggestedTasks: [SuggestedTask]
    let prioritizedReminderIds: [String]
}

struct EveningBriefing: Codable {
    let summary: String
    let productivityScore: Int
    let completedCount: Int
    let tomorrowSuggestions: [SuggestedTask]
}

struct ImportanceLabel: Codable {
    let reminderId: String
    let importance: String
    let reason: String
}

struct ImportanceResponse: Codable {
    let labels: [ImportanceLabel]
}

struct DurationPrediction: Codable {
    let reminderId: String
    let estimatedMinutes: Int
}

struct DurationResponse: Codable {
    let predictions: [DurationPrediction]
}

struct QuickCaptureResponse: Codable {
    let tasks: [SuggestedTask]
}

struct DayPlanPrediction: Codable {
    let reminderId: String
    let scheduledTime: String // Expected format "HH:mm"
}

struct DayPlanResponse: Codable {
    let schedule: [DayPlanPrediction]
}

struct SmartSchedulePrediction: Codable {
    let reminderId: String
    let scheduledDateString: String // "yyyy-MM-dd HH:mm"
}

struct VoiceTaskResponse: Codable {
    struct ParsedTask: Codable {
        let title: String
        let notes: String?
        let dueDateString: String? // "yyyy-MM-dd HH:mm"
        let isImportant: Bool
    }
    let tasks: [ParsedTask]
}

struct SmartScheduleResponse: Codable {
    let schedule: [SmartSchedulePrediction]
}

struct WeeklyInsightsResponse: Codable {
    let summary: String
    let topHabits: [String]
    let struggles: [String]
    let recommendedAction: String
}

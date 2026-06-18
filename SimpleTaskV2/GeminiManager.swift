import Foundation
import EventKit
import SwiftUI
internal import Combine

class GeminiManager: ObservableObject {
    static let shared = GeminiManager()
    
    @Published var isGenerating: Bool = false
    
    @AppStorage("geminiApiKey") private var apiKey: String = ""
    
    private let models = ["gemini-3.1-flash-lite"]
    private let apiBase = "https://generativelanguage.googleapis.com/v1beta/models"
    
    private func endpointURL(for model: String) -> String {
        "\(apiBase)/\(model):generateContent"
    }
    
    enum GeminiError: LocalizedError {
        case apiError(String)
        
        var errorDescription: String? {
            switch self {
            case .apiError(let message): return message
            }
        }
    }
    
    // MARK: - Generic API Helper
    
    private func callGemini<T: Decodable>(prompt: String, responseType: T.Type) async throws -> T {
        guard !apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Try each model with retries for transient errors (503, 429)
        var lastError: Error?
        for model in models {
            let maxRetries = 3
            for attempt in 0..<maxRetries {
                let endpoint = endpointURL(for: model)
                guard let url = URL(string: endpoint) else {
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 120
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
                request.httpBody = jsonData
                
                let (data, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                if statusCode == 200 {
                    // Success — fall through to parsing below
                    let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    guard var text = geminiResponse.candidates.first?.content.parts.first?.text else {
                        throw URLError(.cannotParseResponse)
                    }
                    
                    // Strip markdown code fences if present
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.hasPrefix("```json") {
                        text = String(text.dropFirst(7))
                    } else if text.hasPrefix("```") {
                        text = String(text.dropFirst(3))
                    }
                    if text.hasSuffix("```") {
                        text = String(text.dropLast(3))
                    }
                    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    guard let jsonResultData = text.data(using: .utf8) else {
                        throw URLError(.cannotParseResponse)
                    }
                    return try JSONDecoder().decode(T.self, from: jsonResultData)
                }
                
                if statusCode == 503 || statusCode == 429 {
                    // Transient error — retry with exponential backoff
                    let delay = Double(1 << attempt) // 1s, 2s, 4s
                    print("Gemini API \(statusCode) on \(model), retrying in \(delay)s (attempt \(attempt + 1)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    lastError = GeminiError.apiError("Model \(model) returned \(statusCode) — high demand")
                    continue
                }
                
                // Non-retryable error
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
                print("Gemini API Error: \(errorMsg)")
                throw GeminiError.apiError("API Error (\(statusCode)): \(errorMsg)")
            }
            print("All retries exhausted for \(model), trying next model...")
        }
        
        throw lastError ?? GeminiError.apiError("All models unavailable. Please try again later.")
    }

    
    // MARK: - 1. Morning Briefing
    
    func generateMorningBriefing(events: [EKEvent], reminders: [EKReminder], emails: [String]) async throws -> MorningBriefing {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return MorningBriefing(
                aiMessage: "Good morning! I noticed you have some meetings today. Here are some suggested tasks to help you prepare.",
                suggestedTasks: [
                    SuggestedTask(title: "Review project brief", durationMinutes: 15, reason: "Prepare for your 10:00 AM Sync"),
                    SuggestedTask(title: "Reply to Sarah", durationMinutes: 5, reason: "Important flagged email from yesterday")
                ],
                prioritizedReminderIds: []
            )
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let prompt = """
        You are an intelligent, highly efficient productivity assistant.
        Analyze the user's daily schedule, pending tasks, and recent emails.
        Return a JSON object with:
        1. "aiMessage": A brief, motivational morning greeting (max 2 sentences).
        2. "suggestedTasks": An array of newly suggested tasks based on the events/emails, each with "title" (String), "durationMinutes" (Int), and "reason" (String).
        3. "prioritizedReminderIds": An array of the EKReminder identifiers passed to you, re-ordered by priority.
        
        User's data for today:
        EVENTS: \(events.map { "- \($0.title ?? "")" }.joined(separator: "\n"))
        REMINDERS: \(reminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "")" }.joined(separator: "\n"))
        EMAILS: \(emails.joined(separator: "\n"))
        """
        
        return try await callGemini(prompt: prompt, responseType: MorningBriefing.self)
    }
    
    // MARK: - 2. Evening Briefing
    
    func generateEveningBriefing(events: [EKEvent], completedReminders: [EKReminder], pendingReminders: [EKReminder]) async throws -> EveningBriefing {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return EveningBriefing(
                summary: "Great day! You completed most of your tasks and stayed focused during your meetings.",
                productivityScore: 8,
                completedCount: completedReminders.count,
                tomorrowSuggestions: [
                    SuggestedTask(title: "Plan tomorrow's agenda", durationMinutes: 10, reason: "Start the day organized")
                ]
            )
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let prompt = """
        You are an intelligent productivity assistant performing an evening review.
        Analyze what the user accomplished today and what's still pending.
        Return a JSON object with:
        1. "summary": A 2-3 sentence reflection on the day (encouraging tone).
        2. "productivityScore": An integer from 1 to 10 rating productivity.
        3. "completedCount": Number of tasks completed (Int).
        4. "tomorrowSuggestions": An array of suggested tasks for tomorrow, each with "title" (String), "durationMinutes" (Int), and "reason" (String).
        
        Today's data:
        EVENTS ATTENDED: \(events.map { "- \($0.title ?? "")" }.joined(separator: "\n"))
        COMPLETED TASKS: \(completedReminders.map { "- \($0.title ?? "")" }.joined(separator: "\n"))
        STILL PENDING: \(pendingReminders.map { "- \($0.title ?? "")" }.joined(separator: "\n"))
        """
        
        return try await callGemini(prompt: prompt, responseType: EveningBriefing.self)
    }
    
    // MARK: - 3. Label Importance
    
    func labelImportance(reminders: [EKReminder]) async throws -> [ImportanceLabel] {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return reminders.prefix(3).map {
                ImportanceLabel(reminderId: $0.calendarItemIdentifier, importance: "medium", reason: "Default importance")
            }
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let prompt = """
        You are a productivity assistant. Analyze these tasks and assign an importance level to each.
        Return a JSON object with a "labels" array. Each element has:
        - "reminderId": The exact ID string provided
        - "importance": One of "high", "medium", or "low"
        - "reason": A brief reason for the rating (max 10 words)
        
        TASKS:
        \(reminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "Untitled")" }.joined(separator: "\n"))
        """
        
        let response = try await callGemini(prompt: prompt, responseType: ImportanceResponse.self)
        return response.labels
    }
    
    // MARK: - 4. Predict Durations
    
    func predictDurations(reminders: [EKReminder]) async throws -> [DurationPrediction] {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return reminders.prefix(3).map {
                DurationPrediction(reminderId: $0.calendarItemIdentifier, estimatedMinutes: 15)
            }
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let prompt = """
        You are a productivity assistant. Estimate how long each task will take to complete.
        Return a JSON object with a "predictions" array. Each element has:
        - "reminderId": The exact ID string provided
        - "estimatedMinutes": An integer estimate of minutes needed
        
        TASKS:
        \(reminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "Untitled")" }.joined(separator: "\n"))
        """
        
        let response = try await callGemini(prompt: prompt, responseType: DurationResponse.self)
        return response.predictions
    }
    
    // MARK: - 5. Quick Capture (Natural Language → Tasks)
    
    func parseNaturalLanguage(input: String) async throws -> [SuggestedTask] {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return [SuggestedTask(title: input, durationMinutes: 15, reason: "Parsed from quick capture")]
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let prompt = """
        You are a productivity assistant. Parse the following natural language input into structured tasks.
        The user may describe one or multiple tasks in a single sentence.
        Return a JSON object with a "tasks" array. Each element has:
        - "title": A clean, actionable task title (String)
        - "durationMinutes": Estimated minutes needed (Int)
        - "reason": Why this was extracted from the input (String, max 10 words)
        
        USER INPUT: "\(input)"
        """
        
        let response = try await callGemini(prompt: prompt, responseType: QuickCaptureResponse.self)
        return response.tasks
    }
    
    // MARK: - 6. Plan My Day
    
    func planMyDay(reminders: [EKReminder]) async throws -> [DayPlanPrediction] {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return reminders.enumerated().map { index, reminder in
                let hour = 9 + index // Start at 9am, add an hour for each
                let validHour = min(hour, 23)
                let timeString = String(format: "%02d:00", validHour)
                return DayPlanPrediction(reminderId: reminder.calendarItemIdentifier, scheduledTime: timeString)
            }
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let prompt = """
        You are an intelligent productivity assistant. Schedule the following tasks throughout today.
        Return a JSON object with a "schedule" array. Each element has:
        - "reminderId": The exact ID string provided
        - "scheduledTime": A string in "HH:mm" 24-hour format representing the best time to start the task today.
        
        Space them out logically, starting from 09:00 (or the current time if it's later in the day, assume it's morning for this exercise).
        
        TASKS:
        \(reminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "Untitled")" }.joined(separator: "\n"))
        """
        
        let response = try await callGemini(prompt: prompt, responseType: DayPlanResponse.self)
        return response.schedule
    }
    
    // MARK: - 7. Smart Context Reminders
    
    func smartContextReminders(reminders: [EKReminder]) async throws -> [SmartSchedulePrediction] {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayStr = formatter.string(from: Date())
            return reminders.enumerated().map { index, reminder in
                let hour = 17 + (index % 4) // 5 PM onwards
                let timeString = String(format: "%02d:00", hour)
                return SmartSchedulePrediction(reminderId: reminder.calendarItemIdentifier, scheduledDateString: "\(todayStr) \(timeString)")
            }
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        let tomorrowStr = formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        
        let prompt = """
        You are an intelligent productivity assistant. Assign optimal dates and times to the following tasks based on their context (e.g., "Buy groceries" -> 17:30, "Read book" -> 20:00).
        Return a JSON object with a "schedule" array. Each element has:
        - "reminderId": The exact ID string provided
        - "scheduledDateString": A string in "yyyy-MM-dd HH:mm" format.
        
        Use today's date (\(todayStr)) or tomorrow's date (\(tomorrowStr)). Use 24-hour time.
        
        TASKS:
        \(reminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "Untitled")" }.joined(separator: "\n"))
        """
        
        let response = try await callGemini(prompt: prompt, responseType: SmartScheduleResponse.self)
        return response.schedule
    }
    
    // MARK: - 8. Auto-Reschedule Overdue
    
    func autoRescheduleOverdue(overdueReminders: [EKReminder], events: [EKEvent]) async throws -> [SmartSchedulePrediction] {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayStr = formatter.string(from: Date())
            return overdueReminders.enumerated().map { index, reminder in
                return SmartSchedulePrediction(reminderId: reminder.calendarItemIdentifier, scheduledDateString: "\(todayStr) \(String(format: "%02d:30", 12 + (index % 8)))")
            }
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        let tomorrowStr = formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        
        let prompt = """
        You are an intelligent productivity assistant. The user has overdue tasks that need to be rescheduled logically into the near future.
        Return a JSON object with a "schedule" array. Each element has:
        - "reminderId": The exact ID string provided
        - "scheduledDateString": A string in "yyyy-MM-dd HH:mm" format.
        
        Avoid scheduling them during the user's upcoming events. Spread them out reasonably between today (\(todayStr)) and tomorrow (\(tomorrowStr)). Use 24-hour time.
        
        EVENTS TODAY:
        \(events.map { "- \($0.title ?? "")" }.joined(separator: "\n"))
        
        OVERDUE TASKS:
        \(overdueReminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "Untitled")" }.joined(separator: "\n"))
        """
        
        let response = try await callGemini(prompt: prompt, responseType: SmartScheduleResponse.self)
        return response.schedule
    }
    
    func parseVoiceTasks(transcription: String) async throws -> [VoiceTaskResponse.ParsedTask] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nowString = formatter.string(from: Date())
        
        let prompt = """
        I just spoke the following text to my task manager app:
        "\(transcription)"
        
        The current date and time is \(nowString).
        Parse the text and extract the actionable tasks.
        Return a JSON object with a "tasks" array.
        Each task should have:
        - "title": A concise, imperative task string.
        - "notes": Any extra details or context from the transcription.
        - "dueDateString": A string in "yyyy-MM-dd HH:mm" format if a time/date was implied, or null.
        - "isImportant": true if words like "urgent", "important", or exclamation context is used.
        """
        
        let response = try await callGemini(prompt: prompt, responseType: VoiceTaskResponse.self)
        return response.tasks
    }
    
    // MARK: - 9. Weekly Insights
    
    func generateWeeklyInsights(habits: [HabitItem], sessions: [PomodoroSession]) async throws -> WeeklyInsightsResponse {
        if apiKey.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return WeeklyInsightsResponse(
                summary: "You had a highly productive week, focusing heavily on your core tasks. Great consistency!",
                topHabits: ["Reading", "Exercise"],
                struggles: ["Meditation"],
                recommendedAction: "Try scheduling Meditation right after waking up to build consistency."
            )
        }
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let calendar = Calendar.current
        let today = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        let recentSessions = sessions.filter { $0.date >= oneWeekAgo }
        let totalFocusMinutes = recentSessions.reduce(0) { $0 + $1.durationMinutes }
        
        var habitData = ""
        for habit in habits {
            let completionsThisWeek = habit.completionDates.filter { $0 >= oneWeekAgo }.count
            habitData += "- \(habit.title): \(completionsThisWeek) completions (Streak: \(habit.streak))\n"
        }
        
        let prompt = """
        You are an elite productivity coach. Analyze the user's data from the past week.
        
        Total Focus Time: \(totalFocusMinutes) minutes
        Habit Performance:
        \(habitData)
        
        Generate a JSON object with:
        - "summary": A brief, encouraging 2-sentence summary of their week.
        - "topHabits": Array of 1-3 habit titles they did well on.
        - "struggles": Array of 1-2 habit titles they missed most often.
        - "recommendedAction": One specific, highly actionable tip to improve next week based on their struggles or focus time.
        """
        
        return try await callGemini(prompt: prompt, responseType: WeeklyInsightsResponse.self)
    }
}

// MARK: - Gemini API Response Models
fileprivate struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

fileprivate struct GeminiCandidate: Codable {
    let content: GeminiContent
}

fileprivate struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

fileprivate struct GeminiPart: Codable {
    let text: String
}

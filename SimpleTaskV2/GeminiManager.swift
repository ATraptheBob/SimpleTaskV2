import Foundation
import EventKit
import SwiftUI
internal import Combine

class GeminiManager: ObservableObject {
    static let shared = GeminiManager()
    
    @Published var isGenerating: Bool = false
    
    @AppStorage("googleCloudProjectId") private var projectId: String = ""
    
    func generateMorningBriefing(events: [EKEvent], reminders: [EKReminder], emails: [String]) async throws -> MorningBriefing {
        if projectId.isEmpty {
            // Simulate network delay
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
        
        guard let accessToken = GoogleWorkspaceManager.shared.accessToken else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let endpoint = "https://us-central1-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/us-central1/publishers/google/models/gemini-1.5-flash-001:generateContent"
        
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        let prompt = """
        You are an intelligent, highly efficient productivity assistant with a minimalist aesthetic ("Pure Canvas").
        Your job is to analyze the user's daily schedule (Calendar), pending tasks (Reminders), and recent important emails.
        You must return a JSON object with:
        1. "aiMessage": A brief, motivational morning greeting (max 2 sentences).
        2. "suggestedTasks": An array of newly suggested tasks based on the events/emails, each with a "title", "durationMinutes", and "reason".
        3. "prioritizedReminderIds": An array of the EKReminder identifiers passed to you, re-ordered by priority.
        
        Here is the user's data for today:
        EVENTS: \(events.map { "- \($0.title ?? "")" }.joined(separator: "\n"))
        REMINDERS: \(reminders.map { "- [\($0.calendarItemIdentifier)] \($0.title ?? "")" }.joined(separator: "\n"))
        EMAILS: \(emails.joined(separator: "\n"))
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        DispatchQueue.main.async { self.isGenerating = true }
        defer { DispatchQueue.main.async { self.isGenerating = false } }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            print("Gemini API Error: \(errorMsg)")
            throw URLError(.badServerResponse)
        }
        
        // Parse Gemini's standard response format
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse)
        }
        
        guard let jsonResultData = text.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        let briefing = try JSONDecoder().decode(MorningBriefing.self, from: jsonResultData)
        return briefing
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

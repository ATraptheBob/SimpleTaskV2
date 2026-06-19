import Foundation
import EventKit
import Combine
import SwiftUI

@MainActor
class InboxViewModel: ObservableObject {
    @Published var eveningBriefing: EveningBriefing?
    @Published var isFetchingBriefing = false
    @Published var showingEveningApproval = false
    @Published var showingError = false
    @Published var errorMessage = ""

    func fetchEveningBriefing(events: [EKEvent], completed: [AppTask], pending: [AppTask]) {
        let completedReminders = completed.map { $0.reminder }
        let pendingReminders = pending.map { $0.reminder }

        Task { @MainActor in
            isFetchingBriefing = true
            showingError = false
            do {
                let briefing = try await GeminiManager.shared.generateEveningBriefing(events: events, completedReminders: completedReminders, pendingReminders: pendingReminders)
                self.eveningBriefing = briefing
                self.showingEveningApproval = true
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
}

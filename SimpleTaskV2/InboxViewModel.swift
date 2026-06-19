import Foundation
import Combine
import EventKit

@MainActor
class InboxViewModel: ObservableObject {
    @Published var isFetchingBriefing = false
    @Published var showingError = false
    @Published var errorMessage = ""

    @Published var morningBriefing: MorningBriefing? = nil
    @Published var showingMorningApproval = false

    @Published var eveningBriefing: EveningBriefing? = nil
    @Published var showingEveningApproval = false

    @Published var isParsingVoiceTask = false

    @Published var voiceTaskPlaceholderText = ""
    @Published var quickCaptureText = ""

    private let eventKitManager = EventKitManager.shared

    func processVoiceCapture(text: String, voiceManager: VoiceCaptureManager) {
        guard !text.isEmpty, text != "Listening..." else { return }

        isFetchingBriefing = true
        isParsingVoiceTask = true
        voiceTaskPlaceholderText = text
        Task {
            do {
                let parsedTasks = try await GeminiManager.shared.parseVoiceTasks(transcription: text)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"

                for parsed in parsedTasks {
                    let reminder = self.eventKitManager.createNewReminder()
                    reminder.title = parsed.title

                    if let notes = parsed.notes {
                        reminder.notes = notes
                    }

                    var newTask = AppTask(reminder: reminder)
                    if let dateStr = parsed.dueDateString, let date = formatter.date(from: dateStr) {
                        newTask.dueDate = date
                    }

                    if parsed.isImportant {
                        reminder.priority = 1
                    }

                    try? self.eventKitManager.saveTask(newTask)
                }
                self.isFetchingBriefing = false
                self.isParsingVoiceTask = false
                voiceManager.transcribedText = ""

            } catch {
                self.isFetchingBriefing = false
                self.isParsingVoiceTask = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
                voiceManager.transcribedText = ""
            }
        }
    }

    func fetchMorningBriefing() {
        isFetchingBriefing = true
        Task {
            do {
                var fetchedEmails: [String] = []
                if GoogleWorkspaceManager.shared.isSignedIn {
                    let emailJson = try await GoogleWorkspaceManager.shared.fetchRecentImportantEmails()
                    fetchedEmails = [emailJson]
                }

                let briefing = try await GeminiManager.shared.generateMorningBriefing(
                    events: self.eventKitManager.events,
                    reminders: self.eventKitManager.reminders.map { $0.reminder },
                    emails: fetchedEmails
                )

                self.morningBriefing = briefing
                self.showingMorningApproval = true
                self.isFetchingBriefing = false

            } catch {
                print("Failed to fetch briefing: \(error)")
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func fetchEveningBriefing() {
        isFetchingBriefing = true
        Task {
            do {
                let events = self.eventKitManager.events.filter { Calendar.current.isDateInToday($0.startDate) }
                let completed = self.eventKitManager.reminders.filter { $0.isCompleted && Calendar.current.isDateInToday($0.completionDate ?? Date()) }
                let pending = self.eventKitManager.reminders.filter { !$0.isCompleted }

                let briefing = try await GeminiManager.shared.generateEveningBriefing(events: events, completedReminders: completed.map { $0.reminder }, pendingReminders: pending.map { $0.reminder })

                self.eveningBriefing = briefing
                self.isFetchingBriefing = false
                self.showingEveningApproval = true
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func runLabelImportance() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = self.eventKitManager.reminders.filter { !$0.isCompleted }
                let labels = try await GeminiManager.shared.labelImportance(reminders: pending.map { $0.reminder })

                for label in labels {
                    if var task = pending.first(where: { $0.id == label.reminderId }) {
                        task.aiImportance = label.importance
                        try? self.eventKitManager.updateTask(task, commit: false)
                    }
                }
                try? self.eventKitManager.commitChanges()
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func runPredictDurations() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = self.eventKitManager.reminders.filter { !$0.isCompleted && $0.approximateDuration == nil }
                let predictions = try await GeminiManager.shared.predictDurations(reminders: pending.map { $0.reminder })

                for pred in predictions {
                    if var task = pending.first(where: { $0.id == pred.reminderId }) {
                        task.approximateDuration = "\(pred.estimatedMinutes)m"
                        try? self.eventKitManager.updateTask(task, commit: false)
                    }
                }
                try? self.eventKitManager.commitChanges()
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func runQuickCapture(text: String) {
        guard !text.isEmpty else { return }
        quickCaptureText = ""
        isFetchingBriefing = true
        Task {
            do {
                let tasks = try await GeminiManager.shared.parseNaturalLanguage(input: text)

                for task in tasks {
                    let notes = "\(task.reason)\n\n<!-- {\"duration\": \"\(task.durationMinutes)m\"} -->"
                    try? self.eventKitManager.addTask(title: task.title, notes: notes)
                }
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func runPlanMyDay() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = self.eventKitManager.reminders.filter { !$0.isCompleted }
                let schedule = try await GeminiManager.shared.planMyDay(reminders: pending.map { $0.reminder })

                let calendar = Calendar.current
                let today = Date()

                for pred in schedule {
                    if var task = pending.first(where: { $0.id == pred.reminderId }) {
                        let timeParts = pred.scheduledTime.split(separator: ":")
                        if timeParts.count == 2,
                           let hour = Int(timeParts[0]),
                           let minute = Int(timeParts[1]) {

                            if let newDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) {
                                task.dueDate = newDate
                                try? self.eventKitManager.updateTask(task, commit: false)
                                NotificationManager.shared.scheduleTaskReminders(task: task)
                            }
                        }
                    }
                }
                try? self.eventKitManager.commitChanges()
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func runSmartContext() {
        isFetchingBriefing = true
        Task {
            do {
                let pending = self.eventKitManager.reminders.filter { !$0.isCompleted && $0.dueDate == nil }
                guard !pending.isEmpty else {
                    self.isFetchingBriefing = false
                    return
                }

                let schedule = try await GeminiManager.shared.smartContextReminders(reminders: pending.map { $0.reminder })

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"

                for pred in schedule {
                    if var task = pending.first(where: { $0.id == pred.reminderId }) {
                        if let newDate = formatter.date(from: pred.scheduledDateString) {
                            task.dueDate = newDate
                            try? self.eventKitManager.updateTask(task, commit: false)
                            NotificationManager.shared.scheduleTaskReminders(task: task)
                        }
                    }
                }
                try? self.eventKitManager.commitChanges()
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }

    func runAutoReschedule() {
        isFetchingBriefing = true
        Task {
            do {
                let now = Date()
                let overdue = self.eventKitManager.reminders.filter { !$0.isCompleted && ($0.dueDate ?? Date.distantFuture) < now }
                guard !overdue.isEmpty else {
                    self.isFetchingBriefing = false
                    return
                }

                let events = self.eventKitManager.events.filter { Calendar.current.isDateInToday($0.startDate) }
                let schedule = try await GeminiManager.shared.autoRescheduleOverdue(overdueReminders: overdue.map { $0.reminder }, events: events)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"

                for pred in schedule {
                    if var task = overdue.first(where: { $0.id == pred.reminderId }) {
                        if let newDate = formatter.date(from: pred.scheduledDateString) {
                            task.dueDate = newDate
                            try? self.eventKitManager.updateTask(task, commit: false)
                            NotificationManager.shared.scheduleTaskReminders(task: task)
                        }
                    }
                }
                try? self.eventKitManager.commitChanges()
                self.isFetchingBriefing = false
            } catch {
                self.isFetchingBriefing = false
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
}

import re

# 1. Patch InboxView.swift
with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'r') as f:
    inbox = f.read()

# Fix the Binding issue
binding_old = """                                                    let binding = Binding(
                                                        get: { task },
                                                        set: { updatedTask in
                                                            if let index = eventKitManager.reminders.firstIndex(where: { $0.id == updatedTask.id }) {
                                                                eventKitManager.reminders[index] = updatedTask
                                                            }
                                                        }
                                                    )"""
binding_new = """                                                    let binding = Binding(
                                                        get: { task },
                                                        set: { updatedTask in
                                                            DispatchQueue.main.async {
                                                                if let index = eventKitManager.reminders.firstIndex(where: { $0.id == updatedTask.id }) {
                                                                    eventKitManager.reminders[index] = updatedTask
                                                                }
                                                            }
                                                        }
                                                    )"""
# Wait, actually moving it to a helper func is better.
helper_func = """    private func binding(for task: AppTask) -> Binding<AppTask> {
        Binding(
            get: { task },
            set: { updatedTask in
                if let index = eventKitManager.reminders.firstIndex(where: { $0.id == updatedTask.id }) {
                    eventKitManager.reminders[index] = updatedTask
                }
            }
        )
    }

    var body: some View {"""
inbox = inbox.replace("    var body: some View {", helper_func, 1)
inbox = inbox.replace(binding_old, "                                                    let binding = self.binding(for: task)")

# Fix UIScreen.main
inbox = inbox.replace("let screenHeight = UIScreen.main.bounds.height", "let screenHeight = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 800")

# Fix try?
inbox = inbox.replace("try? eventKitManager.addTask(title: task.title, notes: notes, commit: false)", "_ = try? eventKitManager.addTask(title: task.title, notes: notes, commit: false)")
inbox = inbox.replace("try? eventKitManager.commitChanges()", "_ = try? eventKitManager.commitChanges()")
inbox = inbox.replace("try? voiceManager.startRecording()", "_ = try? voiceManager.startRecording()")

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'w') as f:
    f.write(inbox)


# 2. Patch EveningReviewView.swift
with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/EveningReviewView.swift', 'r') as f:
    evening = f.read()
evening = evening.replace("try? eventKitManager.commitChanges()", "_ = try? eventKitManager.commitChanges()")
with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/EveningReviewView.swift', 'w') as f:
    f.write(evening)


# 3. Patch MorningApprovalView.swift
with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/MorningApprovalView.swift', 'r') as f:
    morning = f.read()
morning = morning.replace("try? eventKitManager.commitChanges()", "_ = try? eventKitManager.commitChanges()")
morning = morning.replace("UIScreen.main.bounds.height", "(UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 800")
with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/MorningApprovalView.swift', 'w') as f:
    f.write(morning)


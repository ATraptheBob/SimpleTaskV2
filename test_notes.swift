import Foundation

struct MockReminder {
    var notes: String?
}

struct AppTask {
    var reminder: MockReminder
    
    private var metadataDict: [String: String]? {
        guard let notes = reminder.notes,
              let range = notes.range(of: "<!-- \\{.*\\} -->", options: .regularExpression),
              let jsonData = String(notes[range]).replacingOccurrences(of: "<!-- ", with: "").replacingOccurrences(of: " -->", with: "").data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: String]
    }
    
    var notes: String {
        get {
            var currentNotes = reminder.notes ?? ""
            if let range = currentNotes.range(of: "<!-- \\{.*\\} -->", options: .regularExpression) {
                currentNotes.removeSubrange(range)
            }
            return currentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            let dict = self.metadataDict
            var newNotes = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let dict = dict, !dict.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: dict),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                if !newNotes.isEmpty {
                    newNotes += "\n\n"
                }
                newNotes += "<!-- \(jsonString) -->"
            }
            reminder.notes = newNotes.isEmpty && dict?.isEmpty ?? true ? nil : newNotes
        }
    }
}

var task = AppTask(reminder: MockReminder(notes: "Hello\n\n<!-- {\"subtasks\":\"[...]\"} -->"))
print("Get:", task.notes == "Hello" ? "OK" : "FAIL (\(task.notes))")
task.notes = "World"
print("Set:", task.reminder.notes == "World\n\n<!-- {\"subtasks\":\"[...]\"} -->" ? "OK" : "FAIL (\(String(describing: task.reminder.notes)))")
task.notes = ""
print("Empty set:", task.reminder.notes == "<!-- {\"subtasks\":\"[...]\"} -->" ? "OK" : "FAIL (\(String(describing: task.reminder.notes)))")

var emptyTask = AppTask(reminder: MockReminder(notes: nil))
emptyTask.notes = ""
print("Empty task empty set:", emptyTask.reminder.notes == nil ? "OK" : "FAIL (\(String(describing: emptyTask.reminder.notes)))")
emptyTask.notes = "Just notes"
print("Empty task normal set:", emptyTask.reminder.notes == "Just notes" ? "OK" : "FAIL (\(String(describing: emptyTask.reminder.notes)))")

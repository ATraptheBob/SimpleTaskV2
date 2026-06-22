import SwiftUI
import EventKit
import SwiftData

struct SubtasksSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var parentTask: AppTask
    @Binding var isPresented: Bool
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var newSubtaskTitle: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach($parentTask.subtasks) { $subtask in
                        SubtaskRowView(subtask: $subtask, isDarkMode: isDarkMode) {
                            deleteSubtask(subtask)
                        }
                        .listRowBackground(AppTheme.surface(.tertiary, isDark: isDarkMode))
                    }
                    .onDelete(perform: deleteSubtasksAtOffsets)
                    
                    // Add new subtask row
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.accent)
                            .font(.caption)
                        
                        TextField("New Subtask", text: $newSubtaskTitle)
                            .font(.subheadline)
                            .foregroundColor(isDarkMode ? .white : .black)
                            .onSubmit {
                                addSubtask()
                            }
                        
                        if !newSubtaskTitle.isEmpty {
                            Button(action: addSubtask) {
                                Text("Add")
                                    .font(.subheadline.bold())
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(AppTheme.surface(.tertiary, isDark: isDarkMode))
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.surface(.secondary, isDark: isDarkMode))
            }
            .navigationTitle("Subtasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.accent)
                }
            }
        }
    }
    
    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        do {
            let newSubtask = try EventKitManager.shared.addSubtask(title: trimmed, to: parentTask)
            withAnimation {
                parentTask.subtasks.append(newSubtask)
                newSubtaskTitle = ""
            }
            // Trigger a reload just in case
            Task { await EventKitManager.shared.loadData() }
        } catch {
            print("Failed to add subtask: \(error)")
        }
    }
    
    private func deleteSubtask(_ subtask: AppTask) {
        do {
            let archivedTask = ArchivedTask(
                title: subtask.title,
                originalCalendarIdentifier: subtask.reminder.calendar.calendarIdentifier,
                notes: subtask.notes,
                dueDate: subtask.dueDate
            )
            modelContext.insert(archivedTask)
            
            try EventKitManager.shared.deleteTask(subtask)
            withAnimation {
                parentTask.subtasks.removeAll { $0.id == subtask.id }
            }
        } catch {
            print("Failed to delete subtask: \(error)")
        }
    }
    
    private func deleteSubtasksAtOffsets(offsets: IndexSet) {
        for index in offsets {
            let subtask = parentTask.subtasks[index]
            deleteSubtask(subtask)
        }
    }
}

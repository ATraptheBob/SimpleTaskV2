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
                        SubtaskRowView(subtask: $subtask, isDarkMode: isDarkMode, onUpdate: {
                            try? EventKitManager.shared.updateTask(parentTask)
                        }) {
                            deleteSubtask(subtask.id)
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
        
        let newSubtask = AppTask.SubtaskData(title: trimmed, isCompleted: false)
        withAnimation {
            parentTask.subtasks.append(newSubtask)
            newSubtaskTitle = ""
        }
        try? EventKitManager.shared.updateTask(parentTask)
    }
    
    private func deleteSubtask(_ id: UUID) {
        withAnimation {
            parentTask.subtasks.removeAll { $0.id == id }
        }
        try? EventKitManager.shared.updateTask(parentTask)
    }
    
    private func deleteSubtasksAtOffsets(offsets: IndexSet) {
        for index in offsets {
            let subtask = parentTask.subtasks[index]
            deleteSubtask(subtask.id)
        }
    }
}

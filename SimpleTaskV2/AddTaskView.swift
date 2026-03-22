import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var repeatInterval: RepeatInterval = .none
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Task Details").foregroundColor(.gray)) {
                        TextField("Task Title", text: $title)
                            .foregroundColor(.green)
                        
                        DatePicker("Due Date", selection: $dueDate)
                            .foregroundColor(.blue)
                        
                        Picker("Repeat", selection: $repeatInterval) {
                            ForEach(RepeatInterval.allCases, id: \.self) { interval in
                                Text(interval.rawValue.capitalized).tag(interval)
                            }
                        }
                        .foregroundColor(.purple)
                    }
                    .listRowBackground(Color(white: 0.12))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // 1. Fire the haptic feedback immediately
                        HapticAndSoundManager.shared.triggerHapticSuccess()
                        
                        // 2. Insert and save
                        let task = TaskItem(title: title, dueDate: dueDate, repeatInterval: repeatInterval)
                        modelContext.insert(task)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
        }
    }
}

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @FocusState private var isTitleFocused: Bool
    
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var repeatInterval: RepeatInterval = .none
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.08) : Color(white: 0.95)).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Task Details").foregroundColor(.gray)) {
                        TextField("Task Title", text: $title)
                            .focused($isTitleFocused)
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
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Task")
            .onAppear {
                            isTitleFocused = true
                        }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticAndSoundManager.shared.triggerHapticSuccess()
                        let task = TaskItem(title: title, dueDate: dueDate, repeatInterval: repeatInterval)
                        modelContext.insert(task)
                        try? modelContext.save()
                        dismiss()
                    }
                    .foregroundColor(.pink)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

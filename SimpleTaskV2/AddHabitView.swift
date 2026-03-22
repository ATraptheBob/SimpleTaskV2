import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    
    // If this is populated, the view knows you are editing instead of creating
    var habitToEdit: HabitItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Habit Details").foregroundColor(.gray)) {
                        TextField("Habit Title", text: $title)
                            .foregroundColor(.orange)
                    }
                    .listRowBackground(Color(white: 0.12))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(habitToEdit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let existingHabit = habitToEdit {
                            existingHabit.title = title // Update existing
                        } else {
                            let newHabit = HabitItem(title: title)
                            modelContext.insert(newHabit) // Save new
                        }
                        dismiss()
                    }
                    .foregroundColor(.pink)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                // Auto-fill the text field if you are editing
                if let existingHabit = habitToEdit {
                    title = existingHabit.title
                }
            }
        }
    }
}

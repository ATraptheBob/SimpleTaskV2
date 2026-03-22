import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var frequency: RepeatInterval = .daily
    
    var habitToEdit: HabitItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.08).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Habit Details").foregroundColor(.gray)) {
                        TextField("Habit Title", text: $title)
                            .foregroundColor(.orange)
                        
                        Picker("Frequency", selection: $frequency) {
                            ForEach(RepeatInterval.allCases, id: \.self) { interval in
                                if interval != .none {
                                    Text(interval.rawValue.capitalized).tag(interval)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color(white: 0.12))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(habitToEdit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let existingHabit = habitToEdit {
                            existingHabit.title = title
                            existingHabit.frequency = frequency
                        } else {
                            // FIX 1: Removed 'streak: 0' since the model calculates it automatically now
                            let newHabit = HabitItem(title: title, frequency: frequency)
                            modelContext.insert(newHabit)
                        }
                        dismiss()
                    }
                    .foregroundColor(.pink)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let existingHabit = habitToEdit {
                    title = existingHabit.title
                    // FIX 2: Added '?? .daily' to safely unwrap the optional frequency
                    frequency = existingHabit.frequency ?? .daily
                }
            }
        }
    }
}

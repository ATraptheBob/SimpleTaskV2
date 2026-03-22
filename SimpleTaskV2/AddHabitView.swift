import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var title = ""
    @State private var frequency: RepeatInterval = .daily
    
    var habitToEdit: HabitItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.08) : Color(white: 0.95)).ignoresSafeArea()
                
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
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
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
                        HapticAndSoundManager.shared.triggerHapticSuccess()
                        if let existingHabit = habitToEdit {
                            existingHabit.title = title
                            existingHabit.frequency = frequency
                        } else {
                            let newHabit = HabitItem(title: title, frequency: frequency)
                            modelContext.insert(newHabit)
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                    .foregroundColor(.pink)
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                if let existingHabit = habitToEdit {
                    title = existingHabit.title
                    frequency = existingHabit.frequency ?? .daily
                }
            }
        }
    }
}

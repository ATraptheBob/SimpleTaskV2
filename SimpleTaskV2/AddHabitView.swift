import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var title = ""
    @State private var frequency: RepeatInterval = .daily
    @State private var activeDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    
    var habitToEdit: HabitItem?
    
    let daysOfWeek = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]
    
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
                    
                    if frequency == .daily {
                        Section(header: Text("Active Days").foregroundColor(.gray)) {
                            HStack(spacing: 8) {
                                ForEach(daysOfWeek, id: \.0) { day in
                                    Text(day.1)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(activeDays.contains(day.0) ? Color.orange : Color.gray.opacity(0.3))
                                        .foregroundColor(activeDays.contains(day.0) ? .white : (isDarkMode ? .gray : .black))
                                        .clipShape(Circle())
                                        .onTapGesture {
                                            HapticAndSoundManager.shared.triggerHapticSelection()
                                            // Ensure at least one day is always selected
                                            if activeDays.contains(day.0) {
                                                if activeDays.count > 1 { activeDays.remove(day.0) }
                                            } else {
                                                activeDays.insert(day.0)
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                    }
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
                            existingHabit.activeDays = Array(activeDays).sorted()
                        } else {
                            let newHabit = HabitItem(title: title, frequency: frequency)
                            newHabit.activeDays = Array(activeDays).sorted()
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
                    activeDays = Set(existingHabit.activeDays)
                }
            }
        }
    }
}

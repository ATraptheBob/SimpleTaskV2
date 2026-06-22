import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var title = ""
    @State private var frequency: RepeatInterval = .daily
    @State private var activeDays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var enableAlarm = false
    @State private var alarmTime = Date()
    
    var habitToEdit: ComputedHabit?
    
    let daysOfWeek = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(AppTheme.matteRed)
                
                Spacer()
                
                Text(habitToEdit == nil ? "New Habit" : "Edit Habit")
                    .font(.headline)
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Button("Save") {
                    HapticAndSoundManager.shared.triggerHapticSuccess()
                    if let existingHabit = habitToEdit {
                        try? EventKitManager.shared.addOrUpdateHabit(
                            habitID: existingHabit.habitID,
                            title: title,
                            frequency: frequency,
                            activeDays: Array(activeDays).sorted(),
                            alarmTime: enableAlarm ? alarmTime : nil
                        )
                    } else {
                        try? EventKitManager.shared.addOrUpdateHabit(
                            title: title,
                            frequency: frequency,
                            activeDays: Array(activeDays).sorted(),
                            alarmTime: enableAlarm ? alarmTime : nil
                        )
                    }
                    dismiss()
                }
                .foregroundColor(AppTheme.accent)
                .disabled(title.isEmpty)
            }
            .padding()
            
            Form {
                Section(header: Text("Habit Details").foregroundColor(isDarkMode ? .gray : .secondary)) {
                    TextField("Habit Title", text: $title)
                        .foregroundColor(AppTheme.matteAmber)
                        .onChange(of: title) { oldValue, newValue in
                            if newValue.count > 100 {
                                title = String(newValue.prefix(100))
                            }
                        }
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RepeatInterval.allCases, id: \.self) { interval in
                            if interval != .none {
                                Text(interval.rawValue.capitalized).tag(interval)
                            }
                        }
                    }
                }
                .listRowBackground(AppTheme.surface(.tertiary, isDark: isDarkMode))
                
                if frequency == .daily {
                    Section(header: Text("Active Days").foregroundColor(isDarkMode ? .gray : .secondary)) {
                        HStack(spacing: 8) {
                            ForEach(daysOfWeek, id: \.0) { day in
                                Text(day.1)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(activeDays.contains(day.0) ? AppTheme.matteAmber : AppTheme.surface(.primary, isDark: isDarkMode))
                                    .foregroundColor(activeDays.contains(day.0) ? (isDarkMode ? .black : .white) : (isDarkMode ? .gray : .black))
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
                    .listRowBackground(AppTheme.surface(.tertiary, isDark: isDarkMode))
                }
                
                Section(header: Text("Notification").foregroundColor(isDarkMode ? .gray : .secondary)) {
                    Toggle("Enable Alarm", isOn: $enableAlarm)
                        .tint(AppTheme.accent)
                    
                    if enableAlarm {
                        DatePicker("Alarm Time", selection: $alarmTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                }
                .listRowBackground(AppTheme.surface(.tertiary, isDark: isDarkMode))
            }
            .scrollContentBackground(.hidden)
        }
        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .presentationBackground(.clear)
        .onAppear {
            if let existingHabit = habitToEdit {
                title = existingHabit.title
                frequency = existingHabit.frequency
                activeDays = Set(existingHabit.activeDays)
                if let existingAlarm = existingHabit.alarmTime {
                    enableAlarm = true
                    alarmTime = existingAlarm
                }
            }
        }
    }
}

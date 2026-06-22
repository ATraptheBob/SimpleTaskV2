import SwiftUI
import EventKit

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @StateObject private var eventKitManager = EventKitManager.shared
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    @State private var title = ""
    @State private var hasDueDate = false
    @Environment(\.dismiss) var dismiss
    
    var taskToEdit: AppTask? = nil
    var initialCalendarIdentifier: String? = nil
    
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var selectedCalendarIdentifier: String = ""
    @State private var priority: Int = 0  // 0 = none, 1 = high, 5 = medium, 9 = low
    @State private var isUrgent: Bool = false
    @State private var newSubtasks: [String] = []    
    private var selectedCalendarColor: Color {
        let calendars = eventKitManager.getCalendars()
        if let cal = calendars.first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            return Color(cgColor: cal.cgColor)
        }
        return AppTheme.accent
    }
    
    private var titleSection: some View {
// Title Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("Title", systemImage: "pencil.line")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    
                    TextField("What do you need to do?", text: $title)
                        .focused($isTitleFocused)
                        .font(.title3.weight(.medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(14)
                        .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isTitleFocused ? selectedCalendarColor.opacity(0.6) : Color.clear, lineWidth: 2)
                        )
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 100 {
                                title = String(newValue.prefix(100))
                            }
                        }
                }
                .padding(.horizontal, 20)
                
                    }

    private var listPickerSection: some View {
// List Picker
                VStack(alignment: .leading, spacing: 8) {
                    Label("List", systemImage: "tray.full")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                    
                    let calendars = eventKitManager.getCalendars()
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                                let isSelected = calendar.calendarIdentifier == selectedCalendarIdentifier
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedCalendarIdentifier = calendar.calendarIdentifier
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 10, height: 10)
                                        Text(calendar.title)
                                            .font(.subheadline.weight(isSelected ? .bold : .regular))
                                            .foregroundColor(isSelected ? .white : (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7)))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        isSelected
                                            ? Color(cgColor: calendar.cgColor).opacity(0.85)
                                            : AppTheme.surface(.tertiary, isDark: isDarkMode)
                                    )
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .scrollTransition(.interactive, axis: .horizontal) { effect, phase in
                                    effect.opacity(1.0 - abs(phase.value))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                    }

    private var dueDateSection: some View {
// Due Date
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Due Date", systemImage: "calendar")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Toggle("", isOn: $hasDueDate.animation(.spring(response: 0.3, dampingFraction: 0.8)))
                            .labelsHidden()
                            .tint(selectedCalendarColor)
                    }
                    
                    if hasDueDate {
                        DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(selectedCalendarColor)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                            .cornerRadius(14)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        
                        HStack {
                            Label("Urgent Reminder (Nag me)", systemImage: "bell.badge")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(isUrgent ? AppTheme.matteRed : .gray)
                                
                            Spacer()
                            
                            Toggle("", isOn: $isUrgent)
                                .labelsHidden()
                                .tint(AppTheme.matteRed)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                
                    }

    private var prioritySection: some View {
// Priority
                VStack(alignment: .leading, spacing: 8) {
                    Label("Priority", systemImage: "flag")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            PriorityChip(label: "None", isSelected: priority == 0, color: .gray) {
                                withAnimation { priority = 0 }
                            }
                            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in effect.opacity(1.0 - abs(phase.value)) }
                            PriorityChip(label: "Low", isSelected: priority == 9, color: AppTheme.matteBlue) {
                                withAnimation { priority = 9 }
                            }
                            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in effect.opacity(1.0 - abs(phase.value)) }
                            PriorityChip(label: "Medium", isSelected: priority == 5, color: AppTheme.matteAmber) {
                                withAnimation { priority = 5 }
                            }
                            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in effect.opacity(1.0 - abs(phase.value)) }
                            PriorityChip(label: "High", isSelected: priority == 1, color: AppTheme.matteRed) {
                                withAnimation { priority = 1 }
                            }
                            .scrollTransition(.interactive, axis: .horizontal) { effect, phase in effect.opacity(1.0 - abs(phase.value)) }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                    }

    private var subtasksSection: some View {
// Subtasks
                VStack(alignment: .leading, spacing: 8) {
                    Label("Subtasks", systemImage: "list.bullet.indent")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        ForEach(newSubtasks.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                
                                TextField("Step \(index + 1)", text: $newSubtasks[index])
                                    .font(.subheadline)
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Button(action: {
                                    let idx = index
                                    withAnimation {
                                        _ = self.newSubtasks.remove(at: idx)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            withAnimation {
                                newSubtasks.append("")
                            }
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Subtask")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(selectedCalendarColor)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedCalendarColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                
                    }

    private var notesSection: some View {
// Notes
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notes", systemImage: "note.text")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.gray)
                    
                    TextField("Add any extra details...", text: $notes, axis: .vertical)
                        .focused($isNotesFocused)
                        .lineLimit(3...8)
                        .font(.body)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(14)
                        .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                        .cornerRadius(14)
                        .onChange(of: notes) { _, newValue in
                            if newValue.count > 5000 {
                                notes = String(newValue.prefix(5000))
                            }
                        }
                }
                .padding(.horizontal, 20)
            }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { closeSheet() }
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(taskToEdit == nil ? "New Reminder" : "Edit Reminder")
                    .font(.headline)
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Button(action: saveReminder) {
                    Text("Save")
                        .fontWeight(.bold)
                        .foregroundColor(title.isEmpty ? .gray : selectedCalendarColor)
                }
                .disabled(title.isEmpty)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                                        titleSection
                    listPickerSection
                    dueDateSection
                    prioritySection
                    subtasksSection
                    notesSection
                }
.padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .frame(maxHeight: 600)
        // Apply shadow to make it look floating
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .onAppear {
            if let task = taskToEdit {
                title = task.title
                
                if let existingDate = task.dueDate {
                    dueDate = existingDate
                    hasDueDate = true
                } else {
                    dueDate = Date()
                    hasDueDate = false
                }
                
                notes = task.notes
                priority = task.reminder.priority
                isUrgent = task.isUrgent
                selectedCalendarIdentifier = task.reminder.calendar.calendarIdentifier
            } else {
                isTitleFocused = true
                let calendars = eventKitManager.getCalendars()
                if let initial = initialCalendarIdentifier, calendars.contains(where: { $0.calendarIdentifier == initial }) {
                    selectedCalendarIdentifier = initial
                } else if let defaultCal = eventKitManager.store.defaultCalendarForNewReminders() {
                    selectedCalendarIdentifier = defaultCal.calendarIdentifier
                } else if let firstCal = calendars.first {
                    selectedCalendarIdentifier = firstCal.calendarIdentifier
                }
            }
        }
        .onTapGesture {
            // Dismiss keyboard if tapped outside text fields
            isTitleFocused = false
            isNotesFocused = false
        }
    }
    
    private func saveReminder() {
        HapticAndSoundManager.shared.triggerHapticSuccess()
        
        let finalDate: Date? = hasDueDate ? dueDate : nil
        let calendars = eventKitManager.getCalendars()
        let selectedCalendar = calendars.first(where: { $0.calendarIdentifier == selectedCalendarIdentifier })
        
        if var task = taskToEdit {
            task.title = title
            task.dueDate = finalDate
            task.notes = notes
            task.reminder.priority = priority
            task.isUrgent = isUrgent
            if let selectedCalendar = selectedCalendar {
                task.reminder.calendar = selectedCalendar
            }
            
            if let finalDate = finalDate {
                task.reminder.alarms = [EKAlarm(absoluteDate: finalDate)]
                if isUrgent { task.reminder.priority = Int(EKReminderPriority.high.rawValue) }
            } else {
                task.reminder.alarms = nil
            }
            
            try? eventKitManager.updateTask(task)
            NotificationManager.shared.scheduleTaskReminders(task: task)
        } else {
            let reminder = EKReminder(eventStore: eventKitManager.store)
            reminder.calendar = selectedCalendar ?? eventKitManager.store.defaultCalendarForNewReminders()
            reminder.title = title
            reminder.notes = notes.isEmpty ? nil : notes
            reminder.priority = priority
            if let finalDate = finalDate {
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: finalDate)
                reminder.dueDateComponents = components
                reminder.alarms = [EKAlarm(absoluteDate: finalDate)]
                if isUrgent { reminder.priority = Int(EKReminderPriority.high.rawValue) }
            } else {
                reminder.alarms = nil
            }
            var newTask = AppTask(reminder: reminder)
            newTask.isUrgent = isUrgent
            try? eventKitManager.saveTask(newTask)
            NotificationManager.shared.scheduleTaskReminders(task: newTask)
            
            // Save subtasks
            for subtaskTitle in newSubtasks where !subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                _ = try? eventKitManager.addSubtask(title: subtaskTitle, to: newTask)
            }
        }
        
        Task {
            await eventKitManager.loadData()
        }
        closeSheet()
    }
    
    private func closeSheet() {
        isTitleFocused = false
        isNotesFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

struct PriorityChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.12))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

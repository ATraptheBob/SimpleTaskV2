import SwiftUI
import EventKit

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @StateObject private var eventKitManager = EventKitManager.shared
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    
    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var selectedCalendarIdentifier: String = ""
    @State private var priority: Int = 0  // 0 = none, 1 = high, 5 = medium, 9 = low
    @State private var isUrgent: Bool = false
    
    var taskToEdit: AppTask?
    
    private var selectedCalendarColor: Color {
        let calendars = eventKitManager.getCalendars()
        if let cal = calendars.first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            return Color(cgColor: cal.cgColor)
        }
        return .pink
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.06) : Color(white: 0.95)).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
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
                                .background(isDarkMode ? Color(white: 0.12) : Color.white)
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
                        
                        // List Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Label("List", systemImage: "tray.full")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            
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
                                                    : (isDarkMode ? Color(white: 0.12) : Color.white)
                                            )
                                            .cornerRadius(20)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                        
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
                                    .background(isDarkMode ? Color(white: 0.12) : Color.white)
                                    .cornerRadius(14)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                
                                HStack {
                                    Label("Urgent Reminder (Nag me)", systemImage: "bell.badge")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(isUrgent ? .red : .gray)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $isUrgent)
                                        .labelsHidden()
                                        .tint(.red)
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        // Priority
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Priority", systemImage: "flag")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 10) {
                                PriorityChip(label: "None", isSelected: priority == 0, color: .gray) {
                                    withAnimation { priority = 0 }
                                }
                                PriorityChip(label: "Low", isSelected: priority == 9, color: .blue) {
                                    withAnimation { priority = 9 }
                                }
                                PriorityChip(label: "Medium", isSelected: priority == 5, color: .orange) {
                                    withAnimation { priority = 5 }
                                }
                                PriorityChip(label: "High", isSelected: priority == 1, color: .red) {
                                    withAnimation { priority = 1 }
                                }
                            }
                        }
                        
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
                                .background(isDarkMode ? Color(white: 0.12) : Color.white)
                                .cornerRadius(14)
                                .onChange(of: notes) { _, newValue in
                                    if newValue.count > 5000 {
                                        notes = String(newValue.prefix(5000))
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(taskToEdit == nil ? "New Reminder" : "Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
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
                    if let defaultCal = eventKitManager.store.defaultCalendarForNewReminders() {
                        selectedCalendarIdentifier = defaultCal.calendarIdentifier
                    } else if let firstCal = calendars.first {
                        selectedCalendarIdentifier = firstCal.calendarIdentifier
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { closeSheet() }
                        .foregroundColor(.gray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveReminder) {
                        Text("Save")
                            .fontWeight(.bold)
                            .foregroundColor(title.isEmpty ? .gray : selectedCalendarColor)
                    }
                    .disabled(title.isEmpty)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTitleFocused = false
                        isNotesFocused = false
                    }
                }
            }
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
            }
            var newTask = AppTask(reminder: reminder)
            newTask.isUrgent = isUrgent
            try? eventKitManager.saveTask(newTask)
            NotificationManager.shared.scheduleTaskReminders(task: newTask)
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
        dismiss()
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

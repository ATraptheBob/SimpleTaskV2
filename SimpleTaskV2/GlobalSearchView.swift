import SwiftUI
import EventKit
import SwiftData
import WidgetKit

struct GlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    @StateObject private var eventKitManager = EventKitManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("archiveSetting") private var archiveSetting: String = "Midnight"
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .date
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    @State private var expandedTaskId: String? = nil
    @State private var taskToReschedule: AppTask? = nil
    @State private var tempDate: Date = Date()

    var activeTasks: [AppTask] {
        let cal = Calendar.current
        let now = Date()
        
        let tasks = eventKitManager.reminders.filter { task in
            if !searchText.isEmpty && !task.title.localizedCaseInsensitiveContains(searchText) {
                return false
            }

            if archiveSetting == "Midnight" {
                return !task.isCompleted || cal.isDateInToday(task.completionDate ?? Date.distantPast)
            } else if archiveSetting == "24 Hours" {
                return !task.isCompleted || now.timeIntervalSince(task.completionDate ?? Date.distantPast) < 86400
            }

            return true
        }
        
        return tasks.sorted { t1, t2 in
            if t1.isCompleted != t2.isCompleted {
                return !t1.isCompleted
            }
            if let d1 = t1.dueDate, let d2 = t2.dueDate { return d1 < d2 }
            if t1.dueDate != nil { return true }
            if t2.dueDate != nil { return false }
            return false
        }
    }
    
    private func binding(for task: AppTask) -> Binding<AppTask> {
        Binding(
            get: { task },
            set: { updatedTask in
                if let index = eventKitManager.reminders.firstIndex(where: { $0.id == updatedTask.id }) {
                    eventKitManager.reminders[index] = updatedTask
                }
            }
        )
    }
    
    private func toggleTask(_ task: AppTask) {
        withAnimation {
            var updatedTask = task
            updatedTask.isCompleted.toggle()
            if updatedTask.isCompleted {
                updatedTask.completionDate = Date()
            } else {
                updatedTask.completionDate = nil
            }
            try? EventKitManager.shared.updateTask(updatedTask)
        }
    }
    
    private func handleTaskSwipe(option: SwipeOption, task: AppTask) {
        switch option {
        case .edit:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if expandedTaskId == task.id {
                    expandedTaskId = nil
                } else {
                    expandedTaskId = task.id
                }
            }
        case .delete:
            withAnimation {
                NotificationManager.shared.cancelTaskReminders(taskId: task.id)
                let archivedTask = ArchivedTask(
                    title: task.title,
                    originalCalendarIdentifier: task.reminder.calendar.calendarIdentifier,
                    notes: task.notes,
                    dueDate: task.dueDate
                )
                modelContext.insert(archivedTask)
                try? EventKitManager.shared.deleteTask(task)
                WidgetCenter.shared.reloadAllTimelines()
            }
        case .toggle:
            toggleTask(task)
        case .date:
            tempDate = task.dueDate ?? Date()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                taskToReschedule = task
            }
        case .restore: break
        case .none: break
        }
    }
    
    private func taskRow(for task: AppTask) -> some View {
        VStack(spacing: 0) {
            let binding = self.binding(for: task)
            
            TaskRowView(
                task: binding,
                isExpanded: expandedTaskId == task.id,
                isDarkMode: isDarkMode,
                toggleTask: { toggleTask(task) },
                onToggleExpand: {
                    if expandedTaskId == task.id {
                        expandedTaskId = nil
                    } else {
                        expandedTaskId = task.id
                    }
                },
                onOpenCalendar: {
                    tempDate = task.dueDate ?? Date()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        taskToReschedule = task
                    }
                }
            )
            .customSwipeActions(
                left: leftSwipeAction,
                right: rightSwipeAction,
                onLeft: { handleTaskSwipe(option: leftSwipeAction, task: task) },
                onRight: { handleTaskSwipe(option: rightSwipeAction, task: task) }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            
            Divider()
                .padding(.horizontal, 16)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    closeSearch()
                }
                
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 20)
                    
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search tasks...", text: $searchText)
                            .focused($isSearchFocused)
                            .foregroundColor(isDarkMode ? .white : .black)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFocused = true
                                }
                            }
                            
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        
                        Button("Cancel") {
                            closeSearch()
                        }
                        .foregroundColor(AppTheme.accent)
                        .padding(.leading, 8)
                    }
                    .padding(14)
                    .background(AppTheme.surface(.primary, isDark: isDarkMode))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                    .neutralShadow(radius: 10, y: 5, opacity: 0.1)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 80)
                
                if !searchText.isEmpty {
                    List {
                        let matchingTasks = activeTasks
                        if matchingTasks.isEmpty {
                            Text("No tasks found")
                                .foregroundColor(.gray)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.top, 20)
                        } else {
                            ForEach(matchingTasks) { task in
                                taskRow(for: task)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                Spacer()
            }
            
            if taskToReschedule != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            if var t = taskToReschedule {
                                t.dueDate = tempDate
                                try? eventKitManager.updateTask(t)
                                NotificationManager.shared.scheduleTaskReminders(task: t)
                                taskToReschedule = nil
                            }
                        }
                    }
                    .zIndex(5)
                
                VStack(spacing: 20) {
                    Text("Due Date")
                        .font(.title2.bold())
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    DatePicker("", selection: $tempDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppTheme.matteSlate)
                        .labelsHidden()
                    
                    HStack(spacing: 15) {
                        Button(action: {
                            if var t = taskToReschedule {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    t.dueDate = nil
                                    try? eventKitManager.updateTask(t)
                                    NotificationManager.shared.cancelTaskReminders(taskId: t.id)
                                    taskToReschedule = nil
                                }
                            }
                        }) {
                            Text("Clear Date")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            if var t = taskToReschedule {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                    t.dueDate = tempDate
                                    try? eventKitManager.updateTask(t)
                                    NotificationManager.shared.scheduleTaskReminders(task: t)
                                    taskToReschedule = nil
                                }
                            }
                        }) {
                            Text("Reschedule")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.matteSlate)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
                .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
                .neutralShadow(radius: 8, y: 4, opacity: 0.15)
                .padding(.horizontal, 30)
                .zIndex(6)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private func closeSearch() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresented = false
            searchText = ""
            isSearchFocused = false
        }
    }
}

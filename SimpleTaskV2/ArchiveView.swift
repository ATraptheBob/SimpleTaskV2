import SwiftUI
import SwiftData
import EventKit

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var eventKitManager = EventKitManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @AppStorage("archiveSetting") private var archiveSetting: String = "Midnight"
    
    @Query(sort: \ArchivedTask.deletionDate, order: .reverse) private var deletedTasks: [ArchivedTask]
    
    var completedTasks: [AppTask] {
        eventKitManager.completedReminders.filter { task in
            guard let completionDate = task.completionDate else { return false }
            if archiveSetting == "24 Hours" {
                return Date().timeIntervalSince(completionDate) >= 86400
            } else if archiveSetting == "Midnight" {
                return !Calendar.current.isDateInToday(completionDate)
            } else { // Immediately
                return true
            }
        }.sorted(by: { ($0.completionDate ?? Date.distantPast) > ($1.completionDate ?? Date.distantPast) })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                if deletedTasks.isEmpty && completedTasks.isEmpty {
                    Text("No archived tasks yet.")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if !deletedTasks.isEmpty {
                                Text("Deleted Tasks").font(.subheadline).bold().foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                                
                                ForEach(deletedTasks) { archivedTask in
                                    deletedTaskRow(archivedTask)
                                        .padding(.horizontal, 16)
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                            
                            if !completedTasks.isEmpty {
                                Text("Completed Tasks").font(.subheadline).bold().foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)
                                
                                ForEach(completedTasks) { task in
                                    completedTaskRow(task)
                                        .padding(.horizontal, 16)
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Archive")
            .toolbar(.hidden, for: .tabBar)
        }
    }
    
    @ViewBuilder
    private func deletedTaskRow(_ archivedTask: ArchivedTask) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(archivedTask.title)
                    .strikethrough(true, color: .red.opacity(0.6))
                    .foregroundColor(isDarkMode ? .gray : .black.opacity(0.8))
                Text("Deleted: \(archivedTask.deletionDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .customSwipeActions(
            left: SwipeOption.restore,
            right: SwipeOption.delete,
            onLeft: {
                restoreTask(archivedTask)
            },
            onRight: {
                deletePermanently(archivedTask)
            }
        )
    }
    
    @ViewBuilder
    private func completedTaskRow(_ task: AppTask) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .foregroundColor(isDarkMode ? .gray : .black.opacity(0.8))
                Text("Completed: \(task.completionDate?.formatted(date: .abbreviated, time: .shortened) ?? "")")
                    .font(.caption2)
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
        .customSwipeActions(
            left: .restore,
            right: .none,
            onLeft: {
                undoCompletedTask(task)
            },
            onRight: {}
        )
    }
    
    private func restoreTask(_ archivedTask: ArchivedTask) {
        do {
            let calendars = eventKitManager.getCalendars()
            let calendar = calendars.first(where: { $0.calendarIdentifier == archivedTask.originalCalendarIdentifier }) ?? calendars.first
            guard let calendar = calendar else { return }
            
            let newEKReminder = EKReminder(eventStore: eventKitManager.store)
            newEKReminder.calendar = calendar
            newEKReminder.title = archivedTask.title
            newEKReminder.notes = archivedTask.notes
            if let dueDate = archivedTask.dueDate {
                newEKReminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
                newEKReminder.startDateComponents = newEKReminder.dueDateComponents
            }
            
            try eventKitManager.store.save(newEKReminder, commit: true)
            
            withAnimation {
                modelContext.delete(archivedTask)
                try? modelContext.save()
            }
            Task { await eventKitManager.loadData() }
            HapticAndSoundManager.shared.triggerHapticSuccess()
        } catch {
            print("Failed to restore task: \(error)")
        }
    }
    
    private func deletePermanently(_ archivedTask: ArchivedTask) {
        withAnimation {
            modelContext.delete(archivedTask)
            try? modelContext.save()
        }
        HapticAndSoundManager.shared.triggerHapticSelection()
    }
    
    private func undoCompletedTask(_ task: AppTask) {
        var mutableTask = task
        mutableTask.isCompleted = false
        mutableTask.completionDate = nil
        do {
            try eventKitManager.updateTask(mutableTask)
            HapticAndSoundManager.shared.triggerHapticSuccess()
            Task { await eventKitManager.loadData() }
        } catch {
            print("Failed to undo task: \(error)")
        }
    }
}

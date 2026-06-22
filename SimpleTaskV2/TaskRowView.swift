import SwiftUI
import SwiftData
import PhotosUI

struct TaskRowView: View {
    @Binding var task: AppTask
    var isExpanded: Bool
    var isDarkMode: Bool
    var toggleTask: () -> Void
    var onToggleExpand: () -> Void
    var onOpenCalendar: () -> Void

    @State private var isEditingNotes = false
    @State private var showingSubtasks = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // HEADER ROW (Always visible)
            HStack(alignment: .top) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? AppTheme.accent : .gray)
                    .font(.title2)
                    .contentShape(Circle())
                    .onTapGesture { toggleTask() }

                VStack(alignment: .leading, spacing: 4) {
                    if isExpanded {
                        TextField("Task Title", text: $task.title)
                            .font(.body)
                            .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(task.isCompleted)
                    } else {
                        Text(task.title)
                            .font(.body)
                            .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(task.isCompleted)
                    }

                    if !task.isCompleted, let date = task.dueDate {
                        let isOverdue = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
                        Text(date.formatted(.dateTime.month().day()))
                            .font(.caption2)
                            .foregroundColor(isOverdue ? .red.opacity(0.7) : (isDarkMode ? .gray.opacity(0.8) : .gray))
                    }
                }
                Spacer()
                
                // AI Duration Badge
                if let duration = task.approximateDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(duration.hasSuffix("m") ? duration : "\(duration)m")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(isDarkMode ? .gray : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                    .clipShape(Capsule())
                }
                
                // AI Importance Dot
                if let importance = task.aiImportance {
                    Circle()
                        .fill(importanceColor(for: importance))
                        .frame(width: 8, height: 8)
                        .padding(.leading, 2)
                }
            }
            .contentShape(Rectangle()) // Confines the expand tap to the header ONLY
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if isExpanded {
                        isEditingNotes = false // Reset notes to view mode
                        try? EventKitManager.shared.updateTask(task)
                        onToggleExpand()
                    } else {
                        onToggleExpand()
                    }
                }
            }

            // EXPANDED DETAILS
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {

                    // 2. NOTES (Always Visible, with Edit Button)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes").font(.caption.bold()).foregroundColor(.gray)
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isEditingNotes.toggle()
                                    if !isEditingNotes { try? EventKitManager.shared.updateTask(task) }
                                }
                            }) {
                                Text(isEditingNotes ? "Done" : (task.notes.isEmpty ? "Add" : "Edit"))
                                    .font(.caption.bold())
                                    .foregroundColor(isEditingNotes ? .green : .gray)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if isEditingNotes {
                            TextField("Add markdown notes or links...", text: $task.notes, axis: .vertical)
                                .font(.callout)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(12)
                                .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                                .cornerRadius(12)
                        } else {
                            if task.notes.isEmpty {
                                Text("No notes provided.")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)
                                    .onTapGesture { withAnimation { isEditingNotes = true } }
                            } else {
                                Group {
                                    if let attrStr = try? AttributedString(markdown: task.notes) {
                                        Text(attrStr)
                                    } else {
                                        Text(task.notes)
                                    }
                                }
                                .font(.callout)
                                .tint(.blue)
                                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                                .cornerRadius(12)
                            }
                        }
                    }

                    // 4. MICROBUTTONS ROW (Isolated Buttons)
                    HStack(spacing: 16) {
                        Spacer()

                        Button(action: {
                            showingSubtasks = true
                        }) {
                            Image(systemName: "list.bullet.indent")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.matteSlate)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                                .clipShape(Circle())
                                .accessibilityLabel("Subtasks")
                                .overlay(
                                    Group {
                                        if !task.subtasks.isEmpty {
                                            Text("\(task.subtasks.count)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(4)
                                                .background(AppTheme.accent)
                                                .clipShape(Circle())
                                                .offset(x: 10, y: -10)
                                        }
                                    },
                                    alignment: .topTrailing
                                )
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingSubtasks) {
                            SubtasksSheet(parentTask: $task, isPresented: $showingSubtasks)
                                .presentationDetents([.medium, .large])
                        }

                        Button(action: onOpenCalendar) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(AppTheme.matteSlate)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                                .clipShape(Circle())
                                .accessibilityLabel("Reschedule Task")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isExpanded ? AppTheme.surface(.secondary, isDark: isDarkMode) : Color.clear)
        .cornerRadius(isExpanded ? 16 : 0)
    }
    
    // MARK: - Helpers
    
    private func importanceColor(for level: String) -> Color {
        switch level.lowercased() {
        case "high": return AppTheme.matteRed
        case "medium": return AppTheme.matteAmber
        case "low": return .gray
        default: return .clear
        }
    }
}

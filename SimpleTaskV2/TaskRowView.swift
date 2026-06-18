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

    // FIX: Using an Edit Mode toggle specifically for Notes
    @State private var isEditingNotes = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // HEADER ROW (Always visible)
            HStack(alignment: .top) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .pink : .gray)
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
                                    .background(isDarkMode ? Color(white: 0.25) : Color(white: 0.85))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain) // FIX: Isolates tap target
                        }

                        if isEditingNotes {
                            TextField("Add markdown notes or links...", text: $task.notes, axis: .vertical)
                                .font(.callout)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(12)
                                .background(isDarkMode ? Color.black.opacity(0.4) : Color.white.opacity(0.8))
                                .cornerRadius(12)
                        } else {
                            if task.notes.isEmpty {
                                Text("No notes provided.")
                                    .font(.callout)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)
                                    .onTapGesture { withAnimation { isEditingNotes = true } }
                            } else {
                                // FIX: .init() allows standard URLs to be natively formatted as clickable links!
                                Text(.init(task.notes))
                                    .font(.callout)
                                    .tint(.blue)
                                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(isDarkMode ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                                    .cornerRadius(12)
                            }
                        }
                    }

                    // 4. MICROBUTTONS ROW (Isolated Buttons)
                    HStack(spacing: 16) {
                        Spacer()

                        Button(action: onOpenCalendar) {
                            Image(systemName: "calendar")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.purple)
                                .frame(width: 32, height: 32)
                                .background(isDarkMode ? Color(white: 0.25) : Color(white: 0.85))
                                .clipShape(Circle())
                                .accessibilityLabel("Reschedule Task")
                        }
                        .buttonStyle(.plain) // FIX: Prevents mass-activation
                    }
                    .padding(.top, 4)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isExpanded ? (isDarkMode ? Color(white: 0.15) : Color(white: 0.95)) : Color.clear)
        .cornerRadius(isExpanded ? 16 : 0)
    }
}

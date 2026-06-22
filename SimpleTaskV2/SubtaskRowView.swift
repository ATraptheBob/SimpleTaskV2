import SwiftUI

struct SubtaskRowView: View {
    @Binding var subtask: AppTask
    var isDarkMode: Bool
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(subtask.isCompleted ? AppTheme.accent : .gray)
                .font(.caption)
                .onTapGesture {
                    withAnimation { 
                        subtask.isCompleted.toggle() 
                        try? EventKitManager.shared.updateTask(subtask)
                    }
                }

            TextField("Step", text: $subtask.title, onEditingChanged: { isEditing in
                if !isEditing {
                    try? EventKitManager.shared.updateTask(subtask)
                }
            })
            .font(.subheadline)
            .strikethrough(subtask.isCompleted)
            .foregroundColor(subtask.isCompleted ? .gray : (isDarkMode ? .gray : .black.opacity(0.7)))
            .onSubmit {
                try? EventKitManager.shared.updateTask(subtask)
            }

            Spacer()

            if subtask.title.isEmpty || subtask.isCompleted {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .onTapGesture { onDelete() }
                    .accessibilityLabel("Delete subtask")
            }
        }
        .padding(.vertical, 4)
    }
}

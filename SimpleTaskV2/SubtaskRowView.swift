import SwiftUI

struct SubtaskRowView: View {
    @Binding var subtask: AppTask.SubtaskData
    var isDarkMode: Bool
    var onUpdate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(subtask.isCompleted ? AppTheme.accent : .gray)
                .font(.caption)
                .onTapGesture {
                    withAnimation { 
                        subtask.isCompleted.toggle() 
                        onUpdate()
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(subtask.isCompleted ? "Mark incomplete" : "Mark complete")

            TextField("Step", text: $subtask.title, onEditingChanged: { isEditing in
                if !isEditing {
                    onUpdate()
                }
            })
            .font(.subheadline)
            .strikethrough(subtask.isCompleted)
            .foregroundColor(subtask.isCompleted ? .gray : (isDarkMode ? .gray : .black.opacity(0.7)))
            .onSubmit {
                onUpdate()
            }

            Spacer()

            if subtask.title.isEmpty || subtask.isCompleted {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .onTapGesture { onDelete() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Delete subtask")
            }
        }
        .padding(.vertical, 4)
    }
}

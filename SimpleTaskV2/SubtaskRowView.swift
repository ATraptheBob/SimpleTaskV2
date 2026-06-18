import SwiftUI

struct SubtaskRowView: View {
    @Bindable var subtask: SubtaskItem
    var isDarkMode: Bool
    var onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(subtask.isCompleted ? .pink : .gray)
                .font(.caption)
                .onTapGesture {
                    withAnimation { subtask.isCompleted.toggle() }
                }

            TextField("Step", text: $subtask.title)
                .font(.subheadline)
                .strikethrough(subtask.isCompleted)
                .foregroundColor(subtask.isCompleted ? .gray : (isDarkMode ? .gray : .black.opacity(0.7)))

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

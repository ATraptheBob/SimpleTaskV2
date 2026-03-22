import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Query(sort: \TaskItem.completionDate, order: .reverse) private var allTasks: [TaskItem]
    
    // Shows only tasks completed MORE than 24 hours ago
    var archivedTasks: [TaskItem] {
        allTasks.filter { task in
            task.isCompleted && (task.completionDate != nil && Date().timeIntervalSince(task.completionDate!) >= 86400)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                if archivedTasks.isEmpty {
                    Text("No archived tasks yet.")
                        .foregroundColor(.gray)
                } else {
                    List(archivedTasks) { task in
                        VStack(alignment: .leading) {
                            Text(task.title).foregroundColor(.gray)
                            Text("Completed: \(task.completionDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Archive")
        }
    }
}

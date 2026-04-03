import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Query(sort: \TaskItem.completionDate, order: .reverse) private var allTasks: [TaskItem]
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var archivedTasks: [TaskItem] {
        allTasks.filter { task in
            task.isCompleted && (task.completionDate != nil && Date().timeIntervalSince(task.completionDate!) >= 86400)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                if archivedTasks.isEmpty {
                    Text("No archived tasks yet.")
                        .foregroundColor(.gray)
                } else {
                    List(archivedTasks) { task in
                        VStack(alignment: .leading) {
                            Text(task.title).foregroundColor(isDarkMode ? .gray : .black.opacity(0.8))
                            Text("Completed: \(task.completionDate?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(.caption2)
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Archive")
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

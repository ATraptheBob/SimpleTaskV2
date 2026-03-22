import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var habits: [HabitItem]
    
    var totalCompletedTasks: Int {
        allTasks.filter { $0.isCompleted }.count
    }
    
    var bestStreak: Int {
        habits.map { $0.streak }.max() ?? 0
    }

    // --- Heatmap Logic ---
    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    
    // Generates an array of the last 35 dates
    var pastDays: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<35).reversed().compactMap {
            Calendar.current.date(byAdding: .day, value: -$0, to: today)
        }
    }
    
    // Groups completed tasks by their specific date
    var completionMap: [Date: Int] {
        var map: [Date: Int] = [:]
        for task in allTasks where task.isCompleted {
            if let compDate = task.completionDate {
                let startOfDay = Calendar.current.startOfDay(for: compDate)
                map[startOfDay, default: 0] += 1
            }
        }
        return map
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Top Stats
                        VStack(spacing: 16) {
                            StatBox(title: "Tasks Conquered", value: "\(totalCompletedTasks)", color: .pink)
                            StatBox(title: "Best Habit Streak", value: "\(bestStreak) 🔥", color: .orange)
                            StatBox(title: "Active Habits", value: "\(habits.count)", color: .blue)
                        }
                        
                        // The New Heatmap
                        VStack(alignment: .leading) {
                            Text("Activity (Last 35 Days)")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.bottom, 8)
                            
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(pastDays, id: \.self) { date in
                                    let taskCount = completionMap[date] ?? 0
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(heatmapColor(for: taskCount))
                                        .aspectRatio(1.0, contentMode: .fit)
                                }
                            }
                        }
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Statistics")
        }
    }
    
    // Changes the opacity based on how much you got done
    private func heatmapColor(for count: Int) -> Color {
        if count == 0 { return Color(white: 0.15) } // Empty day
        if count < 3  { return Color.pink.opacity(0.4) } // Light day
        if count < 6  { return Color.pink.opacity(0.7) } // Medium day
        return Color.pink // Highly productive day
    }
}

// Ensure you keep your StatBox struct here
struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value).font(.title).bold().foregroundColor(color)
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var habits: [HabitItem]
    @Query private var sessions: [PomodoroSession]
    
    var totalCompletedTasks: Int { allTasks.filter { $0.isCompleted }.count }
    var bestStreak: Int { habits.map { $0.streak }.max() ?? 0 }
    
    // Calculates total focus hours from Pomodoro
    var totalFocusHours: Double {
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        return Double(totalMinutes) / 60.0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Hero Metric: Focus Time
                        VStack {
                            Text(String(format: "%.1f", totalFocusHours))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(.pink)
                            Text("Hours Focused")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color(white: 0.1))
                        .cornerRadius(20)
                        
                        // Secondary Metrics Grid
                        HStack(spacing: 20) {
                            SmallStatBox(title: "Tasks Done", value: "\(totalCompletedTasks)", icon: "checkmark.square.fill", color: .green)
                            SmallStatBox(title: "Best Streak", value: "\(bestStreak)", icon: "flame.fill", color: .orange)
                        }
                        
                        // Habit Health
                        VStack(alignment: .leading) {
                            Text("Habit Engine").font(.headline).foregroundColor(.gray)
                            HStack {
                                Text("\(habits.count) Active Habits")
                                Spacer()
                                Image(systemName: "engine.combustion.fill").foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Analytics")
        }
    }
}

struct SmallStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundColor(color).font(.title2)
            Text(value).font(.title).bold().foregroundColor(.white)
            Text(title).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(16)
    }
}

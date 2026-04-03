import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var allTasks: [TaskItem]
    @Query private var habits: [HabitItem]
    @Query private var sessions: [PomodoroSession]
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var totalCompletedTasks: Int { allTasks.filter { $0.isCompleted }.count }
    var bestStreak: Int { habits.map { $0.streak }.max() ?? 0 }
    
    var totalFocusHours: Double {
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        return Double(totalMinutes) / 60.0
    }
    
    // NEW: Groups sessions by subject and calculates hours per subject
    var subjectBreakdown: [(name: String, hours: Double)] {
        var breakdown: [String: Int] = [:]
        for session in sessions {
            breakdown[session.subject, default: 0] += session.durationMinutes
        }
        // Converts to hours and sorts from highest to lowest
        return breakdown.map { (name: $0.key, hours: Double($0.value) / 60.0) }
            .sorted { $0.hours > $1.hours }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Hero Metric: Focus Time
                        VStack {
                            Text(String(format: "%.1f", totalFocusHours))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(.pink)
                            Text("Total Hours Focused")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(isDarkMode ? Color(white: 0.1) : Color.white)
                        .cornerRadius(20)
                        
                        // The New Subject Breakdown Chart
                        if !subjectBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Text("Subject Breakdown").font(.headline).foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chart.bar.fill").foregroundColor(.pink)
                                }
                                
                                ForEach(subjectBreakdown, id: \.name) { stat in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(stat.name).foregroundColor(isDarkMode ? .white : .black).bold()
                                            Spacer()
                                            Text(String(format: "%.1f hrs", stat.hours)).foregroundColor(.gray).font(.subheadline)
                                        }
                                        
                                        // Dynamic Progress Bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                                    .frame(height: 8)
                                                
                                                Capsule()
                                                    .fill(Color.pink)
                                                // Calculates width relative to the subject with the most hours
                                                    .frame(width: max(0, geo.size.width * CGFloat(stat.hours / (subjectBreakdown.first?.hours ?? 1))), height: 8)
                                            }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                            }
                            .padding()
                            .background(isDarkMode ? Color(white: 0.1) : Color.white)
                            .cornerRadius(20)
                        }
                        
                        HStack(spacing: 16) {
                            SmallStatBox(title: "Tasks Done", value: "\(totalCompletedTasks)", icon: "checkmark.square.fill", color: .green, isDarkMode: isDarkMode)
                            SmallStatBox(title: "Best Streak", value: "\(bestStreak)", icon: "flame.fill", color: .orange, isDarkMode: isDarkMode)
                        }
                        
                        // Habit Health
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(habits.count) Active Habits").foregroundColor(isDarkMode ? .white : .black).bold()
                                Spacer()
                                Image(systemName: "engine.combustion.fill").foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(isDarkMode ? Color(white: 0.1) : Color.white)
                        .cornerRadius(16)
                    }
                    .padding()
                    
                    Spacer().frame(height: 40) // Bottom safe space
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
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundColor(color).font(.title2)
            Text(value).font(.title).bold().foregroundColor(isDarkMode ? .white : .black)
            Text(title).font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(isDarkMode ? Color(white: 0.1) : Color.white)
        .cornerRadius(16)
    }
}

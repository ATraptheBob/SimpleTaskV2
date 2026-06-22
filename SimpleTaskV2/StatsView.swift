import SwiftUI
import SwiftData

enum TimeFilter: String, CaseIterable {
    case daily = "Daily"
    case monthly = "Monthly"
    case allTime = "All Time"
}

struct StatsView: View {
    @StateObject private var eventKitManager = EventKitManager.shared
    @Query private var habits: [HabitItem]
    @Query private var sessions: [PomodoroSession]
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var selectedTimeFilter: TimeFilter = .allTime
    @State private var bestStreak: Int = 0
    
    // Weekly AI Insights
    @State private var weeklyInsights: WeeklyInsightsResponse?
    @State private var isGeneratingInsights = false
    @State private var showInsightsError = false
    
    private func isDate(_ date: Date?, in filter: TimeFilter) -> Bool {
        guard let date = date else { return false }
        let calendar = Calendar.current
        switch filter {
        case .daily:
            return calendar.isDateInToday(date)
        case .monthly:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .allTime:
            return true
        }
    }
    
    var filteredSessions: [PomodoroSession] {
        sessions.filter { isDate($0.date, in: selectedTimeFilter) }
    }
    
    var totalCompletedTasks: Int {
        eventKitManager.completedReminders.filter { isDate($0.completionDate, in: selectedTimeFilter) }.count
    }
    
    var totalFocusHours: Double {
        let totalMinutes = filteredSessions.reduce(0) { $0 + $1.durationMinutes }
        return Double(totalMinutes) / 60.0
    }
    
    var subjectBreakdown: [(name: String, hours: Double)] {
        var breakdown: [String: Int] = [:]
        for session in filteredSessions {
            breakdown[session.subject, default: 0] += session.durationMinutes
        }
        return breakdown.map { (name: $0.key, hours: Double($0.value) / 60.0) }
            .sorted { $0.hours > $1.hours }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicBackgroundView()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        Picker("Time Range", selection: $selectedTimeFilter) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        // Hero Metric: Focus Time
                        VStack {
                            Text(String(format: "%.1f", totalFocusHours))
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.accent)
                            Text("Total Hours Focused")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
                        
                        // The New Subject Breakdown Chart
                        if !subjectBreakdown.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Text("Subject Breakdown").font(.headline).foregroundColor(.gray)
                                    Spacer()
                                    Image(systemName: "chart.bar.fill").foregroundColor(AppTheme.accent)
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
                                                    .fill(AppTheme.accent)
                                                // Calculates width relative to the subject with the most hours
                                                    .frame(width: max(0, geo.size.width * CGFloat(stat.hours / (subjectBreakdown.first?.hours ?? 1))), height: 8)
                                            }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                            }
                            .padding()
                            .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
                        }
                        
                        HStack(spacing: 16) {
                            SmallStatBox(title: "Tasks Done", value: "\(totalCompletedTasks)", icon: "checkmark.square.fill", color: AppTheme.matteTeal, isDarkMode: isDarkMode)
                            SmallStatBox(title: "Best Streak", value: "\(bestStreak)", icon: "flame.fill", color: AppTheme.matteAmber, isDarkMode: isDarkMode)
                        }
                        
                        // Habit Health
                        VStack(alignment: .leading) {
                            HStack {
                                Text("\(habits.count) Active Habits").foregroundColor(isDarkMode ? .white : .black).bold()
                                Spacer()
                                Image(systemName: "engine.combustion.fill").foregroundColor(AppTheme.matteBlue)
                            }
                        }
                        .padding()
                        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                        
                        // Weekly AI Insights
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(AppTheme.matteSlate)
                                    .font(.title2)
                                Text("Weekly AI Insights")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(isDarkMode ? .white : .black)
                                Spacer()
                                
                                Button(action: {
                                    fetchInsights()
                                }) {
                                    if isGeneratingInsights {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.matteSlate))
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(AppTheme.matteSlate)
                                            .font(.body.weight(.bold))
                                    }
                                }
                                .disabled(isGeneratingInsights)
                            }
                            
                            if showInsightsError {
                                Text("Failed to generate insights. Check your API key or internet connection.")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                            } else if let insights = weeklyInsights {
                                Text(insights.summary)
                                    .font(.body)
                                    .foregroundColor(isDarkMode ? .gray : .secondary)
                                
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("🏆 Top Habits")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppTheme.matteTeal)
                                        ForEach(insights.topHabits, id: \.self) { habit in
                                            Text("• \(habit)")
                                                .font(.subheadline)
                                                .foregroundColor(isDarkMode ? .white : .black)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("📉 Struggles")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(AppTheme.matteAmber)
                                        ForEach(insights.struggles, id: \.self) { habit in
                                            Text("• \(habit)")
                                                .font(.subheadline)
                                                .foregroundColor(isDarkMode ? .white : .black)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.top, 4)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Action Plan")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppTheme.matteSlate)
                                    Text(insights.recommendedAction)
                                        .font(.subheadline)
                                        .foregroundColor(isDarkMode ? .white : .black)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppTheme.matteSlate.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else if !isGeneratingInsights {
                                Text("Tap the refresh button to generate your weekly insights.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(20)
                        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLarge, style: .continuous))
                        .neutralShadow(radius: 8, y: 4, opacity: 0.10)
                    }
                    .padding()
                    
                    Spacer().frame(height: 40) // Bottom safe space
                }
            }
            .navigationTitle("Analytics")
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                bestStreak = habits.map { $0.streak }.max() ?? 0
            }
            .onChange(of: habits) { _, _ in
                bestStreak = habits.map { $0.streak }.max() ?? 0
            }
        }
    }
    
    private func fetchInsights() {
        isGeneratingInsights = true
        showInsightsError = false
        
        Task {
            do {
                let insights = try await GeminiManager.shared.generateWeeklyInsights(habits: habits, sessions: sessions)
                await MainActor.run {
                    self.weeklyInsights = insights
                    self.isGeneratingInsights = false
                }
            } catch {
                await MainActor.run {
                    self.showInsightsError = true
                    self.isGeneratingInsights = false
                    print("Error generating insights: \(error)")
                }
            }
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
        .background(isDarkMode ? AppTheme.surfaceSecondary : AppTheme.lightSurfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
    }
}

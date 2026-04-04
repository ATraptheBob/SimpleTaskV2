import SwiftUI
import SwiftData
import WidgetKit

// --- 1. THE SHARED MODEL ---
struct MonthData: Identifiable, Equatable {
    let id: Int
    let name: String
    let dates: [Date]
    let monthStart: Date
}

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [HabitItem]
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    @State private var showingAddSheet = false
    @State private var habitToEdit: HabitItem?
    
    @State private var selectedMonthIndex: Int = 11

    var dailyHabits: [HabitItem] { habits.filter { $0.frequency == .daily } }
    var weeklyHabits: [HabitItem] { habits.filter { $0.frequency == .weekly } }
    var monthlyHabits: [HabitItem] { habits.filter { $0.frequency == .monthly } }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color.black : Color.white).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text("Habits")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? .white : .black)
                        Spacer()
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.pink)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                    
                    HabitDashboardPanel(habits: habits, isDarkMode: isDarkMode, selectedMonthIndex: $selectedMonthIndex)
                        .padding(.bottom, 8)
                    
                    List {
                        HabitSection(title: "DAILY", habits: dailyHabits, editAction: { habitToEdit = $0 }, isDarkMode: isDarkMode)
                        HabitSection(title: "WEEKLY", habits: weeklyHabits, editAction: { habitToEdit = $0 }, isDarkMode: isDarkMode)
                        HabitSection(title: "MONTHLY", habits: monthlyHabits, editAction: { habitToEdit = $0 }, isDarkMode: isDarkMode)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) { AddHabitView() }
            .sheet(item: $habitToEdit) { habit in AddHabitView(habitToEdit: habit) }
        }
    }
}

// --- 2. DYNAMIC DASHBOARD PANEL ---
struct HabitDashboardPanel: View {
    var habits: [HabitItem]
    var isDarkMode: Bool
    @Binding var selectedMonthIndex: Int
    
    @State private var months: [MonthData] = []
    
    var dailyCompletions: [Date: Int] {
        var counts: [Date: Int] = [:]
        let calendar = Calendar.current
        for habit in habits {
            let days = Set(habit.completionDates.map { calendar.startOfDay(for: $0) })
            for day in days { counts[day, default: 0] += 1 }
        }
        return counts
    }

    private var monthlyStats: (total: Int, bestStreak: Int, dailyAvg: Double) {
        guard !months.isEmpty, selectedMonthIndex < months.count else { return (0, 0, 0) }
        let currentMonth = months[selectedMonthIndex]
        let calendar = Calendar.current
        
        let monthDates = currentMonth.dates.filter { calendar.isDate($0, equalTo: currentMonth.monthStart, toGranularity: .month) }
        
        // DYNAMIC ACCURACY: Only grade percentages based on habits scheduled for that specific day
        let dailyPercentages = monthDates.map { date -> Double in
            let weekday = calendar.component(.weekday, from: date)
            let activeHabitsForDay = habits.filter { $0.activeDays.contains(weekday) }
            
            if activeHabitsForDay.isEmpty { return 1.0 } // 100% if nothing was scheduled!
            
            let completedActive = activeHabitsForDay.filter { habit in
                let completions = Set(habit.completionDates.map { calendar.startOfDay(for: $0) })
                return completions.contains(date)
            }.count
            
            return Double(completedActive) / Double(activeHabitsForDay.count)
        }
        
        let avgDailyRate = (dailyPercentages.reduce(0, +) / Double(max(monthDates.count, 1))) * 100
        let totalVolume = monthDates.map { dailyCompletions[$0] ?? 0 }.reduce(0, +)
        
        var maxStreak = 0
        var currentStreak = 0
        for date in monthDates {
            if (dailyCompletions[date] ?? 0) > 0 {
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return (totalVolume, maxStreak, avgDailyRate)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 30) {
            HabitHeatmapView(completions: dailyCompletions, isDarkMode: isDarkMode, selectedMonth: $selectedMonthIndex, months: $months)
                .frame(width: 130)
            
            VStack(alignment: .leading, spacing: 18) {
                StatRow(icon: "checkmark.seal.fill", color: .pink, title: "MONTH TOTAL", value: "\(monthlyStats.total)", isDarkMode: isDarkMode)
                StatRow(icon: "flame.fill", color: .orange, title: "MONTH STREAK", value: "\(monthlyStats.bestStreak)", isDarkMode: isDarkMode)
                
                if selectedMonthIndex == 11 {
                    let today = Calendar.current.startOfDay(for: Date())
                    StatRow(icon: "star.fill", color: .yellow, title: "TODAY", value: "\(dailyCompletions[today] ?? 0)", isDarkMode: isDarkMode)
                } else {
                    StatRow(icon: "percent", color: .blue, title: "DAILY AVG", value: String(format: "%.0f%%", monthlyStats.dailyAvg), isDarkMode: isDarkMode)
                        .transition(.opacity)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedMonthIndex)
            .padding(.top, 4)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }
}

// --- 3. HEATMAP ENGINE ---
struct HabitHeatmapView: View {
    var completions: [Date: Int]
    var isDarkMode: Bool
    @Binding var selectedMonth: Int
    @Binding var months: [MonthData]
    @State private var showDots = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !months.isEmpty {
                Text(months[selectedMonth].name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.5))
                    .tracking(1.5)
                    .padding(.bottom, 8)
                
                TabView(selection: $selectedMonth) {
                    ForEach(months) { month in
                        MonthGrid(month: month, completions: completions, isDarkMode: isDarkMode)
                            .tag(month.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 122)
                
                HStack(spacing: 6) {
                    ForEach(0..<12) { index in
                        Circle()
                            .fill(index == selectedMonth ? (isDarkMode ? Color.white : Color.black) : Color.gray.opacity(0.3))
                            .frame(width: 5, height: 5)
                    }
                }
                .opacity(showDots ? 1 : 0)
                .padding(.top, 8)
            }
        }
        .onAppear { if months.isEmpty { self.months = generateMonths() } }
        .onChange(of: selectedMonth) { _, _ in withAnimation(.easeInOut(duration: 0.2)) { showDots = true } }
        .task(id: showDots) {
            if showDots {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation(.easeInOut(duration: 0.4)) { showDots = false }
            }
        }
    }
    
    func generateMonths() -> [MonthData] {
        var result: [MonthData] = []
        let calendar = Calendar.current
        let today = Date()
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return [] }
        
        for i in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: currentMonthStart) else { continue }
            let formatter = DateFormatter(); formatter.dateFormat = "MMM yyyy"
            let name = formatter.string(from: monthStart).uppercased()
            
            guard let range = calendar.range(of: .day, in: .month, for: monthStart),
                  let monthEnd = calendar.date(byAdding: .day, value: range.count - 1, to: monthStart),
                  let startOfGrid = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start,
                  let startOfLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthEnd)?.start,
                  let endOfGrid = calendar.date(byAdding: .day, value: 6, to: startOfLastWeek) else { continue }
            
            var dates: [Date] = []
            var currentDate = startOfGrid
            while currentDate <= endOfGrid {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            result.append(MonthData(id: 11 - i, name: name, dates: dates, monthStart: monthStart))
        }
        return result
    }
}

struct MonthGrid: View {
    let month: MonthData
    let completions: [Date: Int]
    let isDarkMode: Bool
    let rows = Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7)
    
    var body: some View {
        HStack {
            LazyHGrid(rows: rows, spacing: 4) {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                ForEach(month.dates, id: \.self) { date in
                    if !calendar.isDate(date, equalTo: month.monthStart, toGranularity: .month) {
                        Color.clear.frame(width: 14, height: 14)
                    } else {
                        let count = completions[date] ?? 0
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color(for: count, isFuture: date > today))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
    
    func color(for count: Int, isFuture: Bool) -> Color {
        if isFuture { return isDarkMode ? Color(white: 0.08) : Color(white: 0.96) }
        switch count {
        case 0: return isDarkMode ? Color(white: 0.15) : Color(white: 0.90)
        case 1: return Color.orange.opacity(0.4)
        case 2: return Color.orange.opacity(0.65)
        case 3: return Color.orange.opacity(0.85)
        default: return Color.orange.opacity(1.0)
        }
    }
}

// --- 4. SECTIONS AND STATS ---
struct StatRow: View {
    let icon: String; let color: Color; let title: String; let value: String; let isDarkMode: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(isDarkMode ? .white : .black)
                Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(.gray.opacity(0.8)).tracking(1.0)
            }
        }
    }
}

struct HabitSection: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    let title: String; let habits: [HabitItem]; let editAction: (HabitItem) -> Void; let isDarkMode: Bool
    private let hapticSound = HapticAndSoundManager.shared
    
    @State private var expandedHabitID: PersistentIdentifier? = nil
    
    var body: some View {
        if !habits.isEmpty {
            Section {
                ForEach(habits) { habit in
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            Button(action: { toggleHabit(habit) }) {
                                Image(systemName: isCompleted(habit) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isCompleted(habit) ? .gray : .orange)
                                    .font(.system(size: 22, weight: .light))
                            }
                            .buttonStyle(.plain)
                            
                            // Wrapping the text in a button to trigger the expansion
                            Button(action: {
                                hapticSound.triggerHapticSelection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    expandedHabitID = (expandedHabitID == habit.id) ? nil : habit.id
                                }
                            }) {
                                HStack {
                                    Text(habit.title).font(.system(size: 17, weight: .regular))
                                        .foregroundColor(isCompleted(habit) ? .gray : (isDarkMode ? .white : .black))
                                        .strikethrough(isCompleted(habit))
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("\(currentStreak(for: habit))").font(.system(size: 14, weight: .bold, design: .rounded))
                                        Image(systemName: "flame.fill").font(.system(size: 12))
                                    }
                                    .foregroundColor(isCompleted(habit) ? .gray.opacity(0.6) : .orange)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // THE 7-DAY SCHEDULE EXPANSION
                        if expandedHabitID == habit.id {
                            HStack(spacing: 10) {
                                let days = ["S", "M", "T", "W", "T", "F", "S"]
                                ForEach(0..<7, id: \.self) { i in
                                    let dayInt = i + 1 // 1 = Sunday, 7 = Saturday
                                    let isActive = habit.activeDays.contains(dayInt)
                                    
                                    Circle()
                                        .fill(isActive ? Color.orange : Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(Text(days[i]).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(isActive ? .white : (isDarkMode ? .white : .black)))
                                        .onTapGesture {
                                            hapticSound.triggerHapticSelection()
                                            withAnimation {
                                                if isActive { habit.activeDays.removeAll { $0 == dayInt } }
                                                else { habit.activeDays.append(dayInt) }
                                                try? modelContext.save()
                                                WidgetCenter.shared.reloadAllTimelines()
                                            }
                                        }
                                }
                                Spacer()
                            }
                            .padding(.top, 14)
                            .padding(.leading, 38)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .opacity(isCompleted(habit) ? 0.5 : 1.0)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(Color.gray.opacity(0.2))
                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    .swipeActions(edge: .leading) {
                        if leftSwipeAction != .none {
                            Button { handleHabitSwipe(option: leftSwipeAction, habit: habit) }
                            label: { Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon) }.tint(leftSwipeAction.color)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if rightSwipeAction != .none {
                            Button { handleHabitSwipe(option: rightSwipeAction, habit: habit) }
                            label: { Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon) }.tint(rightSwipeAction.color)
                        }
                    }
                }
            } header: {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.pink.opacity(0.8)).padding(.leading, 4).padding(.top, 16)
            }
        }
    }
    
    // FLAWLESS STREAK LOGIC: Ignores deselected days so your streak never breaks unfairly!
    private func currentStreak(for habit: HabitItem) -> Int {
        let calendar = Calendar.current
        var streak = 0
        let checkDate = calendar.startOfDay(for: Date())
        let completions = Set(habit.completionDates.map { calendar.startOfDay(for: $0) })
        let activeDays = habit.activeDays
        
        for i in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -i, to: checkDate) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let isCompleted = completions.contains(day)
            
            if activeDays.contains(weekday) {
                if isCompleted { streak += 1 }
                else {
                    if i == 0 { continue } // Missing today hasn't broken it yet
                    else { break } // Missing an active past day breaks it
                }
            } else {
                if isCompleted { streak += 1 } // Bonus points if you do it on a day off!
                // If not completed, it doesn't break because it wasn't scheduled.
            }
        }
        return streak
    }
    
    private func isCompleted(_ habit: HabitItem) -> Bool {
        let calendar = Calendar.current
        return habit.completionDates.contains { calendar.isDateInToday($0) }
    }
    
    private func toggleHabit(_ habit: HabitItem) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isCompleted(habit) {
                habit.completionDates.removeAll { calendar.isDate($0, equalTo: today, toGranularity: .day) }
                hapticSound.triggerHapticSelection()
                hapticSound.playSuccessSound()
            } else {
                habit.completionDates.append(Date())
                hapticSound.triggerHapticSuccess()
                hapticSound.playCompleteSound()
            }
            try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func handleHabitSwipe(option: SwipeOption, habit: HabitItem) {
            switch option {
            case .edit: editAction(habit)
            case .delete:
                modelContext.delete(habit)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            case .toggle: toggleHabit(habit)
            case .date: break // FIX: Added the missing date case (does nothing for habits)
            case .none: break
            }
        }
}

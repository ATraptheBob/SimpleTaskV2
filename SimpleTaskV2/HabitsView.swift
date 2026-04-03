import SwiftUI
import SwiftData
import WidgetKit

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [HabitItem]
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var showingAddSheet = false
    @State private var habitToEdit: HabitItem?
    
    var dailyHabits: [HabitItem] { habits.filter { $0.frequency == .daily } }
    var weeklyHabits: [HabitItem] { habits.filter { $0.frequency == .weekly } }
    var monthlyHabits: [HabitItem] { habits.filter { $0.frequency == .monthly } }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                List {
                    HabitSection(title: "Daily", habits: dailyHabits, editAction: { habitToEdit = $0 }, isDarkMode: isDarkMode)
                    HabitSection(title: "Weekly", habits: weeklyHabits, editAction: { habitToEdit = $0 }, isDarkMode: isDarkMode)
                    HabitSection(title: "Monthly", habits: monthlyHabits, editAction: { habitToEdit = $0 }, isDarkMode: isDarkMode)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Habits")
            .toolbar {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus").foregroundColor(.pink)
                }
            }
            .sheet(isPresented: $showingAddSheet) { AddHabitView() }
            .sheet(item: $habitToEdit) { habit in AddHabitView(habitToEdit: habit) }
        }
    }
}

struct HabitSection: View {
    // 1. We brought the context and settings INSIDE the section
    @Environment(\.modelContext) private var modelContext
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    let title: String
    let habits: [HabitItem]
    let editAction: (HabitItem) -> Void
    let isDarkMode: Bool
    private let hapticSound = HapticAndSoundManager.shared
    
    var body: some View {
        if !habits.isEmpty {
            Section(header: Text(title).foregroundColor(.pink).bold()) {
                ForEach(habits) { habit in
                    HStack(spacing: 12) {
                        Button(action: { toggleHabit(habit) }) {
                            Image(systemName: isCompleted(habit) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted(habit) ? .gray : .orange)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading) {
                            Text(habit.title)
                                .foregroundColor(isCompleted(habit) ? .gray : (isDarkMode ? .white : .black))
                                .strikethrough(isCompleted(habit))
                            Text("Streak: \(habit.streak) 🔥").font(.caption).foregroundColor(.orange)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if leftSwipeAction != .none {
                            Button {
                                handleHabitSwipe(option: leftSwipeAction, habit: habit)
                            } label: {
                                Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon)
                            }
                            .tint(leftSwipeAction.color)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if rightSwipeAction != .none {
                            Button {
                                handleHabitSwipe(option: rightSwipeAction, habit: habit)
                            } label: {
                                Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon)
                            }
                            .tint(rightSwipeAction.color)
                        }
                    }
                }
            }
        }
    }
    
    private func isCompleted(_ habit: HabitItem) -> Bool {
        let calendar = Calendar.current
        return habit.completionDates.contains { date in
            switch habit.frequency ?? .daily {
            case .daily: return calendar.isDateInToday(date)
            case .weekly: return calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly: return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
            case .none: return false
            }
        }
    }
    
    private func toggleHabit(_ habit: HabitItem) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        hapticSound.triggerHapticSelection()
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isCompleted(habit) {
                habit.completionDates.removeAll { date in
                    calendar.isDate(date, equalTo: today, toGranularity: .day)
                }
            } else {
                hapticSound.playSuccessSound()
                habit.completionDates.append(Date())
            }
            // Ensure we save and update widgets when toggled directly
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // 2. The swipe handler is now inside the struct so it can access everything
    private func handleHabitSwipe(option: SwipeOption, habit: HabitItem) {
        switch option {
        case .edit:
            editAction(habit) // Triggers the sheet passed down from HabitsView
        case .delete:
            modelContext.delete(habit)
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        case .toggle:
            toggleHabit(habit)
        case .none:
            break
        }
    }
}

import SwiftUI
import SwiftData
import WidgetKit

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [HabitItem]
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete
    
    @State private var showingAddSheet = false
    @State private var habitToEdit: HabitItem?
    
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
                    .padding(.bottom, 10)
                    
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

struct HabitSection: View {
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
            Section {
                ForEach(habits) { habit in
                    HStack(spacing: 16) {
                        Button(action: { toggleHabit(habit) }) {
                            Image(systemName: isCompleted(habit) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted(habit) ? .gray : .orange)
                                .font(.system(size: 22, weight: .light))
                        }
                        .buttonStyle(.plain)
                        
                        Text(habit.title)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(isCompleted(habit) ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(isCompleted(habit))
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(habit.streak)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(isCompleted(habit) ? .gray.opacity(0.6) : .orange)
                        .padding(.trailing, 4)
                    }
                    .opacity(isCompleted(habit) ? 0.5 : 1.0)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowSeparatorTint(Color.gray.opacity(0.2))
                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                    // FIX: Changed from 62 to 0
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if leftSwipeAction != .none {
                            Button { handleHabitSwipe(option: leftSwipeAction, habit: habit) }
                            label: { Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon) }
                                .tint(leftSwipeAction.color)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if rightSwipeAction != .none {
                            Button { handleHabitSwipe(option: rightSwipeAction, habit: habit) }
                            label: { Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon) }
                                .tint(rightSwipeAction.color)
                        }
                    }
                }
            } header: {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.pink.opacity(0.8))
                    .padding(.leading, 4)
                    .padding(.top, 16)
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
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isCompleted(habit) {
                habit.completionDates.removeAll { date in calendar.isDate(date, equalTo: today, toGranularity: .day) }
                hapticSound.triggerHapticSelection()
                hapticSound.playSuccessSound()
            } else {
                habit.completionDates.append(Date())
                hapticSound.triggerHapticSuccess()
                hapticSound.playCompleteSound()
            }
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
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
        case .none: break
        }
    }
}

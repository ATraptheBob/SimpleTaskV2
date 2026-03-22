import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var habitToEdit: HabitItem?

    var dailyHabits: [HabitItem] { habits.filter { $0.frequency == .daily } }
    var weeklyHabits: [HabitItem] { habits.filter { $0.frequency == .weekly } }
    var monthlyHabits: [HabitItem] { habits.filter { $0.frequency == .monthly } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                List {
                    HabitSection(title: "Daily", habits: dailyHabits, editAction: { habitToEdit = $0 })
                    HabitSection(title: "Weekly", habits: weeklyHabits, editAction: { habitToEdit = $0 })
                    HabitSection(title: "Monthly", habits: monthlyHabits, editAction: { habitToEdit = $0 })
                }
                .listStyle(.plain)
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

// Reusable logic section
struct HabitSection: View {
    let title: String
    let habits: [HabitItem]
    let editAction: (HabitItem) -> Void
    
    var body: some View {
        if !habits.isEmpty {
            Section(header: Text(title).foregroundColor(.pink).bold()) {
                ForEach(habits) { habit in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(habit.title).foregroundColor(.white)
                            Text("Streak: \(habit.streak) 🔥").font(.caption).foregroundColor(.orange)
                        }
                        Spacer()
                        Button(action: { toggleHabit(habit) }) {
                            Image(systemName: isCompleted(habit) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isCompleted(habit) ? .green : .gray)
                                .font(.title2)
                        }.buttonStyle(.plain)
                    }
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button { editAction(habit) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                    }
                }
            }
        }
    }
    
    // Evaluates completion by searching the completionDates array
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
    
    // Adds or removes completion dates
    private func toggleHabit(_ habit: HabitItem) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        withAnimation(.spring()) {
            if isCompleted(habit) {
                // Remove today's completion (unchecking)
                habit.completionDates.removeAll { date in
                    calendar.isDate(date, equalTo: today, toGranularity: .day)
                }
            } else {
                // Add new completion
                habit.completionDates.append(Date())
            }
        }
    }
}

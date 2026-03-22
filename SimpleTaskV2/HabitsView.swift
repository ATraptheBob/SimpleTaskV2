import SwiftUI
import SwiftData

struct HabitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var habits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var habitToEdit: HabitItem? // Tracks which habit you tapped 'Edit' on

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                if habits.isEmpty {
                    Text("No habits yet. Tap + to start.")
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(habits) { habit in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.title)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                    Text("Streak: \(habit.streak) 🔥")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                                Spacer()
                                Button(action: { completeHabit(habit) }) {
                                    Image(systemName: isCompletedToday(habit) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isCompletedToday(habit) ? .green : .gray)
                                        .font(.title)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                            // The new Edit swipe action
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    habitToEdit = habit
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteHabits)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus").foregroundColor(.pink)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddHabitView()
            }
            .sheet(item: $habitToEdit) { habit in
                AddHabitView(habitToEdit: habit) // Passes the specific habit to the sheet
            }
        }
    }

    private func completeHabit(_ habit: HabitItem) {
        let calendar = Calendar.current
        if isCompletedToday(habit) { return }
        
        if let lastDate = habit.lastCompletedDate, calendar.isDateInYesterday(lastDate) {
            habit.streak += 1
        } else if habit.lastCompletedDate == nil {
            habit.streak = 1
        } else {
            habit.streak = 1
        }
        habit.lastCompletedDate = Date()
    }

    private func isCompletedToday(_ habit: HabitItem) -> Bool {
        guard let lastDate = habit.lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }
    
    private func deleteHabits(offsets: IndexSet) {
        for index in offsets { modelContext.delete(habits[index]) }
    }
}

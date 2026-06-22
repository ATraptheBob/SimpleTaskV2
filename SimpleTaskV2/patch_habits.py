import re

path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/HabitsView.swift'
with open(path, 'r') as f:
    content = f.read()

# Replace variables in HabitsView
content = re.sub(
    r'@Environment\(\\\.modelContext\) private var modelContext\n\s*@Query private var habits: \[HabitItem\]',
    r'@StateObject private var eventKitManager = EventKitManager.shared\n    var habits: [ComputedHabit] { eventKitManager.computedHabits }',
    content
)

content = content.replace('@State private var habitToEdit: HabitItem?', '@State private var habitToEdit: ComputedHabit?')
content = content.replace('var dailyHabits: [HabitItem]', 'var dailyHabits: [ComputedHabit]')
content = content.replace('var weeklyHabits: [HabitItem]', 'var weeklyHabits: [ComputedHabit]')
content = content.replace('var monthlyHabits: [HabitItem]', 'var monthlyHabits: [ComputedHabit]')

# HabitDashboardPanel
content = content.replace('var habits: [HabitItem]', 'var habits: [ComputedHabit]')
content = content.replace('-> [UUID: Set<Date>]', '-> [String: Set<Date>]')
content = content.replace('cache: [UUID: Set<Date>]', 'cache: [String: Set<Date>]')
content = content.replace('var activeHabitsByWeekday: [Int: [HabitItem]]', 'var activeHabitsByWeekday: [Int: [ComputedHabit]]')

# HabitSection
content = content.replace('let title: String; let habits: [HabitItem]; let editAction: (HabitItem) -> Void', 'let title: String; let habits: [ComputedHabit]; let editAction: (ComputedHabit) -> Void')
content = content.replace('@State private var expandedHabitID: PersistentIdentifier? = nil', '@State private var expandedHabitID: String? = nil')
content = content.replace('    @Environment(\\.modelContext) private var modelContext\n', '')

# Remove currentStreak call
content = content.replace('Text("\\(currentStreak(for: habit))")', 'Text("\\(habit.streak)")')

# Active days toggle
active_days_old = """                                            withAnimation {
                                                if isActive { habit.activeDays.removeAll { $0 == dayInt } }
                                                else { habit.activeDays.append(dayInt) }
                                                try? modelContext.save()
                                                WidgetCenter.shared.reloadAllTimelines()
                                            }"""
active_days_new = """                                            withAnimation {
                                                var updatedActive = habit.activeDays
                                                if isActive { updatedActive.removeAll { $0 == dayInt } }
                                                else { updatedActive.append(dayInt) }
                                                try? EventKitManager.shared.addOrUpdateHabit(
                                                    habitID: habit.habitID,
                                                    title: habit.title,
                                                    frequency: habit.frequency,
                                                    activeDays: updatedActive
                                                )
                                                WidgetCenter.shared.reloadAllTimelines()
                                            }"""
content = content.replace(active_days_old, active_days_new)

# Remove currentStreak function block
content = re.sub(
    r'\s*// FLAWLESS STREAK LOGIC.*?\n\s*private func currentStreak\(for habit: HabitItem\) -> Int \{.*?\n\s*\}\n',
    '\n',
    content,
    flags=re.DOTALL
)
content = re.sub(
    r'\s*// FLAWLESS STREAK LOGIC.*?\n\s*private func currentStreak\(for habit: ComputedHabit\) -> Int \{.*?\n\s*\}\n',
    '\n',
    content,
    flags=re.DOTALL
)

# isCompleted
content = content.replace('private func isCompleted(_ habit: HabitItem) -> Bool {', 'private func isCompleted(_ habit: ComputedHabit) -> Bool {')
content = re.sub(
    r'private func isCompleted\(_ habit: ComputedHabit\) -> Bool \{.*?\n\s*\}',
    'private func isCompleted(_ habit: ComputedHabit) -> Bool {\n        return habit.isDone\n    }',
    content,
    flags=re.DOTALL
)

# toggleHabit
toggle_old = """    private func toggleHabit(_ habit: HabitItem) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isCompleted(habit) {
                habit.completionDates.removeAll { calendar.isDate($0, equalTo: today, toGranularity: .day) }
                habit.updateStreak()
                hapticSound.triggerHapticSelection()
                hapticSound.playSuccessSound()
            } else {
                habit.completionDates.append(Date())
                habit.updateStreak()
                hapticSound.triggerHapticSuccess()
                hapticSound.playCompleteSound()
            }
            try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines()
        }
    }"""
toggle_new = """    private func toggleHabit(_ habit: ComputedHabit) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if isCompleted(habit) {
                try? EventKitManager.shared.toggleHabitCompletion(habitID: habit.habitID)
                hapticSound.triggerHapticSelection()
                hapticSound.playSuccessSound()
            } else {
                try? EventKitManager.shared.toggleHabitCompletion(habitID: habit.habitID)
                hapticSound.triggerHapticSuccess()
                hapticSound.playCompleteSound()
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }"""
content = content.replace(toggle_old, toggle_new)
content = content.replace(toggle_old.replace('HabitItem', 'ComputedHabit'), toggle_new)

# handleHabitSwipe
swipe_old = """    private func handleHabitSwipe(option: SwipeOption, habit: HabitItem) {
            switch option {
            case .edit: editAction(habit)
            case .delete:
                modelContext.delete(habit)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            case .toggle: toggleHabit(habit)
            case .date: break
            case .restore: break
            case .none: break
            }
        }"""
swipe_new = """    private func handleHabitSwipe(option: SwipeOption, habit: ComputedHabit) {
            switch option {
            case .edit: editAction(habit)
            case .delete:
                try? EventKitManager.shared.deleteHabit(habitID: habit.habitID)
                WidgetCenter.shared.reloadAllTimelines()
            case .toggle: toggleHabit(habit)
            case .date: break
            case .restore: break
            case .none: break
            }
        }"""
content = content.replace(swipe_old, swipe_new)
content = content.replace(swipe_old.replace('HabitItem', 'ComputedHabit'), swipe_new)

# MiniHeatmapView
content = content.replace('let habit: HabitItem', 'let habit: ComputedHabit')

with open(path, 'w') as f:
    f.write(content)
print("HabitsView patched.")

import os
import re

inbox_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift'
with open(inbox_path, 'r') as f:
    content = f.read()

# Remove @Query private var allHabits: [HabitItem]
content = re.sub(r'\s*@Query private var allHabits: \[HabitItem\]', '', content)
# Remove @State private var habitToEdit: HabitItem?
content = re.sub(r'\s*@State private var habitToEdit: HabitItem\?', '', content)

# Remove dueHabits var block
due_habits_pattern = r'\s*var dueHabits: \[HabitItem\] \{[^{}]*\{[^{}]*\}[^{}]*\}'
content = re.sub(due_habits_pattern, '', content)

# Remove habitSections from List
content = content.replace('habitSections()', '')

# Remove habitSections definition
habit_sections_pattern = r'\s*@ViewBuilder\s*private func habitSections\(\) -> some View \{[^{}]*\{[^{}]*\{[^{}]*\}[^{}]*\}[^{}]*\}'
content = re.sub(habit_sections_pattern, '', content)

# Remove habitRow definition (It might have nested brackets, let's use a simpler approach: replace it with empty func if it's too complex)
# Actually, we can just replace 'HabitItem' with 'ComputedHabit' everywhere else in the file that we might have missed, or remove the func entirely.
# Let's just remove habitRow
habit_row_start = content.find('private func habitRow(for habit: HabitItem)')
if habit_row_start != -1:
    # Find matching brace
    start_brace = content.find('{', habit_row_start)
    brace_count = 1
    i = start_brace + 1
    while brace_count > 0 and i < len(content):
        if content[i] == '{': brace_count += 1
        elif content[i] == '}': brace_count -= 1
        i += 1
    # also remove @ViewBuilder before it
    vb_start = content.rfind('@ViewBuilder', 0, habit_row_start)
    content = content[:vb_start] + content[i:]

# Remove toggleHabit
toggle_habit_start = content.find('private func toggleHabit(_ habit: HabitItem)')
if toggle_habit_start != -1:
    start_brace = content.find('{', toggle_habit_start)
    brace_count = 1
    i = start_brace + 1
    while brace_count > 0 and i < len(content):
        if content[i] == '{': brace_count += 1
        elif content[i] == '}': brace_count -= 1
        i += 1
    content = content[:toggle_habit_start] + content[i:]

# Remove handleHabitSwipe
swipe_start = content.find('private func handleHabitSwipe(option: SwipeOption, habit: HabitItem)')
if swipe_start != -1:
    start_brace = content.find('{', swipe_start)
    brace_count = 1
    i = start_brace + 1
    while brace_count > 0 and i < len(content):
        if content[i] == '{': brace_count += 1
        elif content[i] == '}': brace_count -= 1
        i += 1
    content = content[:swipe_start] + content[i:]

# Remove any other occurrences of dueHabits in the file (like in currentDueHabits)
content = content.replace('let currentDueHabits = dueHabits', '')
content = content.replace('currentActiveTasks.isEmpty && currentDueHabits.isEmpty', 'currentActiveTasks.isEmpty')

with open(inbox_path, 'w') as f:
    f.write(content)

print("Inbox patched")

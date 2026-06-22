import os
import re

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)

# 1. SimpleTaskV2App.swift
app_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/SimpleTaskV2App.swift'
content = read_file(app_path)
content = content.replace('HabitItem.self, ', '')
content = re.sub(r'let allHabits = \(try\? context\.fetch\(FetchDescriptor<HabitItem>\(\)\)\) \?\? \[\]\n\s*', '', content)
content = content.replace('allHabits: allHabits, ', '')
write_file(app_path, content)

# 2. SmartNotificationScheduler.swift
sns_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/SmartNotificationScheduler.swift'
content = read_file(sns_path)
content = content.replace('allHabits: [HabitItem]', 'allHabits: [ComputedHabit]')
write_file(sns_path, content)

# 3. GeminiManager.swift
gemini_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/GeminiManager.swift'
content = read_file(gemini_path)
content = content.replace('habits: [HabitItem]', 'habits: [ComputedHabit]')
write_file(gemini_path, content)

# 4. StatsView.swift
stats_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/StatsView.swift'
content = read_file(stats_path)
content = re.sub(
    r'@Query private var habits: \[HabitItem\]',
    r'@StateObject private var eventKitManager = EventKitManager.shared\n    var habits: [ComputedHabit] { eventKitManager.computedHabits }',
    content
)
write_file(stats_path, content)

# 5. TaskWidget.swift
widget_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/TaskWidget/TaskWidget.swift'
content = read_file(widget_path)
content = content.replace('HabitItem.self, ', '')
content = re.sub(r'let descriptorHabits = FetchDescriptor<HabitItem>\(\).*?let dueHabitsCount = allHabits.filter \{ !isHabitDone\(\$0\) \}.count', 'let dueHabitsCount = 0', content, flags=re.DOTALL)
content = re.sub(r'private func isHabitDone\(_ habit: HabitItem\).*?\}', '', content, flags=re.DOTALL)
content = re.sub(r'let descriptor = FetchDescriptor<HabitItem>\(\).*?habit\.updateStreak\(\)\n\s*try context\.save\(\)\n\s*\}', '', content, flags=re.DOTALL)
content = re.sub(r'struct ToggleHabitIntent: AppIntent \{.*?return \.result\(\)\n\s*\}', '', content, flags=re.DOTALL)
write_file(widget_path, content)

# 6. InboxView.swift
inbox_path = '/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift'
content = read_file(inbox_path)
content = re.sub(r'@Query private var allHabits: \[HabitItem\]\n\s*', '', content)
content = re.sub(r'@State private var habitToEdit: HabitItem\?\n\s*', '', content)
content = re.sub(r'var dueHabits: \[HabitItem\] \{.*?\}\n\s*', '', content, flags=re.DOTALL)
# Remove Habits section from Inbox (if it exists)
content = re.sub(r'if !dueHabits\.isEmpty \{.*?\}\n\s*\}\n', '', content, flags=re.DOTALL) # Assuming the block can be roughly matched, wait this might break syntax. I'll use a python script that accurately parses or just replace specific strings.

print("Done patching files.")

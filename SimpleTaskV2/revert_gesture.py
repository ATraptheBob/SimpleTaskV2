import re

with open("InboxView.swift", "r") as f:
    content = f.read()

# 1. Remove the states added in previous patch
content = re.sub(r'\s*@State private var dragDirectionDetermined = false\s*@State private var isVerticalDrag = false\n', '\n', content)

# 2. Remove the simultaneousGesture from ZStack
gesture_regex = r'\.simultaneousGesture\(\s*DragGesture\(minimumDistance: 20\).*?dragDirectionDetermined = false\s*\}\s*\)'
content = re.sub(gesture_regex, '', content, flags=re.DOTALL)

with open("InboxView.swift", "w") as f:
    f.write(content)

print("Gesture reverted")

import re

with open("InboxView.swift", "r") as f:
    content = f.read()

# 1. First, we need to add a state to track the global drag
state_insertion = """
    @State private var dragDirectionDetermined = false
    @State private var isVerticalDrag = false
"""
content = re.sub(r'(@State private var listTopOffset: CGFloat = 0)', r'\1\n' + state_insertion, content)

# 2. Find the main ZStack and attach a gesture
# The ZStack containing DynamicBackgroundView()
# Then VStack(spacing: 0) { ... }
# We want to attach it to the VStack so it catches the title and the List.

vstack_regex = r'(// 1\. MAIN CONTENT LAYER\s*VStack\(spacing: 0\) \{.*?if showSearchBox \{\s*searchOverlay\(\)\s*\})'

# Actually, the easiest place to attach a highPriorityGesture or simultaneousGesture is to the ZStack itself, or the top level NavigationStack.
# Let's attach to the ZStack.
zstack_regex = r'(ZStack \{\s*DynamicBackgroundView\(\).*?if showSearchBox \{\s*searchOverlay\(\)\s*\}\s*\})'
zstack_match = re.search(zstack_regex, content, flags=re.DOTALL)
if zstack_match:
    gesture_code = """
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if !dragDirectionDetermined {
                            dragDirectionDetermined = true
                            isVerticalDrag = abs(value.translation.height) > abs(value.translation.width) * 1.5
                        }
                        
                        guard isVerticalDrag else { return }
                        
                        // Check if they are pulling down significantly
                        if value.translation.height > 60 {
                            // Only trigger if we haven't already
                            if !showSearchBox {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showSearchBox = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFocused = true
                                }
                                HapticAndSoundManager.shared.triggerHapticSelection()
                            }
                        }
                    }
                    .onEnded { _ in
                        dragDirectionDetermined = false
                    }
            )"""
    new_zstack = zstack_match.group(1) + gesture_code
    content = content.replace(zstack_match.group(1), new_zstack)

with open("InboxView.swift", "w") as f:
    f.write(content)

print("Patch inbox gesture applied")

import re

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'r') as f:
    content = f.read()

# Add droppedCalendarId state
content = content.replace("@State private var isScrollingDown = false", "@State private var isScrollingDown = false\n    @State private var droppedCalendarId: String? = nil")

# Pass it to AddTaskView
content = content.replace("AddTaskView(isPresented: $showingAddSheet)", "AddTaskView(initialCalendarIdentifier: droppedCalendarId)")
# Also handle case if it was just AddTaskView() or something else.
content = content.replace("AddTaskView()", "AddTaskView(initialCalendarIdentifier: droppedCalendarId)")

# Set droppedCalendarId in DragGesture
old_end_logic = """                            let targetId = targetCalendarId
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                                dragOffset = .zero
                                isDraggingToAdd = false
                                targetCalendarId = nil
                            }
                            
                            // Present add sheet with pre-selected target
                            // We need to pass targetId somehow.
                            // We will use initialCalendarIdentifier
                            // But AddTaskView needs to be updated in InboxView callsite
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                                showingAddSheet = true
                                // We store the dropped target in a temporary variable to pass to AddTaskView
                            }"""

new_end_logic = """                            let targetId = targetCalendarId
                            droppedCalendarId = targetId
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                                dragOffset = .zero
                                isDraggingToAdd = false
                                targetCalendarId = nil
                            }
                            
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                                showingAddSheet = true
                            }"""
content = content.replace(old_end_logic, new_end_logic)

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'w') as f:
    f.write(content)


import re

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'r') as f:
    content = f.read()

# Add coordinateSpace to ZStack
if '.coordinateSpace(name: "Global")' not in content:
    zstack_idx = content.find("ZStack {")
    if zstack_idx != -1:
        # We need to insert .coordinateSpace(name: "Global") at the end of ZStack
        # Let's just find `NavigationView {` and the corresponding ZStack
        pass # Actually we can just put coordinateSpace on the DragGesture as .global

# Rewrite addButton DragGesture
old_gesture = """            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressDown {
                            isPressDown = true
                            HapticAndSoundManager.shared.triggerHapticSelection()
                        }
                    }
                    .onEnded { _ in
                        isPressDown = false
                        if isVoiceCapturing {
                            isVoiceCapturing = false
                            voiceManager.stopRecording()
                            HapticAndSoundManager.shared.triggerHapticSuccess()
                            
                            if !voiceManager.transcribedText.isEmpty && voiceManager.transcribedText != "Listening..." {
                                processVoiceCapture()
                            }
                        } else {
                            HapticAndSoundManager.shared.triggerHapticSelection()
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                                showingAddSheet = true
                            }
                        }
                    }
            )"""

new_gesture = """            .offset(dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !isPressDown {
                            isPressDown = true
                            HapticAndSoundManager.shared.triggerHapticSelection()
                        }
                        
                        if !isVoiceCapturing {
                            let dragThreshold: CGFloat = 10
                            let translation = CGSize(width: value.translation.width, height: value.translation.height)
                            
                            if abs(translation.width) > dragThreshold || abs(translation.height) > dragThreshold || isDraggingToAdd {
                                isDraggingToAdd = true
                                dragOffset = translation
                                
                                // Check bounds to highlight list
                                let dragY = value.location.y
                                var newTarget: String? = nil
                                for (calId, bounds) in sectionBounds {
                                    if dragY >= bounds.minY && dragY <= bounds.maxY {
                                        newTarget = calId
                                        break
                                    }
                                }
                                
                                if targetCalendarId != newTarget {
                                    targetCalendarId = newTarget
                                    HapticAndSoundManager.shared.triggerHapticSelection()
                                }
                                
                                // Auto-scroll logic
                                let screenHeight = UIScreen.main.bounds.height
                                if dragY < screenHeight * 0.2 {
                                    isScrollingUp = true
                                    isScrollingDown = false
                                } else if dragY > screenHeight * 0.8 {
                                    isScrollingUp = false
                                    isScrollingDown = true
                                } else {
                                    isScrollingUp = false
                                    isScrollingDown = false
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressDown = false
                        isScrollingUp = false
                        isScrollingDown = false
                        
                        if isVoiceCapturing {
                            isVoiceCapturing = false
                            voiceManager.stopRecording()
                            HapticAndSoundManager.shared.triggerHapticSuccess()
                            
                            if !voiceManager.transcribedText.isEmpty && voiceManager.transcribedText != "Listening..." {
                                processVoiceCapture()
                            }
                        } else {
                            HapticAndSoundManager.shared.triggerHapticSelection()
                            
                            let targetId = targetCalendarId
                            
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
                            }
                        }
                    }
            )"""

content = content.replace(old_gesture, new_gesture)

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'w') as f:
    f.write(content)


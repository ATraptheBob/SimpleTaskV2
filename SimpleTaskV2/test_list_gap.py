import re

with open("InboxView.swift", "r") as f:
    content = f.read()

# Add GeometryReader back
list_start = r'(List \{\s*)(if !currentActiveTasks.isEmpty \|\| isParsingVoiceTask \{\s*voiceTaskProcessingSection\(\))'
list_replacement = r"""\1
                            Color.clear
                                .frame(height: 0)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: ScrollOffsetKey.self,
                                            value: geo.frame(in: .named("InboxList")).minY
                                        )
                                    }
                                )
                            
                            \2"""
content = re.sub(list_start, list_replacement, content)

# Add .environment(\.defaultMinListRowHeight, 0) and .onPreferenceChange to List
list_end_regex = r'(\.autoScroll\(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown\) \{ offset in.*?\n\s*\}\n)'
list_end_replacement = r"""\1
                        .environment(\.defaultMinListRowHeight, 0)
                        .onPreferenceChange(ScrollOffsetKey.self) { minY in
                            if minY > 80 && !showSearchBox {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showSearchBox = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFocused = true
                                }
                                HapticAndSoundManager.shared.triggerHapticSelection()
                            }
                        }
"""
content = re.sub(list_end_regex, list_end_replacement, content, flags=re.DOTALL)

with open("InboxView.swift", "w") as f:
    f.write(content)

print("Patch applied")

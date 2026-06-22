import re

with open("InboxView.swift", "r") as f:
    content = f.read()

bad_block = """                        .environment(\.defaultMinListRowHeight, 0)
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
                                HapticAndSoundManager.shared.triggerHapticSelection()
                            }
                        }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFocused = true
                                }
                                HapticAndSoundManager.shared.triggerHapticSelection()
                            }
                        }
                        .onPreferenceChange(SectionBoundsKey.self)"""

good_block = """                        .environment(\.defaultMinListRowHeight, 0)
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
                        .onPreferenceChange(SectionBoundsKey.self)"""

content = content.replace(bad_block, good_block)

with open("InboxView.swift", "w") as f:
    f.write(content)

print("Syntax fixed")

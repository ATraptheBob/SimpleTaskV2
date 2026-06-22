import re

with open("InboxView.swift", "r") as f:
    content = f.read()

# 1. Remove the GeometryReader dummy item
geom_reader_regex = r'\s*GeometryReader \{ geo in\s*Color\.clear\.preference\(\s*key: ScrollOffsetKey\.self,\s*value: geo\.frame\(in: \.named\("InboxList"\)\)\.minY\s*\)\s*\}\s*\.frame\(height: 0\)\s*\.listRowInsets\(EdgeInsets\(\)\)\s*\.listRowSeparator\(\.hidden\)\s*\.listRowBackground\(Color\.clear\)'
content = re.sub(geom_reader_regex, '', content, flags=re.DOTALL)

# 2. Update .autoScroll and remove onPreferenceChange
autoscroll_regex = r'\.autoScroll\(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown\)\s*\.onPreferenceChange\(ScrollOffsetKey\.self\) \{ minY in.*?HapticAndSoundManager\.shared\.triggerHapticSelection\(\)\s*\}\s*\}'
autoscroll_replacement = """.autoScroll(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown) { offset in
                            if offset < -80 && !showSearchBox {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showSearchBox = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isSearchFocused = true
                                }
                                HapticAndSoundManager.shared.triggerHapticSelection()
                            }
                        }"""
content = re.sub(autoscroll_regex, autoscroll_replacement, content, flags=re.DOTALL)

with open("InboxView.swift", "w") as f:
    f.write(content)

print("Patch drag applied")

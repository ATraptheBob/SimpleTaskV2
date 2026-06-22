import re

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'r') as f:
    content = f.read()

# 1. Define SectionBoundsKey at the top
preference_key = """
struct SectionBoundsKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
"""
if "struct SectionBoundsKey" not in content:
    content = content.replace("struct InboxView: View {", preference_key + "\nstruct InboxView: View {")

# 2. Add Magic Add Button states
states = """
    // Magic Add Button States
    @State private var dragOffset: CGSize = .zero
    @State private var isDraggingToAdd = false
    @State private var targetCalendarId: String? = nil
    @State private var sectionBounds: [String: CGRect] = [:]
    @State private var isScrollingUp = false
    @State private var isScrollingDown = false
"""
if "Magic Add Button States" not in content:
    content = content.replace("private let hapticSound = HapticAndSoundManager.shared", states + "\n    private let hapticSound = HapticAndSoundManager.shared")

# 3. Add .autoScroll and .coordinateSpace to List, and capture preference key
# Find `List {` inside InboxView
list_start = content.find("List {\n")
list_end_idx = content.find(".listStyle(.plain)", list_start)
if list_end_idx != -1:
    list_modifiers = """
                        .listStyle(.plain)
                        .coordinateSpace(name: "InboxList")
                        .autoScroll(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown)
                        .onPreferenceChange(SectionBoundsKey.self) { bounds in
                            self.sectionBounds = bounds
                        }"""
    content = content[:list_end_idx] + list_modifiers + content[list_end_idx + len(".listStyle(.plain)"):]

# 4. Wrap Section Header with GeometryReader and PreferenceKey
section_target = """Section {
                                            HStack(spacing: 8) {"""
section_replacement = """Section {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color(cgColor: calendar.cgColor))
                                                    .frame(width: 8, height: 8)
                                                Text(calendar.title.uppercased())
                                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                                    .foregroundColor(Color(cgColor: calendar.cgColor).opacity(0.8))
                                                    .tracking(0.5)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 10)
                                            .padding(.top, 16)
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: SectionBoundsKey.self,
                                                        value: [calendar.calendarIdentifier: geo.frame(in: .named("InboxList"))]
                                                    )
                                                }
                                            )
                                            .listRowInsets(EdgeInsets())
                                            .background(
                                                Rectangle()
                                                    .fill(targetCalendarId == calendar.calendarIdentifier ? AppTheme.accent.opacity(0.2) : .ultraThinMaterial)
                                            )
                                            .contentShape(Rectangle())
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .onLongPressGesture {
                                                let calendars = eventKitManager.getCalendars()
                                                let sorted = calendarOrderManager.sort(calendars)
                                                reorderableCalendarIds = sorted.map { $0.calendarIdentifier }
                                                withAnimation {
                                                    isReorderingLists = true
                                                }
                                            }"""

# Use regex to replace the section header to inject GeometryReader
pattern = re.compile(r"Section \{\s*HStack\(spacing: 8\) \{\s*Circle\(\)\s*\.fill\(Color\(cgColor: calendar\.cgColor\)\)\s*\.frame\(width: 8, height: 8\)\s*Text\(calendar\.title\.uppercased\(\)\)\s*\.font\(\.system\(size: 13, weight: \.bold, design: \.rounded\)\)\s*\.foregroundColor\(Color\(cgColor: calendar\.cgColor\)\.opacity\(0\.8\)\)\s*\.tracking\(0\.5\)\s*Spacer\(\)\s*\}\s*\.padding\(\.horizontal, 16\)\s*\.padding\(\.bottom, 10\)\s*\.padding\(\.top, 16\)\s*\.listRowInsets\(EdgeInsets\(\)\)\s*\.background\(\s*Rectangle\(\)\s*\.fill\(\.ultraThinMaterial\)\s*\)\s*\.contentShape\(Rectangle\(\)\)\s*\.listRowBackground\(Color\.clear\)\s*\.listRowSeparator\(\.hidden\)\s*\.onLongPressGesture \{\s*let calendars = eventKitManager\.getCalendars\(\)\s*let sorted = calendarOrderManager\.sort\(calendars\)\s*reorderableCalendarIds = sorted\.map \{ \$0\.calendarIdentifier \}\s*withAnimation \{\s*isReorderingLists = true\s*\}\s*\}")
if pattern.search(content):
    content = pattern.sub(section_replacement, content)

# 5. Relocate addButton from top bar to bottom right overlay
# First, remove addButton from HStack
nav_bar_target = """                        addButton
                            .animation(.easeInOut, value: isMenuOpen)"""
content = content.replace(nav_bar_target, "")

# Then, append addButton at the end of the root ZStack
# The root ZStack ends around the `isMenuOpen` handling or alert modifiers.
# It ends with `.alert(isPresented: $viewModel.showingError)` usually.
overlay_addition = """        }
        .overlay(
            Group {
                if !isMenuOpen && !showingAddSheet {
                    addButton
                        .padding(.trailing, 24)
                        .padding(.bottom, 60)
                }
            },
            alignment: .bottomTrailing
        )"""
content = content.replace("        }", overlay_addition, 1) # Wait, replacing `        }` might be risky. Let's replace `.alert(isPresented: $viewModel.showingError)` instead.

alert_idx = content.find(".alert(isPresented: $viewModel.showingError) {")
if alert_idx != -1:
    end_of_alert = content.find("        }", alert_idx)
    overlay_str = """
        .overlay(
            Group {
                if !isMenuOpen {
                    addButton
                        .padding(.trailing, 24)
                        .padding(.bottom, 40)
                }
            },
            alignment: .bottomTrailing
        )"""
    content = content[:end_of_alert+9] + overlay_str + content[end_of_alert+9:]

with open('/Users/wilsonlee/Desktop/SimpleTaskV2/SimpleTaskV2/InboxView.swift', 'w') as f:
    f.write(content)


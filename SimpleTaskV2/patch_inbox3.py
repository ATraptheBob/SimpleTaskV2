import re

with open("InboxView.swift", "r") as f:
    content = f.read()

# 1. Add ScrollOffsetKey
offset_key = """
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
"""
content = re.sub(r'struct SectionBoundsKey:', offset_key + '\nstruct SectionBoundsKey:', content)

# 2. Remove showSearchBox block from VStack
search_box_regex = r'// Search Bar\s*if showSearchBox \{.*?\}\s*\.transition\(.*?\)\s*\}\n'
content = re.sub(search_box_regex, '', content, flags=re.DOTALL)

# 3. Add GeometryReader inside List
list_start = r'List \{\n\s*voiceTaskProcessingSection\(\)'
list_replacement = """List {
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ScrollOffsetKey.self,
                                    value: geo.frame(in: .named("InboxList")).minY
                                )
                            }
                            .frame(height: 0)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            
                            voiceTaskProcessingSection()"""
content = re.sub(list_start, list_replacement, content)

# 4. Update autoScroll and onPreferenceChange
autoscroll_regex = r'\.autoScroll\(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown\) \{ offset in.*?\}\n\s*\.onPreferenceChange'
autoscroll_replacement = """.autoScroll(isScrollingUp: isScrollingUp, isScrollingDown: isScrollingDown)
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
                        .onPreferenceChange"""
content = re.sub(autoscroll_regex, autoscroll_replacement, content, flags=re.DOTALL)

# 5. Add overlay
overlay_regex = r'if showingAddSheet \{.*?\n\s*\}\n\s*\.zIndex\(10\)\n\s*\}\n\s*\}'
overlay_replacement = """if showingAddSheet {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
                                showingAddSheet = false
                            }
                        }
                        .zIndex(9)
                        .transition(.opacity)
                    
                    VStack {
                        AddTaskView(isPresented: $showingAddSheet, initialCalendarIdentifier: droppedCalendarId)
                            .padding(.top, 60)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.01, anchor: .top)
                                            .combined(with: .opacity)
                                            .combined(with: .offset(y: -150)),
                                removal: .scale(scale: 0.6, anchor: .top)
                                            .combined(with: .opacity)
                                            .combined(with: .offset(y: -50))
                            ))
                        Spacer()
                    }
                    .zIndex(10)
                }
                
                if showSearchBox {
                    searchOverlay()
                }
            }"""
content = re.sub(overlay_regex, overlay_replacement, content, flags=re.DOTALL)

# 6. Define searchOverlay()
overlay_func = """
    @ViewBuilder
    private func searchOverlay() -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showSearchBox = false
                        searchText = ""
                        isSearchFocused = false
                    }
                }
                
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search tasks...", text: $searchText)
                        .focused($isSearchFocused)
                        .foregroundColor(isDarkMode ? .white : .black)
                        
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                    
                    Button("Cancel") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showSearchBox = false
                            searchText = ""
                            isSearchFocused = false
                        }
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding(.leading, 8)
                }
                .padding(14)
                .background(AppTheme.surface(.primary, isDark: isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                .neutralShadow(radius: 10, y: 5, opacity: 0.1)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                if !searchText.isEmpty {
                    List {
                        let matchingTasks = activeTasks
                        if matchingTasks.isEmpty {
                            Text("No tasks found")
                                .foregroundColor(.gray)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.top, 20)
                        } else {
                            ForEach(matchingTasks) { task in
                                taskRow(for: task)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                Spacer()
            }
        }
        .zIndex(15)
        .transition(.opacity)
    }
"""
# Insert before body
body_regex = r'\n\s*var body: some View \{'
content = re.sub(body_regex, overlay_func + '\n    var body: some View {', content)

with open("InboxView.swift", "w") as f:
    f.write(content)

print("Patch applied")

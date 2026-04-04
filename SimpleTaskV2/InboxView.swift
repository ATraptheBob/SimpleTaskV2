import SwiftUI
import SwiftData
import PhotosUI
import WidgetKit

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    @State private var selectedTask: TaskItem?
    
    private let hapticSound = HapticAndSoundManager.shared
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("leftSwipeAction") private var leftSwipeAction: SwipeOption = .edit
    @AppStorage("rightSwipeAction") private var rightSwipeAction: SwipeOption = .delete

    var activeTasks: [TaskItem] {
        let filtered = allTasks.filter { task in
            if !task.isCompleted { return true }
            if let completionDate = task.completionDate {
                return Date().timeIntervalSince(completionDate) < 86400
            }
            return false
        }
        return filtered.sorted { t1, t2 in
            if t1.isCompleted == t2.isCompleted { return t1.dueDate < t2.dueDate }
            return !t1.isCompleted
        }
    }
    
    // UPDATED: Only show habits scheduled for TODAY
    var dueHabits: [HabitItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        
        return allHabits.filter { habit in
            let isScheduledToday = habit.activeDays.contains(weekday)
            let isCompletedToday = habit.completionDates.contains { calendar.isDate($0, equalTo: today, toGranularity: .day) }
            return isScheduledToday && !isCompletedToday
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color.black : Color.white).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Spacer().frame(width: 44)
                        Text("Inbox")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? .white : .black)
                        Spacer()
                        Button(action: {
                            hapticSound.triggerHapticSelection()
                            showingAddSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.pink)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    
                    List {
                        if !dueHabits.isEmpty {
                            Section {
                                ForEach(dueHabits) { habit in
                                    HStack(spacing: 16) {
                                        Button(action: { toggleHabit(habit) }) {
                                            Image(systemName: "circle")
                                                .foregroundColor(.orange)
                                                .font(.system(size: 22, weight: .light))
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text(habit.title)
                                            .font(.system(size: 17, weight: .regular))
                                            .foregroundColor(isDarkMode ? .white : .black)
                                        
                                        Spacer()
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.visible)
                                    .listRowSeparatorTint(Color.gray.opacity(0.2))
                                    .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                }
                            } header: {
                                Text("DUE HABITS")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.orange.opacity(0.8))
                                    .padding(.leading, 4)
                            }
                        }
                        
                        Section {
                            ForEach(activeTasks) { task in
                                TaskRowView(task: task) {
                                    hapticSound.triggerHapticSelection()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        selectedTask = task
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.visible)
                                .listRowSeparatorTint(Color.gray.opacity(0.2))
                                .listRowInsets(EdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24))
                                .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                                
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if leftSwipeAction != .none {
                                        Button { handleTaskSwipe(option: leftSwipeAction, task: task) }
                                        label: { Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon) }
                                        .tint(leftSwipeAction.color)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if rightSwipeAction != .none {
                                        Button { handleTaskSwipe(option: rightSwipeAction, task: task) }
                                        label: { Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon) }
                                        .tint(rightSwipeAction.color)
                                    }
                                }
                            }
                        } header: {
                            Text("TASKS")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.pink.opacity(0.8))
                                .padding(.leading, 4)
                                .padding(.top, 16)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                // LAYER 2: MENU
                ZStack {
                    VStack {
                        HStack {
                            Circle()
                                .fill(isDarkMode ? Color(white: 0.12) : Color.white)
                                .frame(width: 44, height: 44)
                                .scaleEffect(isMenuOpen ? 50 : 0.001)
                                .opacity(isMenuOpen ? 1 : 0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        Spacer()
                    }
                    .ignoresSafeArea(.all, edges: .bottom)
                    
                    VStack(alignment: .center, spacing: 50) {
                        NavigationLink(destination: ArchiveView().toolbar(.hidden, for: .tabBar)) { MenuLink(title: "Archive", icon: "archivebox") }
                            .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                        NavigationLink(destination: StatsView().toolbar(.hidden, for: .tabBar)) { MenuLink(title: "Statistics", icon: "chart.bar") }
                            .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                        NavigationLink(destination: SettingsView().toolbar(.hidden, for: .tabBar)) { MenuLink(title: "Settings", icon: "gearshape") }
                            .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                    }
                    .opacity(isMenuOpen ? 1 : 0)
                    .scaleEffect(isMenuOpen ? 1 : 0.9)
                    .animation(.spring(response: 0.4, dampingFraction: 0.9), value: isMenuOpen)
                }
                .allowsHitTesting(isMenuOpen)
                
                VStack {
                    HStack {
                        HamburgerButton(isOpen: $isMenuOpen)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                
                // POPUP LAYERS
                if selectedTask != nil {
                    Color.black.opacity(0.6).ignoresSafeArea().transition(.opacity).onTapGesture { dismissPopup() }.zIndex(99)
                    
                    // FIXED: Removed ignoresSafeArea(.bottom) so the keyboard pushes this VStack upward!
                    VStack {
                        Spacer()
                        TaskDetailPopup(task: selectedTask!, isDarkMode: isDarkMode, dismissAction: dismissPopup)
                            .frame(maxHeight: 550)
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
            .toolbar(isMenuOpen || selectedTask != nil ? .hidden : .automatic, for: .tabBar)
            .sheet(isPresented: $showingAddSheet) { AddTaskView() }
        }
    }

    private func toggleHabit(_ habit: HabitItem) {
        withAnimation {
            habit.completionDates.append(Date())
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
        hapticSound.triggerHapticSuccess()
        hapticSound.playCompleteSound()
    }
    
    private func dismissPopup() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selectedTask = nil }
    }
    
    private func handleTaskSwipe(option: SwipeOption, task: TaskItem) {
        switch option {
        case .edit:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selectedTask = task }
        case .delete:
            modelContext.delete(task)
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        case .toggle:
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                task.isCompleted.toggle()
                task.completionDate = task.isCompleted ? Date() : nil
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
            if task.isCompleted { hapticSound.triggerHapticSuccess(); hapticSound.playCompleteSound() }
            else { hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound() }
        case .none: break
        }
    }
}

// ---------------------------------------------------------
// MINIMALIST TASK ROW
// ---------------------------------------------------------
struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @Bindable var task: TaskItem
    var onSelect: () -> Void
    private let hapticSound = HapticAndSoundManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    task.isCompleted.toggle()
                    task.completionDate = task.isCompleted ? Date() : nil
                    try? modelContext.save()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                if task.isCompleted { hapticSound.triggerHapticSuccess(); hapticSound.playCompleteSound() }
                else { hapticSound.triggerHapticSelection(); hapticSound.playSuccessSound() }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .gray : .pink)
                    .font(.system(size: 22, weight: .light))
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { onSelect() }) {
                    HStack {
                        Text(task.title).font(.system(size: 17, weight: .regular))
                            .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(task.isCompleted)
                        Spacer()
                        HStack(spacing: 8) {
                            if !task.notes.isEmpty { Image(systemName: "text.alignleft").font(.caption) }
                            if task.imageData != nil { Image(systemName: "photo").font(.caption) }
                        }
                        .foregroundColor(.gray.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if !task.subtasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(task.subtasks) { subtask in
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(subtask.isCompleted ? .gray.opacity(0.4) : .pink.opacity(0.5))
                                    .onTapGesture {
                                        hapticSound.triggerHapticSelection()
                                        withAnimation { subtask.isCompleted.toggle() }
                                        if subtask.isCompleted { hapticSound.playSuccessSound() }
                                        try? modelContext.save()
                                        WidgetCenter.shared.reloadAllTimelines()
                                    }
                                Text(subtask.title).font(.system(size: 14, weight: .regular))
                                    .foregroundColor(subtask.isCompleted ? .gray.opacity(0.4) : .gray)
                                    .strikethrough(subtask.isCompleted)
                                    .lineLimit(1)
                                    .onTapGesture { onSelect() }
                            }
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
            }
        }
        .opacity(task.isCompleted ? 0.5 : 1.0)
    }
}

// ---------------------------------------------------------
// POPUP AND MENU HELPERS (WITH CLICKABLE LINKS & KEYBOARD FIX)
// ---------------------------------------------------------
struct TaskDetailPopup: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    let isDarkMode: Bool
    var dismissAction: () -> Void
    
    @State private var newSubtaskTitle = ""
    @State private var selectedPhoto: PhotosPickerItem?
    
    // NEW: Toggles between Clickable Markdown and Editable TextField
    @State private var isEditingNotes = false
    @FocusState private var isNotesFocused: Bool
    
    private let hapticSound = HapticAndSoundManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                HStack {
                    Text(task.title).font(.headline).foregroundColor(isDarkMode ? .white : .black)
                    Spacer()
                    Button(action: dismissAction) {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture().onEnded { value in if value.translation.height > 40 { dismissAction() } })
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Steps").font(.caption).bold().foregroundColor(.gray)
                        ForEach(task.subtasks) { subtask in
                            HStack {
                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(subtask.isCompleted ? .green : .gray)
                                    .onTapGesture {
                                        hapticSound.triggerHapticSelection()
                                        withAnimation { subtask.isCompleted.toggle() }
                                        if subtask.isCompleted { hapticSound.playSuccessSound() }
                                        try? modelContext.save()
                                        WidgetCenter.shared.reloadAllTimelines()
                                    }
                                Text(subtask.title).strikethrough(subtask.isCompleted).foregroundColor(isDarkMode ? .white : .black)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "plus.circle").foregroundColor(.gray)
                            TextField("Add step...", text: $newSubtaskTitle)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .onSubmit {
                                    if !newSubtaskTitle.isEmpty {
                                        hapticSound.triggerHapticSuccess()
                                        withAnimation {
                                            task.subtasks.append(SubtaskItem(title: newSubtaskTitle))
                                            newSubtaskTitle = ""
                                            try? modelContext.save()
                                            WidgetCenter.shared.reloadAllTimelines()
                                        }
                                    }
                                }
                        }
                    }
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // UPDATED: Note Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notes").font(.caption).bold().foregroundColor(.gray)
                            Spacer()
                            if !isEditingNotes {
                                Button("Edit") { isEditingNotes = true; isNotesFocused = true }
                                    .font(.caption).bold().foregroundColor(.pink)
                            } else {
                                Button("Save") { isEditingNotes = false; isNotesFocused = false; try? modelContext.save() }
                                    .font(.caption).bold().foregroundColor(.pink)
                            }
                        }
                        
                        if isEditingNotes {
                            TextEditor(text: $task.notes)
                                .focused($isNotesFocused)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(isDarkMode ? Color(white: 0.08) : Color.white)
                                .cornerRadius(8)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .toolbar {
                                    ToolbarItemGroup(placement: .keyboard) {
                                        Spacer()
                                        Button("Done") { isEditingNotes = false; isNotesFocused = false; try? modelContext.save() }
                                            .foregroundColor(.pink)
                                    }
                                }
                        } else {
                            // Clickable Markdown mode! Will route links to your browser automatically.
                            Text(.init(task.notes.isEmpty ? "No notes. Tap Edit to add." : task.notes))
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .tint(.pink) // Colors links pink
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .environment(\.openURL, OpenURLAction { url in
                                    UIApplication.shared.open(url)
                                    return .handled
                                })
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attachment").font(.caption).bold().foregroundColor(.gray)
                        if let imageData = task.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable().scaledToFill().frame(maxWidth: .infinity).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        withAnimation { task.imageData = nil; try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() }
                                    } label: { Label("Remove Image", systemImage: "trash") }
                                }
                        }
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: task.imageData == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath.camera")
                                Text(task.imageData == nil ? "Attach Image" : "Change Image")
                            }
                            .font(.subheadline).bold().foregroundColor(.pink)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    await MainActor.run { withAnimation { task.imageData = data; try? modelContext.save(); WidgetCenter.shared.reloadAllTimelines() } }
                                }
                            }
                        }
                    }
                }
                .padding(20)
                Spacer().frame(height: 40)
            }
        }
        .background(isDarkMode ? Color(white: 0.15) : Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}

struct HamburgerButton: View {
    @Binding var isOpen: Bool
    @AppStorage("isDarkMode") private var isDarkMode = true
    var body: some View {
        Button(action: {
            HapticAndSoundManager.shared.triggerHapticSelection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { isOpen.toggle() }
        }) {
            VStack(spacing: 6) {
                Capsule().fill(isOpen ? Color.pink : (isDarkMode ? Color.gray : Color.black)).frame(width: 24, height: 3).rotationEffect(.degrees(isOpen ? 45 : 0)).offset(y: isOpen ? 9 : 0)
                Capsule().fill(isDarkMode ? Color.gray : Color.black).frame(width: 24, height: 3).opacity(isOpen ? 0 : 1)
                Capsule().fill(isOpen ? Color.pink : (isDarkMode ? Color.gray : Color.black)).frame(width: 24, height: 3).rotationEffect(.degrees(isOpen ? -45 : 0)).offset(y: isOpen ? -9 : 0)
            }
        }
        .frame(width: 44, height: 44, alignment: .leading)
    }
}

struct MenuLink: View {
    let title: String
    let icon: String
    @AppStorage("isDarkMode") private var isDarkMode = true
    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon).foregroundColor(.pink).font(.largeTitle).frame(width: 50)
            Text(title).foregroundColor(isDarkMode ? .white : .black).font(.system(size: 32, weight: .bold, design: .rounded))
        }
    }
}

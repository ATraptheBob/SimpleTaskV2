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
    
    // Preferences & Swipe Settings
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
        // In-memory sort: Incomplete first, then by date
        return filtered.sorted { t1, t2 in
            if t1.isCompleted == t2.isCompleted {
                return t1.dueDate < t2.dueDate
            }
            return !t1.isCompleted
        }
    }
    
    var dueHabits: [HabitItem] {
        allHabits.filter { !$0.isDone }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Spacer().frame(width: 44)
                        Spacer()
                        Text("Inbox").font(.title2).bold().foregroundColor(isDarkMode ? .white : .black)
                        Spacer()
                        Button(action: {
                            hapticSound.triggerHapticSelection()
                            showingAddSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.pink)
                                .padding(10)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    
                    List {
                        if !dueHabits.isEmpty {
                            Section(header: Text("Due Habits").foregroundColor(.orange)) {
                                ForEach(dueHabits) { habit in
                                    HStack(spacing: 12) {
                                        Button(action: { toggleHabit(habit) }) {
                                            Image(systemName: "circle")
                                                .foregroundColor(.orange)
                                                .font(.title2)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Text(habit.title)
                                            .foregroundColor(isDarkMode ? .white : .black)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                        
                        Section(header: Text("Tasks").foregroundColor(.pink)) {
                            ForEach(activeTasks) { task in
                                TaskRowView(task: task) {
                                    hapticSound.triggerHapticSelection()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        selectedTask = task
                                    }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                // THE SWIPE ACTIONS ARE NOW CORRECTLY ATTACHED HERE
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if leftSwipeAction != .none {
                                        Button {
                                            handleTaskSwipe(option: leftSwipeAction, task: task)
                                        } label: {
                                            Label(leftSwipeAction.rawValue, systemImage: leftSwipeAction.icon)
                                        }
                                        .tint(leftSwipeAction.color)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if rightSwipeAction != .none {
                                        Button {
                                            handleTaskSwipe(option: rightSwipeAction, task: task)
                                        } label: {
                                            Label(rightSwipeAction.rawValue, systemImage: rightSwipeAction.icon)
                                        }
                                        .tint(rightSwipeAction.color)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                // LAYER 2: THE GLITCH-FREE MENU
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
                
                if selectedTask != nil {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { dismissPopup() }
                        .zIndex(99)
                }
                
                if let task = selectedTask {
                    VStack {
                        Spacer()
                        
                        TaskDetailPopup(task: task, isDarkMode: isDarkMode, dismissAction: dismissPopup)
                            .frame(maxHeight: 550)
                    }
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationBarHidden(true)
            .toolbar(isMenuOpen || selectedTask != nil ? .hidden : .automatic, for: .tabBar)
            .sheet(isPresented: $showingAddSheet) { AddTaskView() }
        }
    }
    
    private func toggleHabit(_ habit: HabitItem) {
        hapticSound.triggerHapticSelection()
        hapticSound.playSuccessSound()
        withAnimation {
            habit.completionDates.append(Date())
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func dismissPopup() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedTask = nil
        }
    }
    
    // THIS FUNCTION IS NOW SAFELY INSIDE THE INBOXVIEW
    private func handleTaskSwipe(option: SwipeOption, task: TaskItem) {
        switch option {
        case .edit:
            // FIX: Removed showingAddSheet = true. Now it just smoothly opens the popup!
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selectedTask = task
            }
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
        case .none:
            break
        }
    }
    // ---------------------------------------------------------
    // TASK ROW & POPUP
    // ---------------------------------------------------------
    struct TaskRowView: View {
        @Environment(\.modelContext) private var modelContext
        @AppStorage("isDarkMode") private var isDarkMode = true
        
        @Bindable var task: TaskItem
        var onSelect: () -> Void
        private let hapticSound = HapticAndSoundManager.shared
        
        var body: some View {
            HStack(spacing: 12) {
                Button(action: {
                    hapticSound.triggerHapticSelection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        task.isCompleted.toggle()
                        task.completionDate = task.isCompleted ? Date() : nil
                        try? modelContext.save()
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                    
                    if task.isCompleted {
                        hapticSound.playCompleteSound()
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? .gray : .pink)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button(action: { onSelect() }) {
                    HStack {
                        Text(task.title)
                            .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                            .strikethrough(task.isCompleted)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            if !task.subtasks.isEmpty { Image(systemName: "checklist").font(.caption2) }
                            if !task.notes.isEmpty { Image(systemName: "text.alignleft").font(.caption2) }
                            if task.imageData != nil { Image(systemName: "photo").font(.caption2) }
                        }
                        .foregroundColor(.gray.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
        }
    }
    
    struct TaskDetailPopup: View {
        @Environment(\.modelContext) private var modelContext
        @Bindable var task: TaskItem
        let isDarkMode: Bool
        var dismissAction: () -> Void
        
        @State private var newSubtaskTitle = ""
        @State private var selectedPhoto: PhotosPickerItem?
        private let hapticSound = HapticAndSoundManager.shared
        
        var body: some View {
            VStack(spacing: 0) {
                
                // FIX: Wrapped the top bar in its own VStack to handle the swipe-down gesture
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
                .contentShape(Rectangle()) // Ensures tapping in the empty space works
                .gesture(
                    DragGesture().onEnded { value in
                        // If the user drags downward more than 40 pixels, dismiss it
                        if value.translation.height > 40 {
                            dismissAction()
                        }
                    }
                )
                
                ScrollView {
                    // ... The rest of your ScrollView code stays exactly the same ...
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
                                    Text(subtask.title)
                                        .strikethrough(subtask.isCompleted)
                                        .foregroundColor(isDarkMode ? .white : .black)
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
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes").font(.caption).bold().foregroundColor(.gray)
                            TextEditor(text: $task.notes)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(isDarkMode ? Color(white: 0.08) : Color.white)
                                .cornerRadius(8)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .onChange(of: task.notes) { _, _ in try? modelContext.save() }
                        }
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attachment").font(.caption).bold().foregroundColor(.gray)
                            if let imageData = task.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                task.imageData = nil
                                                try? modelContext.save()
                                                WidgetCenter.shared.reloadAllTimelines()
                                            }
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
                                        await MainActor.run {
                                            withAnimation {
                                                task.imageData = data
                                                try? modelContext.save()
                                                WidgetCenter.shared.reloadAllTimelines()
                                            }
                                        }
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
}

// ---------------------------------------------------------
// HELPERS
// ---------------------------------------------------------
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

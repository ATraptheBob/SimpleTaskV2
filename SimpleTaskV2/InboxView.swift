import SwiftUI
import SwiftData
import PhotosUI

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    @State private var selectedTask: TaskItem?
    
    private let hapticSound = HapticAndSoundManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = true

    var activeTasks: [TaskItem] {
        let filtered = allTasks.filter { !$0.isCompleted || ($0.completionDate != nil && Date().timeIntervalSince($0.completionDate!) < 86400) }
        return filtered.sorted { task1, task2 in
            if task1.isCompleted == task2.isCompleted { return task1.dueDate < task2.dueDate }
            return !task1.isCompleted && task2.isCompleted
        }
    }
    
    var dueHabits: [HabitItem] {
        allHabits.filter { !isHabitDone($0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // LAYER 0: THEME BACKGROUND
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                // LAYER 1: THE INBOX
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
                                    HStack {
                                        Text(habit.title).foregroundColor(isDarkMode ? .white : .black)
                                        Spacer()
                                        Image(systemName: "circle").foregroundColor(.orange)
                                            .onTapGesture { toggleHabit(habit) }
                                    }
                                    .listRowBackground(isDarkMode ? Color(white: 0.1) : Color.white)
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
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                // LAYER 2: THE PERFECTLY CENTERED BUBBLE MENU
                ZStack {
                    // FIX: This layout perfectly mirrors the Hamburger Button's layout, ensuring 100% alignment.
                    VStack {
                        HStack {
                            Circle()
                                .fill(isDarkMode ? Color(white: 0.12) : Color.white)
                                .frame(width: 44, height: 44) // Exact size of the button
                                .scaleEffect(isMenuOpen ? 50 : 0.001)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        Spacer()
                    }
                    .ignoresSafeArea(.all, edges: .bottom)
                    
                    if isMenuOpen {
                        VStack(alignment: .center, spacing: 50) {
                            NavigationLink(destination: ArchiveView()) { MenuLink(title: "Archive", icon: "archivebox") }
                                .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                            NavigationLink(destination: StatsView()) { MenuLink(title: "Statistics", icon: "chart.bar") }
                                .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                            
                            NavigationLink(destination: SettingsView()) { MenuLink(title: "Settings", icon: "gearshape") }
                                .simultaneousGesture(TapGesture().onEnded { isMenuOpen = false })
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2).delay(0.1)))
                    }
                }
                .allowsHitTesting(isMenuOpen)
                
                // LAYER 3: HAMBURGER BUTTON
                VStack {
                    HStack {
                        HamburgerButton(isOpen: $isMenuOpen)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                
                // LAYER 4: DARK FADE OVERLAY
                if selectedTask != nil {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { dismissPopup() }
                        .zIndex(99)
                }
                
                // LAYER 5: BOTTOM HALF SHEET POPUP
                if let task = selectedTask {
                    VStack {
                        Spacer() // Pushes the popup to the bottom half
                        
                        TaskDetailPopup(task: task, isDarkMode: isDarkMode, dismissAction: dismissPopup)
                            .frame(maxHeight: 550) // Limits height to roughly the bottom half
                    }
                    .transition(.move(edge: .bottom)) // Smooth slide up
                    .zIndex(100)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) { AddTaskView() }
        }
    }

    private func isHabitDone(_ habit: HabitItem) -> Bool {
        let cal = Calendar.current
        return habit.completionDates.contains { date in
            switch habit.frequency ?? .daily {
            case .daily: return cal.isDateInToday(date)
            case .weekly: return cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
            case .monthly: return cal.isDate(date, equalTo: Date(), toGranularity: .month)
            case .none: return false
            }
        }
    }

    private func toggleHabit(_ habit: HabitItem) {
        hapticSound.triggerHapticSelection()
        hapticSound.playSuccessSound()
        withAnimation {
            habit.completionDates.append(Date())
            try? modelContext.save()
        }
    }
    
    private func dismissPopup() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedTask = nil
        }
    }
}

// ---------------------------------------------------------
// TASK ROW
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
                }
                if task.isCompleted { hapticSound.playCompleteSound() }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
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
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}

// ---------------------------------------------------------
// THE NEW HALF-SHEET POPUP
// ---------------------------------------------------------
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
            // Sleek Apple-style Drag Handle
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Header
            HStack {
                Text(task.title).font(.headline).foregroundColor(isDarkMode ? .white : .black)
                Spacer()
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // 1. Subtasks
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
                                        }
                                    }
                                }
                        }
                    }
                    
                    Divider().background(Color.gray.opacity(0.3))
                    
                    // 2. Notes
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
                    
                    // 3. Image Attachment
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
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
                
                // Safe area padding for the bottom of the phone
                Spacer().frame(height: 40)
            }
        }
        .background(isDarkMode ? Color(white: 0.15) : Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 30))
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

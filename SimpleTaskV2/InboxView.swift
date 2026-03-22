import SwiftUI
import SwiftData
import PhotosUI // REQUIRED for image attachments

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.dueDate, order: .forward) private var allTasks: [TaskItem]
    @Query private var allHabits: [HabitItem]
    
    @State private var showingAddSheet = false
    @State private var isMenuOpen = false
    private let hapticSound = HapticAndSoundManager.shared
    
    // Listens for the theme toggle
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
                // THEME ADAPTATION: Swaps background color dynamically
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
                                TaskRowView(task: task)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color(white: 0.12) : Color.white)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isMenuOpen ? 45 : 0.001)
                        .position(x: 35, y: 30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isMenuOpen)
                        .ignoresSafeArea()
                    
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
                
                VStack {
                    HStack {
                        HamburgerButton(isOpen: $isMenuOpen)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    Spacer()
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
                Capsule()
                    .fill(isOpen ? Color.pink : (isDarkMode ? Color.gray : Color.black))
                    .frame(width: 24, height: 3)
                    .rotationEffect(.degrees(isOpen ? 45 : 0))
                    .offset(y: isOpen ? 9 : 0)
                
                Capsule()
                    .fill(isDarkMode ? Color.gray : Color.black)
                    .frame(width: 24, height: 3)
                    .opacity(isOpen ? 0 : 1)
                
                Capsule()
                    .fill(isOpen ? Color.pink : (isDarkMode ? Color.gray : Color.black))
                    .frame(width: 24, height: 3)
                    .rotationEffect(.degrees(isOpen ? -45 : 0))
                    .offset(y: isOpen ? -9 : 0)
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

// THE NEW TASK ROW WITH NOTES & IMAGES
struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @Bindable var task: TaskItem
    @State private var isExpanded = false
    @State private var newSubtaskTitle = ""
    @State private var selectedPhoto: PhotosPickerItem?
    
    private let hapticSound = HapticAndSoundManager.shared
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 16) {
                
                // 1. Subtasks
                VStack(alignment: .leading, spacing: 12) {
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
                                .font(.subheadline)
                                .strikethrough(subtask.isCompleted)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "plus.circle").foregroundColor(.gray)
                        TextField("New step...", text: $newSubtaskTitle)
                            .font(.subheadline)
                            .foregroundColor(isDarkMode ? .white : .black)
                            .onSubmit {
                                if !newSubtaskTitle.isEmpty {
                                    hapticSound.triggerHapticSuccess()
                                    hapticSound.playSuccessSound()
                                    withAnimation {
                                        task.subtasks.append(SubtaskItem(title: newSubtaskTitle))
                                        newSubtaskTitle = ""
                                        try? modelContext.save()
                                    }
                                }
                            }
                    }
                }
                .padding(.leading, 8)
                
                Divider().background(Color.gray.opacity(0.3))
                
                // 2. Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes").font(.caption).foregroundColor(.gray).bold()
                    TextField("Add context, links, or details...", text: $task.notes, axis: .vertical)
                        .font(.subheadline)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .onChange(of: task.notes) { _, _ in
                            try? modelContext.save() // Saves as you type
                        }
                }
                .padding(.leading, 8)
                
                // 3. Image Attachment Section
                VStack(alignment: .leading, spacing: 8) {
                    if let imageData = task.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        task.imageData = nil
                                        try? modelContext.save()
                                    }
                                } label: {
                                    Label("Remove Image", systemImage: "trash")
                                }
                            }
                    }
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        HStack {
                            Image(systemName: task.imageData == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath.camera")
                            Text(task.imageData == nil ? "Attach Image" : "Change Image")
                        }
                        .font(.caption)
                        .bold()
                        .foregroundColor(.pink)
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            // Converts the picked photo into Data for SwiftData
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
                .padding(.leading, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        } label: {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .foregroundColor(task.isCompleted ? .gray : .pink)
                    .font(.title3)
                    .onTapGesture {
                        hapticSound.triggerHapticSelection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            task.isCompleted.toggle()
                            task.completionDate = task.isCompleted ? Date() : nil
                            try? modelContext.save()
                        }
                        if task.isCompleted { hapticSound.playCompleteSound() }
                    }
                
                Text(task.title)
                    .foregroundColor(task.isCompleted ? .gray : (isDarkMode ? .white : .black))
                    .strikethrough(task.isCompleted)
                
                // Shows a tiny paperclip if an image is attached
                if task.imageData != nil {
                    Image(systemName: "paperclip").font(.caption).foregroundColor(.gray)
                }
            }
            .padding(.vertical, 8)
        }
        .tint(.gray)
    }
}

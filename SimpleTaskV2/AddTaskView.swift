import SwiftUI
import SwiftData
import PhotosUI

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool
    @FocusState private var isStepFocused: Bool
    
    @State private var title = ""
    @State private var dueDate = Date()
    @State private var repeatInterval: RepeatInterval = .none
    
    @State private var notes = ""
    @State private var newStepTitle = ""
    @State private var steps: [String] = []
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.08) : Color(white: 0.95)).ignoresSafeArea()
                
                Form {
                    Section(header: Text("Task Details").foregroundColor(.gray)) {
                        TextField("Task Title", text: $title)
                            .focused($isTitleFocused)
                            .foregroundColor(.green)
                        
                        DatePicker("Due Date", selection: $dueDate)
                            .foregroundColor(.blue)
                        
                        Picker("Repeat", selection: $repeatInterval) {
                            ForEach(RepeatInterval.allCases, id: \.self) { interval in
                                Text(interval.rawValue.capitalized).tag(interval)
                            }
                        }
                        .foregroundColor(.purple)
                    }
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                    
                    Section(header: Text("Notes").foregroundColor(.gray)) {
                        TextField("Add markdown notes...", text: $notes, axis: .vertical)
                            .focused($isNotesFocused)
                            .lineLimit(3...8)
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                    
                    Section(header: Text("Steps").foregroundColor(.gray)) {
                        ForEach(steps, id: \.self) { step in
                            Text(step)
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        .onDelete { indices in
                            steps.remove(atOffsets: indices)
                        }
                        
                        HStack {
                            TextField("Add a step...", text: $newStepTitle)
                                .focused($isStepFocused)
                                .onSubmit(addStep)
                            
                            Button(action: addStep) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(newStepTitle.isEmpty ? .gray : .pink)
                            }
                            .disabled(newStepTitle.isEmpty)
                        }
                    }
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                    
                    Section(header: Text("Attachment").foregroundColor(.gray)) {
                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                                .contextMenu {
                                    Button("Remove Image", role: .destructive) {
                                        withAnimation {
                                            selectedImageData = nil
                                            selectedPhotoItem = nil
                                        }
                                    }
                                }
                        }
                        
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(selectedImageData == nil ? "Attach Image" : "Change Image", systemImage: "photo")
                                .foregroundColor(.blue)
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    DispatchQueue.main.async {
                                        withAnimation {
                                            selectedImageData = data
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(isDarkMode ? Color(white: 0.12) : Color.white)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                isTitleFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { closeSheet() }
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticAndSoundManager.shared.triggerHapticSuccess()
                        
                        let task = TaskItem(
                            title: title,
                            dueDate: dueDate,
                            repeatInterval: repeatInterval,
                            notes: notes,
                            imageData: selectedImageData
                        )
                        
                        modelContext.insert(task)
                        
                        for stepTitle in steps {
                            let subtask = SubtaskItem(title: stepTitle)
                            task.subtasks.append(subtask)
                        }
                        
                        try? modelContext.save()
                        closeSheet()
                    }
                    .foregroundColor(.pink)
                    .disabled(title.isEmpty)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isTitleFocused = false
                        isNotesFocused = false
                        isStepFocused = false
                    }
                }
            }
        }
    }
    
    private func addStep() {
        let trimmed = newStepTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation {
            steps.append(trimmed)
            newStepTitle = ""
        }
    }
    
    private func closeSheet() {
        isTitleFocused = false
        isNotesFocused = false
        isStepFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        dismiss()
    }
}

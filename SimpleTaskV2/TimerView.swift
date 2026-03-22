import SwiftUI
import SwiftData
import Combine

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase // Detects if app is backgrounded
    
    @AppStorage("pomodoroDuration") private var sessionLength = 25
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    // PERSISTENT TIMER STATE
    @AppStorage("targetEndTime") private var targetEndTime: Double = 0
    @AppStorage("isTimerActive") private var timerRunning = false
    @AppStorage("timeRemaining") private var storedTimeRemaining = 25 * 60
    @AppStorage("currentFocus") private var selectedSubject = "AP Chemistry"
    
    // CUSTOM SUBJECTS
    @AppStorage("savedSubjects") private var savedSubjects = "AP Chemistry,AP Calculus,AP Physics,French,Coding,General"
    
    @State private var timeRemaining = 25 * 60
    @State private var showingAddSubject = false
    @State private var newSubject = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // Converts the saved string into a usable array
    var subjectsArray: [String] {
        savedSubjects.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    
                    // 1. THE TIMER RING
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 15)
                            .opacity(0.1)
                            .foregroundColor(.pink)
                        
                        Circle()
                            .trim(from: 0.0, to: CGFloat(timeRemaining) / CGFloat(sessionLength * 60))
                            .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.pink)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: timeRemaining)
                        
                        Text(timeString(time: timeRemaining))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    // 2. THE DYNAMIC SUBJECT SELECTOR
                    VStack(spacing: 12) {
                        Text("Current Focus").font(.caption).bold().foregroundColor(.gray)
                        
                        ZStack {
                            if timerRunning {
                                // THE BUBBLE-OUT STATE (Focus Mode)
                                Text(selectedSubject)
                                    .font(.title2).bold()
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 15)
                                    .background(Color.pink)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                    .shadow(color: .pink.opacity(0.4), radius: 15, y: 5)
                                    .scaleEffect(1.1)
                                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                                    .zIndex(1)
                            } else {
                                // THE SELECTOR STATE (Menu Mode)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        Spacer().frame(width: 20)
                                        ForEach(subjectsArray, id: \.self) { subject in
                                            Text(subject)
                                                .font(.subheadline).bold()
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(selectedSubject == subject ? Color.pink : (isDarkMode ? Color(white: 0.15) : Color.white))
                                                .foregroundColor(selectedSubject == subject ? .white : (isDarkMode ? .gray : .black))
                                                .clipShape(Capsule())
                                                .shadow(color: .black.opacity(isDarkMode ? 0 : 0.05), radius: 5, y: 2)
                                                .onTapGesture {
                                                    HapticAndSoundManager.shared.triggerHapticSelection()
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                        selectedSubject = subject
                                                    }
                                                }
                                        }
                                        
                                        // The "Add Custom" Button
                                        Button(action: { showingAddSubject = true }) {
                                            Image(systemName: "plus")
                                                .font(.subheadline).bold()
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(isDarkMode ? Color(white: 0.15) : Color.white)
                                                .foregroundColor(.gray)
                                                .clipShape(Capsule())
                                                .shadow(color: .black.opacity(isDarkMode ? 0 : 0.05), radius: 5, y: 2)
                                        }
                                        Spacer().frame(width: 20)
                                    }
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .frame(height: 80) // Locks the height so the controls don't jump around
                    
                    // 3. THE CONTROLS
                    HStack(spacing: 30) {
                        Button(action: resetTimer) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                                .opacity(timerRunning ? 0.5 : 1.0)
                        }
                        .disabled(timerRunning) // Disables reset while running
                        
                        Button(action: toggleTimer) {
                            Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.pink)
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Focus")
            
            // BACKGROUND SYNC LOGIC
            .onAppear(perform: syncTimer)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { syncTimer() }
            }
            .onReceive(timer) { _ in
                if timerRunning {
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                        storedTimeRemaining = timeRemaining
                    } else {
                        finishSession()
                    }
                }
            }
            
            // CUSTOM SUBJECT POPUP
            .alert("New Focus Subject", isPresented: $showingAddSubject) {
                TextField("E.g., SAT Prep, Reading", text: $newSubject)
                Button("Cancel", role: .cancel) { newSubject = "" }
                Button("Add") {
                    if !newSubject.isEmpty {
                        savedSubjects += ",\(newSubject)"
                        selectedSubject = newSubject
                        newSubject = ""
                    }
                }
            }
        }
    }
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // -------------------------
    // ENGINE LOGIC
    // -------------------------
    
    // Syncs the timer when you reopen the app or switch tabs
    private func syncTimer() {
        if timerRunning {
            let remainingSeconds = targetEndTime - Date().timeIntervalSince1970
            if remainingSeconds > 0 {
                timeRemaining = Int(remainingSeconds)
            } else {
                finishSession() // Timer finished while you were gone
            }
        } else {
            timeRemaining = storedTimeRemaining == 0 ? sessionLength * 60 : storedTimeRemaining
        }
    }
    
    private func toggleTimer() {
        HapticAndSoundManager.shared.triggerHapticSelection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            timerRunning.toggle()
        }
        
        if timerRunning {
            // Calculates the exact real-world time the timer should end
            targetEndTime = Date().timeIntervalSince1970 + Double(timeRemaining)
        } else {
            // Pauses the timer and saves the remaining chunk
            storedTimeRemaining = timeRemaining
            targetEndTime = 0
        }
    }
    
    private func resetTimer() {
        withAnimation { timerRunning = false }
        timeRemaining = sessionLength * 60
        storedTimeRemaining = timeRemaining
        targetEndTime = 0
    }
    
    private func finishSession() {
        withAnimation { timerRunning = false }
        HapticAndSoundManager.shared.playCompleteSound()
        
        let session = PomodoroSession(durationMinutes: sessionLength, subject: selectedSubject)
        modelContext.insert(session)
        try? modelContext.save()
        
        resetTimer()
    }
}

import SwiftUI
import SwiftData
import Combine

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("pomodoroDuration") private var sessionLength = 1
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @AppStorage("targetEndTime") private var targetEndTime: Double = 0
    @AppStorage("isTimerActive") private var timerRunning = false
    @AppStorage("timeRemaining") private var storedTimeRemaining = 25 * 60
    @AppStorage("currentFocus") private var selectedSubject = "AP Chemistry"
    
    @AppStorage("savedSubjects") private var savedSubjects = "AP Chemistry,AP Calculus,AP Physics,French,Coding,General"
    
    @State private var timeRemaining = 25 * 60
    @State private var showingAddSubject = false
    @State private var newSubject = ""
    
    // FIX: This toggle prevents the "fly-in from top left" glitch
    @State private var isReadyToAnimate = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var subjectsArray: [String] {
        savedSubjects.components(separatedBy: ",").filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    
                    ZStack {
                        Circle()
                            .stroke(lineWidth: 15)
                            .opacity(0.1)
                            .foregroundColor(.pink)
                        
                        Circle()
                            .trim(from: 0.0, to: sessionLength > 0 ? CGFloat(timeRemaining) / CGFloat(sessionLength * 60) : 0)
                            .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.pink)
                            .rotationEffect(Angle(degrees: 270.0))
                            // FIX: Only applies the animation AFTER the initial layout is complete
                            .animation(isReadyToAnimate ? .linear(duration: 1.0) : .none, value: timeRemaining)
                        
                        Text(timeString(time: timeRemaining))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    VStack(spacing: 12) {
                        Text("Current Focus").font(.caption).bold().foregroundColor(.gray)
                        
                        ZStack {
                            if timerRunning {
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
                    .frame(height: 80)
                    
                    VStack(spacing: 25) {
                        HStack(spacing: 30) {
                            Button(action: resetTimer) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.gray)
                                    .opacity(timerRunning ? 0.5 : 1.0)
                            }
                            .disabled(timerRunning)
                            
                            Button(action: toggleTimer) {
                                Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundColor(.pink)
                            }
                        }
                        
                        if timeRemaining < sessionLength * 60 {
                            Button(action: endSessionEarly) {
                                Text("End Session")
                                    .font(.subheadline).bold()
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .transition(.opacity)
                        }
                    }
                    Spacer()
                }
            }
            .navigationTitle("Focus")
            .onAppear {
                syncTimer()
                // FIX: Waits 0.1 seconds for the view to physically snap into place before allowing animations
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isReadyToAnimate = true
                }
            }
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
            .alert("New Focus Subject", isPresented: $showingAddSubject) {
                TextField("E.g., SAT Prep, Reading", text: $newSubject)
                Button("Cancel", role: .cancel) { newSubject = "" }
                Button("Add") {
                    let trimmed = newSubject.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let currentSubjects = savedSubjects.components(separatedBy: ",")
                        if !currentSubjects.contains(trimmed) {
                            savedSubjects += ",\(trimmed)"
                            selectedSubject = trimmed
                        }
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
    
    private func syncTimer() {
        if timerRunning {
            let remainingSeconds = targetEndTime - Date().timeIntervalSince1970
            if remainingSeconds > 0 {
                timeRemaining = Int(ceil(remainingSeconds))
            } else {
                finishSession()
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
                targetEndTime = Date().timeIntervalSince1970 + Double(timeRemaining)
                // NEW: Schedule the notification!
                NotificationManager.shared.scheduleTimerNotification(durationInSeconds: Double(timeRemaining))
            } else {
                storedTimeRemaining = timeRemaining
                targetEndTime = 0
                // NEW: Cancel the notification because we paused
                NotificationManager.shared.cancelTimerNotification()
            }
        }
    
    private func resetTimer() {
            withAnimation { timerRunning = false }
            timeRemaining = sessionLength * 60
            storedTimeRemaining = timeRemaining
            targetEndTime = 0
            // NEW: Cancel notification
            NotificationManager.shared.cancelTimerNotification()
        }
    
    private func endSessionEarly() {
            HapticAndSoundManager.shared.triggerHapticSelection()
            let elapsedMinutes = sessionLength - (timeRemaining / 60)
            
            if elapsedMinutes > 0 {
                let session = PomodoroSession(durationMinutes: elapsedMinutes, subject: selectedSubject)
                modelContext.insert(session)
                try? modelContext.save()
            }
            // NEW: Cancel notification
            NotificationManager.shared.cancelTimerNotification()
            resetTimer()
        }
    
    private func finishSession() {
        HapticAndSoundManager.shared.playCompleteSound()
        let session = PomodoroSession(durationMinutes: sessionLength, subject: selectedSubject)
        modelContext.insert(session)
        try? modelContext.save()
        resetTimer()
    }
}

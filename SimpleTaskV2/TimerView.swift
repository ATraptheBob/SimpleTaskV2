import SwiftUI
import SwiftData
internal import Combine

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    // Preferences
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("pomodoroDuration") private var sessionLength = 25
    @AppStorage("breakDuration") private var breakDuration = 5
    
    // Timer State
    @State private var timeRemaining: Int = 1500
    @State private var timerRunning = false
    @State private var isBreakMode = false
    @State private var selectedSubject = "Focus"
    
    // Persistence for backgrounding
    @AppStorage("targetEndTime") private var targetEndTime: Double = 0
    @AppStorage("storedTimeRemaining") private var storedTimeRemaining: Int = 1500
    
    let subjects = ["Focus", "Coding", "Reading", "Math", "Writing", "Design"]
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UI Helpers
    var activeColor: Color { isBreakMode ? .green : .pink }
    
    var progress: CGFloat {
        let total = isBreakMode ? (breakDuration * 60) : (sessionLength * 60)
        guard total > 0 else { return 0 }
        return CGFloat(timeRemaining) / CGFloat(total)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (isDarkMode ? Color(white: 0.05) : Color(white: 0.95)).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    
                    // Header
                    HStack {
                        Text(isBreakMode ? "Take a Break" : "Focus Session")
                            .font(.title2).bold()
                            .foregroundColor(activeColor)
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    
                    // Subject Picker (Hidden during breaks)
                    if !isBreakMode {
                        Menu {
                            ForEach(subjects, id: \.self) { subject in
                                Button(subject) { selectedSubject = subject }
                            }
                        } label: {
                            HStack {
                                Text(selectedSubject)
                                Image(systemName: "chevron.up.chevron.down").font(.caption)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(activeColor.opacity(0.15))
                            .foregroundColor(activeColor)
                            .clipShape(Capsule())
                        }
                        .disabled(timerRunning)
                        .opacity(timerRunning ? 0.5 : 1.0)
                    } else {
                        // Spacer to keep the circle vertically aligned when picker is hidden
                        Spacer().frame(height: 40)
                    }
                    
                    // The Timer Circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(activeColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: progress)
                        
                        VStack(spacing: 8) {
                            Text(timeString(from: timeRemaining))
                                .font(.system(size: 65, weight: .bold, design: .rounded))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .contentTransition(.numericText())
                            
                            Text(isBreakMode ? "Relaxing..." : "Remaining")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 280, height: 280)
                    .padding(.vertical, 20)
                    
                    // Controls
                    HStack(spacing: 40) {
                        Button(action: toggleTimer) {
                            Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(activeColor)
                                .clipShape(Circle())
                                .shadow(color: activeColor.opacity(0.4), radius: 10, y: 5)
                        }
                        
                        Button(action: isBreakMode ? resetTimer : endSessionEarly) {
                            Image(systemName: isBreakMode ? "forward.end.fill" : "stop.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                                .frame(width: 80, height: 80)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .disabled(timeRemaining == (isBreakMode ? breakDuration * 60 : sessionLength * 60))
                        .opacity(timeRemaining == (isBreakMode ? breakDuration * 60 : sessionLength * 60) ? 0.5 : 1.0)
                    }
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .onAppear {
            calculateBackgroundTime()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { calculateBackgroundTime() }
        }
        .onReceive(timer) { _ in
            if timerRunning {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    handleTimerCompletion()
                }
            }
        }
    }
    
    // ---------------------------------------------------------
    // TIMER ENGINE
    // ---------------------------------------------------------
    
    private func handleTimerCompletion() {
        HapticAndSoundManager.shared.playSuccessSound()
        
        if !isBreakMode {
            // POMODORO FINISHED -> START BREAK
            let session = PomodoroSession(durationMinutes: sessionLength, subject: selectedSubject)
            modelContext.insert(session)
            try? modelContext.save()
            
            withAnimation(.spring()) {
                isBreakMode = true
                timeRemaining = breakDuration * 60
                targetEndTime = Date().timeIntervalSince1970 + Double(timeRemaining)
                timerRunning = true
            }
            
            NotificationManager.shared.scheduleBreakNotification(durationInSeconds: Double(timeRemaining))
            
        } else {
            // BREAK FINISHED -> RESET TO POMODORO
            withAnimation(.spring()) {
                isBreakMode = false
                timerRunning = false
                timeRemaining = sessionLength * 60
                targetEndTime = 0
            }
        }
    }

    private func toggleTimer() {
        HapticAndSoundManager.shared.triggerHapticSelection()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            timerRunning.toggle()
        }
        
        if timerRunning {
            targetEndTime = Date().timeIntervalSince1970 + Double(timeRemaining)
            
            if isBreakMode {
                NotificationManager.shared.scheduleBreakNotification(durationInSeconds: Double(timeRemaining))
            } else {
                NotificationManager.shared.scheduleTimerNotification(durationInSeconds: Double(timeRemaining))
            }
        } else {
            storedTimeRemaining = timeRemaining
            targetEndTime = 0
            
            NotificationManager.shared.cancelTimerNotification()
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["break_timer_complete"])
        }
    }

    private func resetTimer() {
        HapticAndSoundManager.shared.triggerHapticSelection()
        withAnimation { timerRunning = false }
        
        timeRemaining = isBreakMode ? (breakDuration * 60) : (sessionLength * 60)
        storedTimeRemaining = timeRemaining
        targetEndTime = 0
        
        NotificationManager.shared.cancelTimerNotification()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["break_timer_complete"])
    }

    private func endSessionEarly() {
        HapticAndSoundManager.shared.triggerHapticSelection()
        let elapsedMinutes = sessionLength - (timeRemaining / 60)
        
        if elapsedMinutes > 0 && !isBreakMode {
            let session = PomodoroSession(durationMinutes: elapsedMinutes, subject: selectedSubject)
            modelContext.insert(session)
            try? modelContext.save()
        }
        
        isBreakMode = false
        resetTimer()
    }

    private func calculateBackgroundTime() {
        if targetEndTime > 0 {
            let currentTime = Date().timeIntervalSince1970
            let difference = targetEndTime - currentTime
            
            if difference > 0 {
                timeRemaining = Int(difference)
                timerRunning = true
            } else {
                // Timer finished while app was closed
                timeRemaining = 0
                timerRunning = false
                targetEndTime = 0
                handleTimerCompletion()
            }
        } else if storedTimeRemaining > 0 {
            timeRemaining = storedTimeRemaining
            if timeRemaining > (isBreakMode ? breakDuration * 60 : sessionLength * 60) {
                timeRemaining = isBreakMode ? breakDuration * 60 : sessionLength * 60
            }
        } else {
            timeRemaining = isBreakMode ? breakDuration * 60 : sessionLength * 60
        }
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

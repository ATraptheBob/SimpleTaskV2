import SwiftUI
import SwiftData
import Combine

struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("pomodoroDuration") private var sessionLength = 25
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var timeRemaining = 25 * 60
    @State private var timerRunning = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                            .trim(from: 0.0, to: CGFloat(timeRemaining) / CGFloat(sessionLength * 60))
                            .stroke(style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.pink)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: timeRemaining)
                        
                        Text(timeString(time: timeRemaining))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .padding(40)
                    
                    HStack(spacing: 30) {
                        Button(action: resetTimer) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {
                            HapticAndSoundManager.shared.triggerHapticSelection()
                            timerRunning.toggle()
                        }) {
                            Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.pink)
                        }
                    }
                }
            }
            .navigationTitle("Focus")
            .onAppear { resetTimer() }
            .onReceive(timer) { _ in
                if timerRunning && timeRemaining > 0 {
                    timeRemaining -= 1
                } else if timerRunning && timeRemaining == 0 {
                    finishSession()
                }
            }
        }
    }
    
    private func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func resetTimer() {
        timerRunning = false
        timeRemaining = sessionLength * 60
    }
    
    private func finishSession() {
        timerRunning = false
        HapticAndSoundManager.shared.playCompleteSound()
        let session = PomodoroSession(durationMinutes: sessionLength)
        modelContext.insert(session)
        try? modelContext.save()
        resetTimer()
    }
}

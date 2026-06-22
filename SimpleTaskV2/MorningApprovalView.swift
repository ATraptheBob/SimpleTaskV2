import SwiftUI

struct MorningApprovalView: View {
    let briefing: MorningBriefing
    @Binding var isPresented: Bool
    
    @State private var currentIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    
    @StateObject private var eventKitManager = EventKitManager.shared
    
    // Aesthetic Preferences
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    
    var body: some View {
        ZStack {
            // Background
            (isDarkMode ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Text("Morning Briefing")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : .black)
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .accessibilityLabel("Close")
                }
                .padding()
                
                Text(briefing.aiMessage)
                    .font(.body)
                    .italic()
                    .foregroundColor(isDarkMode ? .gray : .secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                
                // Cards Area
                ZStack {
                    if currentIndex < briefing.suggestedTasks.count {
                        ForEach(currentIndex..<briefing.suggestedTasks.count, id: \.self) { index in
                            let task = briefing.suggestedTasks[index]
                            let isTopCard = index == currentIndex
                            
                            CardView(
                                task: task,
                                isDarkMode: isDarkMode
                            )
                            .zIndex(Double(briefing.suggestedTasks.count - index))
                            .offset(x: isTopCard ? cardOffset.width : 0, y: isTopCard ? cardOffset.height : 0)
                            .rotationEffect(.degrees(isTopCard ? Double(cardOffset.width / 20) : 0))
                            .scaleEffect(isTopCard ? 1.0 : 0.95 - CGFloat(index - currentIndex) * 0.05)
                            .opacity(isTopCard ? 1.0 : 1.0 - Double(index - currentIndex) * 0.2)
                            .gesture(isTopCard ? dragGesture(for: task) : nil)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: cardOffset)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.accent)
                            Text("All caught up!")
                                .font(.title2.bold())
                                .foregroundColor(isDarkMode ? .white : .black)
                            Button("Close") {
                                isPresented = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        }
                        .transition(.opacity)
                    }
                }
                .frame(maxHeight: 400)
                .padding()
                
                Spacer()
                
                // Hints
                if currentIndex < briefing.suggestedTasks.count {
                    HStack {
                        VStack {
                            Image(systemName: "arrow.left")
                            Text("Skip")
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                        
                        VStack {
                            Image(systemName: "arrow.right")
                            Text("Approve")
                        }
                        .foregroundColor(.green)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    private func dragGesture(for task: SuggestedTask) -> some Gesture {
        DragGesture()
            .onChanged { value in
                cardOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if value.translation.width > threshold {
                    // Swipe Right: Approve
                    approveTask(task)
                    swipeCard(to: .right)
                } else if value.translation.width < -threshold {
                    // Swipe Left: Reject
                    if enableHaptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    swipeCard(to: .left)
                } else {
                    // Snap back
                    cardOffset = .zero
                }
            }
    }
    
    private func swipeCard(to direction: SwipeDirection) {
        let width: CGFloat = 500
        cardOffset = CGSize(width: direction == .right ? width : -width, height: 0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentIndex += 1
            cardOffset = .zero
        }
    }
    
    private func approveTask(_ task: SuggestedTask) {
        if enableHaptics {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        
        // Add to EventKit
        _ = try? eventKitManager.addTask(
            title: task.title,
            notes: task.reason + "\n\n<!-- {\"duration\": \"\(task.durationMinutes)m\"} -->",
            dueDate: Calendar.current.startOfDay(for: Date())
        )
    }
    
    private enum SwipeDirection {
        case left, right
    }
}

fileprivate struct CardView: View {
    let task: SuggestedTask
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task.title)
                .font(.title2.bold())
                .foregroundColor(isDarkMode ? .white : .black)
            
            HStack {
                Image(systemName: "clock")
                Text("\(task.durationMinutes) min")
            }
            .font(.subheadline)
            .foregroundColor(AppTheme.accent)
            
            Text(task.reason)
                .font(.body)
                .foregroundColor(isDarkMode ? .gray : .secondary)
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
        .cornerRadius(20)
        .neutralShadow(radius: 8, y: 4, opacity: 0.15)
    }
}

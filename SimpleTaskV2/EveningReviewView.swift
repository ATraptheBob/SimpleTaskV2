import SwiftUI
import EventKit

struct EveningReviewView: View {
    @Binding var isPresented: Bool
    var briefing: EveningBriefing
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("enableHaptics") private var enableHaptics = true
    
    @State private var currentIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            (isDarkMode ? Color.black : Color.white).ignoresSafeArea()
            
            VStack {
                HStack {
                    Text("Evening Reflection")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : .black)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .accessibilityLabel("Close")
                }
                .padding()
                
                // Hero Stats
                HStack(spacing: 30) {
                    VStack {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                                .frame(width: 80, height: 80)
                            Circle()
                                .trim(from: 0, to: CGFloat(briefing.productivityScore) / 10.0)
                                .stroke(AppTheme.matteSlate, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            Text("\(briefing.productivityScore)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("\(briefing.completedCount) Tasks Done")
                                .font(.headline)
                        }
                        Text(briefing.summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding()
                .background(AppTheme.surface(.primary, isDark: isDarkMode))
                .cornerRadius(16)
                .padding(.horizontal)
                
                Spacer().frame(height: 20)
                
                Text("Tomorrow's Prep")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                ZStack {
                    if currentIndex < briefing.tomorrowSuggestions.count {
                        ForEach(Array(briefing.tomorrowSuggestions.enumerated().reversed()), id: \.element.title) { index, task in
                            if index >= currentIndex {
                                let offsetIndex = index - currentIndex
                                let isTop = offsetIndex == 0
                                
                                EveningCardView(task: task, isDarkMode: isDarkMode)
                                    .offset(x: isTop ? cardOffset.width : 0, y: isTop ? cardOffset.height : CGFloat(offsetIndex * 10))
                                    .scaleEffect(isTop ? 1.0 : max(1.0 - CGFloat(offsetIndex) * 0.05, 0.8))
                                    .rotationEffect(.degrees(isTop ? Double(cardOffset.width / 20) : 0))
                                    .zIndex(Double(-offsetIndex))
                                    .gesture(
                                        DragGesture()
                                            .onChanged { gesture in
                                                if isTop { cardOffset = gesture.translation }
                                            }
                                            .onEnded { gesture in
                                                if isTop { handleSwipe(gesture: gesture, task: task) }
                                            }
                                    )
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: cardOffset)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "moon.zzz.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.matteSlate)
                            Text("All set for tomorrow!")
                                .font(.title2.bold())
                                .foregroundColor(isDarkMode ? .white : .black)
                            Button(action: { isPresented = false }) {
                                Text("Goodnight")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.matteSlate)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .padding(.horizontal, 20)
                
                Spacer()
                
                if currentIndex < briefing.tomorrowSuggestions.count {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Skip")
                        Spacer()
                        Text("Schedule")
                        Image(systemName: "arrow.right")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    private func handleSwipe(gesture: DragGesture.Value, task: SuggestedTask) {
        let threshold: CGFloat = 100
        if gesture.translation.width > threshold {
            // Right swipe - Add task for tomorrow
            if enableHaptics {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
            let notes = "\(task.reason)\n\n<!-- {\"duration\": \"\(task.durationMinutes)m\"} -->"
            _ = try? EventKitManager.shared.addTask(title: task.title, notes: notes, dueDate: tomorrow)
            
            withAnimation(.spring()) {
                cardOffset.width = 500
            }
            nextCard()
        } else if gesture.translation.width < -threshold {
            // Left swipe - Skip
            if enableHaptics {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            withAnimation(.spring()) {
                cardOffset.width = -500
            }
            nextCard()
        } else {
            // Return to center
            withAnimation(.spring()) {
                cardOffset = .zero
            }
        }
    }
    
    private func nextCard() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cardOffset = .zero
            currentIndex += 1
        }
    }
}

fileprivate struct EveningCardView: View {
    let task: SuggestedTask
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task.title)
                .font(.title2.bold())
                .foregroundColor(isDarkMode ? .white : .black)
                .multilineTextAlignment(.leading)
            
            HStack {
                Image(systemName: "clock.fill")
                Text("\(task.durationMinutes) min")
            }
            .font(.subheadline.bold())
            .foregroundColor(AppTheme.matteSlate)
            
            Text(task.reason)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: 300, alignment: .topLeading)
        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
        .cornerRadius(20)
        .neutralShadow(radius: 8, y: 4, opacity: 0.15)
    }
}

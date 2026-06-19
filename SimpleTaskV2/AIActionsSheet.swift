import SwiftUI

struct AIActionsSheet: View {
    @Binding var isPresented: Bool
    var onMorningBrief: () -> Void
    var onEveningBrief: () -> Void
    var onLabelImportance: () -> Void
    var onPredictDuration: () -> Void
    var onPlanMyDay: () -> Void
    var onQuickCapture: () -> Void
    var onSmartContext: () -> Void
    var onAutoReschedule: () -> Void
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var apiKey: String = ""
    
    var body: some View {
        ZStack {
            // Glassmorphism background
            if isDarkMode {
                Color.black.opacity(0.4).ignoresSafeArea()
            } else {
                Color.white.opacity(0.8).ignoresSafeArea()
            }
            
            VStack(spacing: 20) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                Text("AI Actions")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .padding(.bottom, 10)
                
                if apiKey.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Gemini API Key Missing")
                            .font(.headline)
                        Text("Add your API key in Settings to use these features.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(white: isDarkMode ? 0.15 : 0.95))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                
                ScrollView {
                    VStack(spacing: 12) {
                        AIActionCard(
                            icon: "sun.max.fill",
                            title: "Morning Brief",
                            subtitle: "Plan your day based on your schedule",
                            color: .orange,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onMorningBrief) }
                        )
                        
                        AIActionCard(
                            icon: "moon.stars.fill",
                            title: "Evening Brief",
                            subtitle: "Reflect on today and prep for tomorrow",
                            color: .indigo,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onEveningBrief) }
                        )
                        
                        AIActionCard(
                            icon: "location.magnifyingglass",
                            title: "Smart Contexts",
                            subtitle: "AI assigns times based on task context",
                            color: .teal,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onSmartContext) }
                        )
                        
                        AIActionCard(
                            icon: "arrow.uturn.right.circle.fill",
                            title: "Reschedule Overdue",
                            subtitle: "AI optimally reschedules missed tasks",
                            color: .pink,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onAutoReschedule) }
                        )
                        
                        AIActionCard(
                            icon: "tag.fill",
                            title: "Label Importance",
                            subtitle: "AI assigns High/Medium/Low priority to tasks",
                            color: .red,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onLabelImportance) }
                        )
                        
                        AIActionCard(
                            icon: "clock.badge.questionmark",
                            title: "Predict Durations",
                            subtitle: "AI estimates time required for pending tasks",
                            color: .blue,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onPredictDuration) }
                        )
                        
                        AIActionCard(
                            icon: "calendar.badge.clock",
                            title: "Plan My Day",
                            subtitle: "AI assigns optimal times to your tasks",
                            color: .purple,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onPlanMyDay) }
                        )
                        
                        AIActionCard(
                            icon: "text.bubble.fill",
                            title: "Quick Capture",
                            subtitle: "Type natural language to create tasks",
                            color: .green,
                            disabled: apiKey.isEmpty,
                            action: { dismissAndRun(onQuickCapture) }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            apiKey = KeychainManager.shared.get(key: "geminiApiKey") ?? ""
        }
    }
    
    private func dismissAndRun(_ action: @escaping () -> Void) {
        isPresented = false
        // Small delay to allow sheet to dismiss before starting heavy work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }
}

struct AIActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let disabled: Bool
    let action: () -> Void
    
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundColor(Color(white: 0.5))
            }
            .padding()
            .background(Color(white: isDarkMode ? 0.15 : 0.95))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1.0)
    }
}

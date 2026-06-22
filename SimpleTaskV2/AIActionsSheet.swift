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
    @State private var apiKey: String = KeychainManager.shared.getApiKey()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AI Actions")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.top, 24)
            
            if apiKey.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.matteAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("API Key Missing")
                            .font(.subheadline.bold())
                            .foregroundColor(isDarkMode ? .white : .black)
                        Text("Add your Gemini key in Settings.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(14)
                .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
                .padding(.horizontal)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                AIGridTile(icon: "sun.max.fill", label: "Morning", color: AppTheme.matteAmber, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onMorningBrief) }
                AIGridTile(icon: "moon.stars.fill", label: "Evening", color: AppTheme.matteSlate, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onEveningBrief) }
                AIGridTile(icon: "tag.fill", label: "Priority", color: AppTheme.matteRed, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onLabelImportance) }
                AIGridTile(icon: "clock.badge.questionmark", label: "Duration", color: AppTheme.matteBlue, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onPredictDuration) }
                AIGridTile(icon: "calendar.badge.clock", label: "Plan Day", color: AppTheme.matteSlate, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onPlanMyDay) }
                AIGridTile(icon: "location.magnifyingglass", label: "Contexts", color: AppTheme.matteTeal, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onSmartContext) }
                AIGridTile(icon: "arrow.uturn.right.circle.fill", label: "Reschedule", color: AppTheme.accent, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onAutoReschedule) }
                AIGridTile(icon: "text.bubble.fill", label: "Capture", color: AppTheme.matteTeal, disabled: apiKey.isEmpty, isDarkMode: isDarkMode) { dismissAndRun(onQuickCapture) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.surface(.secondary, isDark: isDarkMode))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .presentationDetents([.height(apiKey.isEmpty ? 360 : 280)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        .onAppear { apiKey = KeychainManager.shared.getApiKey() }
    }
    
    private func dismissAndRun(_ action: @escaping () -> Void) {
        isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            action()
        }
    }
}

// MARK: - Compact Grid Tile

struct AIGridTile: View {
    let icon: String
    let label: String
    let color: Color
    let disabled: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(AppTheme.surface(.tertiary, isDark: isDarkMode))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusMedium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

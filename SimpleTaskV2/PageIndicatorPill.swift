import SwiftUI

struct PageIndicatorPill: View {
    @Binding var selectedTab: Int
    let totalTabs: Int
    
    @State private var isDragging: Bool = false
    
    // Configurable dimensions
    private let dotSize: CGFloat = 8
    private let activeDotSize: CGFloat = 10
    private let dotSpacing: CGFloat = 10
    private let pillPaddingHorizontal: CGFloat = 16
    private let pillPaddingVertical: CGFloat = 10
    
    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<totalTabs, id: \.self) { index in
                Circle()
                    .fill(selectedTab == index ? AppTheme.accent : Color.gray.opacity(0.6))
                    .frame(width: selectedTab == index ? activeDotSize : dotSize, 
                           height: selectedTab == index ? activeDotSize : dotSize)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)
            }
        }
        .padding(.horizontal, pillPaddingHorizontal)
        .padding(.vertical, pillPaddingVertical)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDragging)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.1)) {
                        isDragging = true
                    }
                    
                    // Total width of the interactive area roughly
                    let totalWidth = CGFloat(totalTabs) * dotSize + CGFloat(totalTabs - 1) * dotSpacing + pillPaddingHorizontal * 2
                    
                    // We map the scrub position to a tab index.
                    let scrubPosition = max(0, min(value.location.x, totalWidth))
                    let segmentWidth = totalWidth / CGFloat(totalTabs)
                    
                    let newIndex = Int(scrubPosition / segmentWidth)
                    let clampedIndex = min(max(newIndex, 0), totalTabs - 1)
                    
                    if clampedIndex != selectedTab {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = clampedIndex
                        }
                        HapticAndSoundManager.shared.triggerHapticSelection()
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isDragging = false
                    }
                }
        )
    }
}

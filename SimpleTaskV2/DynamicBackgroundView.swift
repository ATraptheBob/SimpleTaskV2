import SwiftUI

struct DynamicBackgroundView: View {
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("useDynamicBackground") private var useDynamicBackground = true
    
    /// Controls a very slow, barely-perceptible warmth shift.
    @State private var animateShift = false
    
    var body: some View {
        ZStack {
            if isDarkMode {
                // Dark mode: near-black base to warm charcoal
                LinearGradient(
                    colors: darkGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: warm off-white to cool cream
                LinearGradient(
                    colors: lightGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if useDynamicBackground {
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    animateShift = true
                }
            }
        }
        .onChange(of: useDynamicBackground) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                    animateShift = true
                }
            }
        }
    }
    
    /// Dark gradient: subtle warm-to-cool shift when dynamic is on.
    private var darkGradientColors: [Color] {
        if useDynamicBackground && animateShift {
            return [
                AppTheme.surfacePrimary,
                Color(hue: 0.97, saturation: 0.06, brightness: 0.10),  // faint rose warmth
                Color(hue: 0.62, saturation: 0.04, brightness: 0.08)   // faint cool edge
            ]
        }
        return [
            AppTheme.surfacePrimary,
            Color(white: 0.05),
            Color(white: 0.04)
        ]
    }
    
    /// Light gradient: warm off-white to cool cream.
    private var lightGradientColors: [Color] {
        if useDynamicBackground && animateShift {
            return [
                AppTheme.lightSurfacePrimary,
                Color(hue: 0.08, saturation: 0.05, brightness: 0.96),  // warm cream
                Color(hue: 0.55, saturation: 0.03, brightness: 0.95)   // cool hint
            ]
        }
        return [
            AppTheme.lightSurfacePrimary,
            Color(white: 0.96),
            Color(white: 0.95)
        ]
    }
}

import SwiftUI

struct DynamicBackgroundView: View {
    @AppStorage("isDarkMode") private var isDarkMode = true
    @AppStorage("useDynamicBackground") private var useDynamicBackground = true
    
    @State private var animate1 = false
    @State private var animate2 = false
    @State private var animate3 = false
    
    var body: some View {
        ZStack {
            // Base background
            (isDarkMode ? Color.black : Color.white).ignoresSafeArea()
            
            if useDynamicBackground {
                // Rasterize all blurred orbs into a single GPU texture.
                // Without drawingGroup(), each 60-90pt blur is composited
                // separately on every animation frame — extremely expensive.
                ZStack {
                    // Orb 1
                    Circle()
                        .fill(Color.pink.opacity(isDarkMode ? 0.4 : 0.2))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: animate1 ? -100 : 100, y: animate1 ? -150 : 150)
                        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animate1)
                    
                    // Orb 2
                    Circle()
                        .fill(Color.purple.opacity(isDarkMode ? 0.3 : 0.15))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: animate2 ? 150 : -100, y: animate2 ? 200 : -200)
                        .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animate2)
                    
                    // Orb 3
                    Circle()
                        .fill(Color.orange.opacity(isDarkMode ? 0.3 : 0.15))
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .offset(x: animate3 ? -50 : 150, y: animate3 ? 100 : -100)
                        .animation(.easeInOut(duration: 12).repeatForever(autoreverses: true), value: animate3)
                }
                .drawingGroup() // Flattens 3 expensive blur layers into 1 GPU-rendered texture
            }
        }
        .onAppear {
            if useDynamicBackground {
                animate1 = true
                animate2 = true
                animate3 = true
            }
        }
        .onChange(of: useDynamicBackground) { _, newValue in
            if newValue {
                animate1 = true
                animate2 = true
                animate3 = true
            }
        }
        .ignoresSafeArea()
    }
}

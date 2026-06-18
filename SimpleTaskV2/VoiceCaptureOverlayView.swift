import SwiftUI

struct VoiceCaptureOverlayView: View {
    @ObservedObject var voiceManager: VoiceCaptureManager
    var isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text(voiceManager.transcribedText.isEmpty ? "Listening..." : voiceManager.transcribedText)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(isDarkMode ? .white : .black)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal)
            
            HStack(spacing: 4) {
                ForEach(0..<15, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.pink)
                        .frame(width: 4, height: max(4, CGFloat(voiceManager.audioLevel) * CGFloat.random(in: 20...60)))
                        .animation(.linear(duration: 0.1), value: voiceManager.audioLevel)
                }
            }
            .frame(height: 60)
        }
        .padding(24)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(isDarkMode ? 0.2 : 0.5), lineWidth: 1)
        )
    }
}

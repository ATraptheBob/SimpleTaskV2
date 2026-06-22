import SwiftUI

struct VoiceCaptureOverlayView: View {
    @ObservedObject var voiceManager: VoiceCaptureManager
    var isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(voiceManager.transcribedText.isEmpty ? "Listening..." : voiceManager.transcribedText)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal, 32)
            
            HStack(spacing: 6) {
                ForEach(0..<15, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white)
                        .frame(width: 4, height: max(6, CGFloat(voiceManager.audioLevel) * CGFloat.random(in: 20...60)))
                        .animation(.linear(duration: 0.1), value: voiceManager.audioLevel)
                }
            }
            .frame(height: 60)
        }
        .padding(20)
        .frame(width: 300)
        // No ugly background! Let it overlay perfectly on the big red circle
    }
}

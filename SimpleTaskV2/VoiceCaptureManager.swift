import Foundation
import Speech
import AVFoundation
internal import Combine

protocol AVAudioSessionProtocol {
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AVAudioSessionProtocol {}

class VoiceCaptureManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var audioLevel: Float = 0.0
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    internal var audioEngine = AVAudioEngine()
    internal var audioSessionProvider: AVAudioSessionProtocol = AVAudioSession.sharedInstance()
    
    private var displayLink: CADisplayLink?
    
    override init() {
        super.init()
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            completion(granted)
                        }
                    }
                } else {
                    completion(false)
                }
            }
        }
    }
    
    func startRecording() throws {
        // Cancel previous task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = audioSessionProvider
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode = audioEngine.inputNode
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
            self.updateAudioLevel(buffer: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.transcribedText = "Listening..."
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map{ channelData[$0] }
        let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        // Convert to a 0-1 scale, rough approximation
        var level = max(0, min(1, (avgPower + 50) / 50))
        if level.isNaN { level = 0 }
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
}

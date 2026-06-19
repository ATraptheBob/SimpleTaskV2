import XCTest
import AVFoundation
@testable import SimpleTaskV2

class MockAudioSession: AVAudioSessionProtocol {
    var shouldThrowOnSetCategory = false
    var shouldThrowOnSetActive = false

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions) throws {
        if shouldThrowOnSetCategory {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        if shouldThrowOnSetActive {
            throw NSError(domain: "Test", code: 2, userInfo: nil)
        }
    }
}

class MockAudioEngine: AVAudioEngine {
    var shouldThrowOnStart = false

    override func start() throws {
        if shouldThrowOnStart {
            throw NSError(domain: "Test", code: 3, userInfo: nil)
        }
        try super.start()
    }
}

final class VoiceCaptureManagerTests: XCTestCase {

    func testStartRecording_ThrowsError_WhenAudioSessionSetCategoryFails() {
        let manager = VoiceCaptureManager()
        let mockSession = MockAudioSession()
        mockSession.shouldThrowOnSetCategory = true
        manager.audioSessionProvider = mockSession

        XCTAssertThrowsError(try manager.startRecording()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 1)
        }
    }

    func testStartRecording_ThrowsError_WhenAudioSessionSetActiveFails() {
        let manager = VoiceCaptureManager()
        let mockSession = MockAudioSession()
        mockSession.shouldThrowOnSetActive = true
        manager.audioSessionProvider = mockSession

        XCTAssertThrowsError(try manager.startRecording()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 2)
        }
    }

    func testStartRecording_ThrowsError_WhenAudioEngineStartFails() {
        let manager = VoiceCaptureManager()
        let mockSession = MockAudioSession()
        manager.audioSessionProvider = mockSession

        let mockEngine = MockAudioEngine()
        mockEngine.shouldThrowOnStart = true
        manager.audioEngine = mockEngine

        XCTAssertThrowsError(try manager.startRecording()) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.code, 3)
        }
    }
}

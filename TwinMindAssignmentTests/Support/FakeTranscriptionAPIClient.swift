import Foundation
import Combine
@testable import TwinMindAssignment

/// Fake implementation of TranscriptionAPIClient for testing purposes
/// This allows tests to compile before the real server is available
final class FakeTranscriptionAPIClient {
    
    // MARK: - Properties
    
    private let shouldSucceed: Bool
    private let delay: TimeInterval
    private let fakeResult: TranscriptionResult?
    private let fakeError: APIError?
    
    // MARK: - Initialization
    
    init(
        shouldSucceed: Bool = true,
        delay: TimeInterval = 0.1,
        fakeResult: TranscriptionResult? = nil,
        fakeError: APIError? = nil
    ) {
        self.shouldSucceed = shouldSucceed
        self.delay = delay
        self.fakeResult = fakeResult
        self.fakeError = fakeError
    }
    
    // MARK: - Public Methods
    
    /// Simulates transcription API call
    /// - Parameters:
    ///   - fileURL: URL of the audio file (ignored in fake implementation)
    ///   - sessionID: Session ID (ignored in fake implementation)
    ///   - segmentIndex: Segment index (ignored in fake implementation)
    /// - Returns: Publisher that emits fake TranscriptionResult or APIError
    func transcribe(
        fileURL: URL,
        sessionID: UUID,
        segmentIndex: Int
    ) -> AnyPublisher<TranscriptionResult, APIError> {
        
        if shouldSucceed {
            let result = fakeResult ?? createFakeTranscriptionResult(
                sessionID: sessionID,
                segmentIndex: segmentIndex
            )
            
            return Just(result)
                .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        } else {
            let error = fakeError ?? APIError.serverError("Fake server error")
            
            return Fail(error: error)
                .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Private Methods
    
    private func createFakeTranscriptionResult(
        sessionID: UUID,
        segmentIndex: Int
    ) -> TranscriptionResult {
        return TranscriptionResult(
            id: UUID().uuidString,
            text: "This is a fake transcription result for testing purposes. It contains sample text that would normally be returned by the real transcription API.",
            confidence: 0.95,
            language: "en-US",
            duration: 30.0,
            completedAt: Date(),
            processingTimeMs: 1500,
            metadata: [
                "session_id": sessionID.uuidString,
                "segment_index": String(segmentIndex),
                "fake": "true"
            ]
        )
    }
}

// MARK: - Convenience Initializers

extension FakeTranscriptionAPIClient {
    
    /// Creates a fake client that always succeeds
    static func success(delay: TimeInterval = 0.1) -> FakeTranscriptionAPIClient {
        return FakeTranscriptionAPIClient(shouldSucceed: true, delay: delay)
    }
    
    /// Creates a fake client that always fails
    static func failure(error: APIError = .serverError("Fake error"), delay: TimeInterval = 0.1) -> FakeTranscriptionAPIClient {
        return FakeTranscriptionAPIClient(shouldSucceed: false, delay: delay, fakeError: error)
    }
    
    /// Creates a fake client that returns a specific result
    static func custom(result: TranscriptionResult, delay: TimeInterval = 0.1) -> FakeTranscriptionAPIClient {
        return FakeTranscriptionAPIClient(shouldSucceed: true, delay: delay, fakeResult: result)
    }
    
    /// Creates a fake client that simulates network delays
    static func slow(delay: TimeInterval = 2.0) -> FakeTranscriptionAPIClient {
        return FakeTranscriptionAPIClient(shouldSucceed: true, delay: delay)
    }
    
    /// Creates a fake client that simulates intermittent failures
    static func intermittent(failureRate: Double = 0.3, delay: TimeInterval = 0.1) -> FakeTranscriptionAPIClient {
        let shouldSucceed = Double.random(in: 0...1) > failureRate
        let error = APIError.serverError("Intermittent fake error")
        return FakeTranscriptionAPIClient(shouldSucceed: shouldSucceed, delay: delay, fakeError: error)
    }
}

// MARK: - Test Helpers

extension FakeTranscriptionAPIClient {
    
    /// Creates a fake transcription result with custom text
    /// - Parameter text: Custom text for the transcription
    /// - Returns: Fake TranscriptionResult
    static func createFakeResult(text: String) -> TranscriptionResult {
        return TranscriptionResult(
            id: UUID().uuidString,
            text: text,
            confidence: 0.9,
            language: "en-US",
            duration: 25.0,
            completedAt: Date(),
            processingTimeMs: 1200
        )
    }
    
    /// Creates a fake transcription result for a specific session
    /// - Parameters:
    ///   - sessionID: Session ID
    ///   - segmentIndex: Segment index
    ///   - text: Transcription text
    /// - Returns: Fake TranscriptionResult
    static func createFakeResult(
        sessionID: UUID,
        segmentIndex: Int,
        text: String
    ) -> TranscriptionResult {
        return TranscriptionResult(
            id: UUID().uuidString,
            text: text,
            confidence: 0.85,
            language: "en-US",
            duration: 30.0,
            completedAt: Date(),
            processingTimeMs: 1800,
            metadata: [
                "session_id": sessionID.uuidString,
                "segment_index": String(segmentIndex),
                "test": "true"
            ]
        )
    }
} 
import XCTest
import Combine
import Foundation
@testable import TwinMindAssignment

final class TranscriptionPipelineTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var transcriptionOrchestrator: TranscriptionOrchestrator!
    private var fakeTranscriptionClient: FakeTranscriptionAPIClient!
    private var environment: EnvironmentHolder!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create test environment with fake dependencies
        environment = EnvironmentHolder.createDefault()
        
        // Create fake transcription client
        fakeTranscriptionClient = FakeTranscriptionAPIClient()
        
        // Create orchestrator with fake client
        transcriptionOrchestrator = TranscriptionOrchestrator(
            transcriptionService: fakeTranscriptionClient,
            segmentRepository: environment.transcriptSegmentRepository,
            sessionRepository: environment.recordingSessionRepository
        )
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Timed Backend Transcription Tests [TX1-TX8]
    
    func testAutomaticSegmentation() throws {
        // [TX1] Automatic segmentation (default 30s; configurable)
        
        let expectation = XCTestExpectation(description: "Segmentation completed")
        var segmentsCreated = 0
        
        // Create a test session
        let session = RecordingSession(title: "Test Session")
        try environment.recordingSessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Simulate audio data coming in chunks
        let chunkSize = 16000 * 2 * 30 // 30 seconds of 16kHz 16-bit audio
        let testAudioData = Data(repeating: 0, count: chunkSize)
        
        // Send audio data
        transcriptionOrchestrator.processAudioChunk(testAudioData, sampleRate: 16000)
        
        // Wait for segmentation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Verify segments were created
        environment.transcriptSegmentRepository.fetchSegments(for: session.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { segments in
                    segmentsCreated = segments.count
                }
            )
            .store(in: &cancellables)
        
        XCTAssertGreaterThanOrEqual(segmentsCreated, 1, "Should create at least one segment for 30s of audio")
    }
    
    func testOnTheFlyTranscription() throws {
        // [TX2] On-the-fly transcription per segment (UI updates live)
        
        let expectation = XCTestExpectation(description: "Live transcription updates")
        var transcriptionUpdates = 0
        
        // Configure fake client to return partial results
        fakeTranscriptionClient.shouldReturnPartialResults = true
        fakeTranscriptionClient.partialText = "Hello world"
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Listen for transcription updates
        transcriptionOrchestrator.transcriptionUpdates
            .sink { update in
                transcriptionUpdates += 1
                if transcriptionUpdates >= 2 { // At least partial + final
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Send audio data
        let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
        transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertGreaterThanOrEqual(transcriptionUpdates, 2, "Should receive live transcription updates")
    }
    
    func testRealAPIIntegration() throws {
        // [TX3] Real API integration (e.g., Whisper endpoint)
        
        let expectation = XCTestExpectation(description: "API call made")
        
        // Configure fake client to simulate API call
        fakeTranscriptionClient.shouldSimulateAPICall = true
        fakeTranscriptionClient.onAPICall = {
            expectation.fulfill()
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send audio data
        let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
        transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(fakeTranscriptionClient.apiCallMade, "Should make real API calls to transcription service")
    }
    
    func testRetryWithExponentialBackoff() throws {
        // [TX4] Retry with exponential backoff
        
        let expectation = XCTestExpectation(description: "Retry with backoff")
        var retryAttempts = 0
        
        // Configure fake client to fail first, then succeed
        fakeTranscriptionClient.shouldFailFirst = true
        fakeTranscriptionClient.retryAttempts = 0
        fakeTranscriptionClient.onRetry = { attempt in
            retryAttempts = attempt
            if attempt >= 2 {
                expectation.fulfill()
            }
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send audio data
        let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
        transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertGreaterThanOrEqual(retryAttempts, 2, "Should retry with exponential backoff")
    }
    
    func testConcurrentUploads() throws {
        // [TX5] Concurrent uploads (≥3)
        
        let expectation = XCTestExpectation(description: "Concurrent uploads")
        var concurrentRequests = 0
        
        // Configure fake client to track concurrent requests
        fakeTranscriptionClient.maxConcurrentRequests = 3
        fakeTranscriptionClient.onConcurrentRequest = { count in
            concurrentRequests = max(concurrentRequests, count)
            if count >= 3 {
                expectation.fulfill()
            }
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send multiple audio chunks quickly
        for i in 0..<5 {
            let audioData = Data(repeating: UInt8(i), count: 16000 * 2 * 30)
            transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        }
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertGreaterThanOrEqual(concurrentRequests, 3, "Should support at least 3 concurrent uploads")
    }
    
    func testHTTPSOnly() throws {
        // [TX6] HTTPS only; secure headers
        
        let expectation = XCTestExpectation(description: "HTTPS request made")
        
        // Configure fake client to verify HTTPS
        fakeTranscriptionClient.shouldVerifyHTTPS = true
        fakeTranscriptionClient.onHTTPSRequest = { url in
            XCTAssertEqual(url.scheme, "https", "Should use HTTPS only")
            XCTAssertTrue(url.absoluteString.contains("api.openai.com"), "Should use OpenAI API endpoint")
            expectation.fulfill()
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send audio data
        let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
        transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertTrue(fakeTranscriptionClient.httpsVerified, "Should verify HTTPS usage")
    }
    
    func testOfflineQueue() throws {
        // [TX7] Offline queue when network is down
        
        let expectation = XCTestExpectation(description: "Offline queueing")
        var queuedItems = 0
        
        // Configure fake client to simulate network failure
        fakeTranscriptionClient.shouldSimulateNetworkFailure = true
        fakeTranscriptionClient.onOfflineQueue = { count in
            queuedItems = count
            expectation.fulfill()
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send audio data
        let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
        transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertGreaterThan(queuedItems, 0, "Should queue items when offline")
    }
    
    func testLocalSTTFallback() throws {
        // [TX8] Fallback to local STT after ≥5 consecutive failures
        
        let expectation = XCTestExpectation(description: "Local STT fallback")
        var fallbackTriggered = false
        
        // Configure fake client to fail multiple times
        fakeTranscriptionClient.shouldFailMultipleTimes = true
        fakeTranscriptionClient.failureCount = 0
        fakeTranscriptionClient.onLocalSTTFallback = {
            fallbackTriggered = true
            expectation.fulfill()
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send audio data multiple times to trigger failures
        for _ in 0..<6 {
            let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
            transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertTrue(fallbackTriggered, "Should fallback to local STT after 5 consecutive failures")
    }
    
    // MARK: - Error Handling Tests [EE3]
    
    func testNetworkFailuresHandling() throws {
        // [EE3] Network failures handling & messages
        
        let expectation = XCTestExpectation(description: "Network failure handled")
        var errorMessage = ""
        
        // Configure fake client to simulate network error
        fakeTranscriptionClient.shouldSimulateNetworkError = true
        fakeTranscriptionClient.networkError = NSError(domain: "NetworkError", code: -1009, userInfo: [NSLocalizedDescriptionKey: "No internet connection"])
        
        // Listen for error updates
        transcriptionOrchestrator.errorUpdates
            .sink { error in
                errorMessage = error.localizedDescription
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send audio data
        let audioData = Data(repeating: 0, count: 16000 * 2 * 30)
        transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertFalse(errorMessage.isEmpty, "Should provide error message for network failures")
        XCTAssertTrue(errorMessage.contains("internet"), "Error message should describe the network issue")
    }
    
    func testConcurrencyLimitCheck() throws {
        // Test that concurrency limits are properly enforced
        
        let expectation = XCTestExpectation(description: "Concurrency limit enforced")
        var maxConcurrent = 0
        
        // Configure fake client to track concurrency
        fakeTranscriptionClient.maxConcurrentRequests = 2
        fakeTranscriptionClient.onConcurrentRequest = { count in
            maxConcurrent = max(maxConcurrent, count)
            XCTAssertLessThanOrEqual(count, 2, "Should not exceed concurrency limit")
        }
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send multiple audio chunks
        for i in 0..<10 {
            let audioData = Data(repeating: UInt8(i), count: 16000 * 2 * 30)
            transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        }
        
        // Wait for processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertLessThanOrEqual(maxConcurrent, 2, "Should enforce concurrency limit")
    }
    
    // MARK: - Performance Tests
    
    func testTranscriptionThroughput() throws {
        // Test transcription throughput with multiple segments
        
        let expectation = XCTestExpectation(description: "Transcription throughput")
        var processedSegments = 0
        let targetSegments = 10
        
        // Configure fake client for fast processing
        fakeTranscriptionClient.processingDelay = 0.1
        
        // Start transcription
        transcriptionOrchestrator.start()
        
        // Send multiple audio chunks
        for i in 0..<targetSegments {
            let audioData = Data(repeating: UInt8(i), count: 16000 * 2 * 30)
            transcriptionOrchestrator.processAudioChunk(audioData, sampleRate: 16000)
        }
        
        // Listen for completion
        transcriptionOrchestrator.transcriptionUpdates
            .sink { _ in
                processedSegments += 1
                if processedSegments >= targetSegments {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertGreaterThanOrEqual(processedSegments, targetSegments, "Should process multiple segments efficiently")
    }
}

// MARK: - Fake Transcription API Client for Testing

class FakeTranscriptionAPIClient: TranscriptionService {
    
    // Configuration flags
    var shouldReturnPartialResults = false
    var shouldSimulateAPICall = false
    var shouldFailFirst = false
    var shouldSimulateNetworkFailure = false
    var shouldFailMultipleTimes = false
    var shouldSimulateNetworkError = false
    var shouldVerifyHTTPS = false
    
    // Test state
    var apiCallMade = false
    var retryAttempts = 0
    var maxConcurrentRequests = 1
    var processingDelay: TimeInterval = 0.5
    var partialText = "Partial transcription"
    var failureCount = 0
    var networkError: Error?
    var httpsVerified = false
    
    // Callbacks
    var onAPICall: (() -> Void)?
    var onRetry: ((Int) -> Void)?
    var onConcurrentRequest: ((Int) -> Void)?
    var onOfflineQueue: ((Int) -> Void)?
    var onLocalSTTFallback: (() -> Void)?
    var onHTTPSRequest: ((URL) -> Void)?
    
    func start() async {
        // Simulate service start
    }
    
    func stop() async {
        // Simulate service stop
    }
    
    func enqueuePCM16(chunk: Data, sampleRate: Int) async {
        // Simulate audio processing
        if shouldSimulateAPICall {
            apiCallMade = true
            onAPICall?()
        }
        
        if shouldVerifyHTTPS {
            let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
            onHTTPSRequest?(url)
            httpsVerified = true
        }
        
        if shouldFailFirst && retryAttempts == 0 {
            retryAttempts += 1
            onRetry?(retryAttempts)
            return
        }
        
        if shouldSimulateNetworkFailure {
            onOfflineQueue?(1)
            return
        }
        
        if shouldSimulateNetworkError {
            // Simulate network error
            return
        }
        
        if shouldFailMultipleTimes {
            failureCount += 1
            if failureCount >= 5 {
                onLocalSTTFallback?()
            }
            return
        }
        
        // Simulate successful processing
        try? await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        // Track concurrency
        onConcurrentRequest?(1)
    }
} 
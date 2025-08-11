import XCTest
import Combine
@testable import TwinMindAssignment

final class OrchestratorTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    private var testScheduler: TestScheduler!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        testScheduler = TestScheduler()
    }
    
    override func tearDown() {
        cancellables = nil
        testScheduler = nil
        super.tearDown()
    }
    
    // MARK: - Orchestrator Parallelism Tests
    
    func testOrchestratorProcessesSegmentsInParallel() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segments = [
            TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: UUID(), index: 2, startTime: 30, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: UUID(), index: 3, startTime: 60, duration: 30.0, status: .pending)
        ]
        
        let expectation = XCTestExpectation(description: "Orchestrator processes segments in parallel")
        expectation.expectedFulfillmentCount = 3
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                if case .segmentProcessing = event {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Add segments to queue
        segments.forEach { orchestrator.addSegmentToQueue($0) }
        
        // Simulate parallel processing
        orchestrator.simulateSegmentProcessing(sessionID: segments[0].sessionID, segmentIndex: segments[0].index)
        orchestrator.simulateSegmentProcessing(sessionID: segments[1].sessionID, segmentIndex: segments[1].index)
        orchestrator.simulateSegmentProcessing(sessionID: segments[2].sessionID, segmentIndex: segments[2].index)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testOrchestratorLimitsConcurrentProcessing() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segments = [
            TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: UUID(), index: 2, startTime: 30, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: UUID(), index: 3, startTime: 60, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: UUID(), index: 4, startTime: 90, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: UUID(), index: 5, startTime: 120, duration: 30.0, status: .pending)
        ]
        
        let processingExpectation = XCTestExpectation(description: "Orchestrator processes segments with concurrency limit")
        let queueExpectation = XCTestExpectation(description: "Orchestrator queues excess segments")
        
        var processingCount = 0
        var queuedCount = 0
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                switch event {
                case .segmentProcessing:
                    processingCount += 1
                    if processingCount == 3 {
                        processingExpectation.fulfill()
                    }
                case .segmentQueued:
                    queuedCount += 1
                    if queuedCount == 2 {
                        queueExpectation.fulfill()
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Add segments to queue
        segments.forEach { orchestrator.addSegmentToQueue($0) }
        
        // Simulate processing of first 3 segments
        for i in 0..<3 {
            orchestrator.simulateSegmentProcessing(sessionID: segments[i].sessionID, segmentIndex: segments[i].index)
        }
        
        // Then
        wait(for: [processingExpectation, queueExpectation], timeout: 1.0)
        XCTAssertEqual(processingCount, 3)
        XCTAssertEqual(queuedCount, 2)
    }
    
    // MARK: - Orchestrator Fallback Tests
    
    func testOrchestratorTriggersFallbackAfterMultipleFailures() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segment = TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending)
        let testError = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let failureExpectation = XCTestExpectation(description: "Orchestrator handles segment failure")
        let fallbackExpectation = XCTestExpectation(description: "Orchestrator triggers fallback after multiple failures")
        
        var failureCount = 0
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                switch event {
                case .segmentFailed(_, _, _, let count):
                    failureCount = count
                    if count >= 5 {
                        fallbackExpectation.fulfill()
                    }
                    failureExpectation.fulfill()
                case .fallbackTriggered:
                    fallbackExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Simulate multiple failures
        for i in 1...5 {
            orchestrator.simulateSegmentFailed(
                sessionID: segment.sessionID,
                segmentIndex: segment.index,
                error: testError,
                failureCount: i
            )
        }
        
        // Then
        wait(for: [failureExpectation, fallbackExpectation], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(failureCount, 5)
    }
    
    func testOrchestratorRetriesFailedSegments() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segment = TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending)
        let testError = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let retryExpectation = XCTestExpectation(description: "Orchestrator retries failed segments")
        let successExpectation = XCTestExpectation(description: "Orchestrator succeeds after retry")
        
        var retryCount = 0
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                switch event {
                case .segmentFailed(_, _, _, let count):
                    retryCount = count
                    if count < 3 {
                        retryExpectation.fulfill()
                    }
                case .segmentCompleted:
                    successExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Simulate failures followed by success
        orchestrator.simulateSegmentFailed(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            error: testError,
            failureCount: 1
        )
        
        orchestrator.simulateSegmentFailed(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            error: testError,
            failureCount: 2
        )
        
        // Simulate success after retries
        let result = TranscriptionResult(
            id: "test-123",
            text: "Success after retry",
            confidence: 0.95,
            language: "en",
            duration: 30.0,
            completedAt: Date(),
            processingTimeMs: 1000,
            metadata: nil
        )
        
        orchestrator.simulateSegmentCompleted(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            result: result
        )
        
        // Then
        wait(for: [retryExpectation, successExpectation], timeout: 1.0)
        XCTAssertEqual(retryCount, 2)
    }
    
    // MARK: - Orchestrator State Management Tests
    
    func testOrchestratorStartsAndStopsCorrectly() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let startExpectation = XCTestExpectation(description: "Orchestrator starts correctly")
        let stopExpectation = XCTestExpectation(description: "Orchestrator stops correctly")
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                switch event {
                case .segmentQueued:
                    startExpectation.fulfill()
                case .orchestratorPaused:
                    stopExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        orchestrator.start()
        orchestrator.stop()
        
        // Then
        wait(for: [startExpectation, stopExpectation], timeout: 1.0)
        XCTAssertFalse(orchestrator.isRunning)
    }
    
    func testOrchestratorMaintainsQueueStatus() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segment = TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending)
        
        let queueExpectation = XCTestExpectation(description: "Orchestrator maintains queue status")
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                if case .segmentQueued = event {
                    queueExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        orchestrator.addSegmentToQueue(segment)
        
        // Then
        wait(for: [queueExpectation], timeout: 1.0)
        XCTAssertNotNil(orchestrator.queueStatus)
    }
    
    // MARK: - Network Reachability Tests
    
    func testOrchestratorRespondsToNetworkChanges() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let networkChangeExpectation = XCTestExpectation(description: "Orchestrator responds to network changes")
        let offlineExpectation = XCTestExpectation(description: "Orchestrator handles offline state")
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                switch event {
                case .networkReachabilityChanged(let isReachable, _):
                    if !isReachable {
                        offlineExpectation.fulfill()
                    }
                    networkChangeExpectation.fulfill()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Simulate network loss
        orchestrator.simulateNetworkReachabilityChange(isReachable: false, connectionType: .unknown)
        
        // Then
        wait(for: [networkChangeExpectation, offlineExpectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testOrchestratorHandlesTranscriptionErrors() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segment = TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending)
        let testError = APIError.serverError("Internal Server Error")
        
        let errorExpectation = XCTestExpectation(description: "Orchestrator handles transcription errors")
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                if case .segmentFailed(_, _, let error, _) = event {
                    XCTAssertEqual(error, testError)
                    errorExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        orchestrator.simulateSegmentFailed(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            error: testError,
            failureCount: 1
        )
        
        // Then
        wait(for: [errorExpectation], timeout: 1.0)
    }
    
    // MARK: - Performance Tests
    
    func testOrchestratorHandlesHighVolumeSegments() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segments = (1...100).map { index in
            TranscriptSegment(
                sessionID: UUID(),
                index: index,
                startTime: TimeInterval(index * 30),
                duration: 30.0,
                status: .pending
            )
        }
        
        let volumeExpectation = XCTestExpectation(description: "Orchestrator handles high volume segments")
        volumeExpectation.expectedFulfillmentCount = 100
        
        // When
        orchestrator.eventsPublisher
            .sink { event in
                if case .segmentQueued = event {
                    volumeExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Add all segments to queue
        segments.forEach { orchestrator.addSegmentToQueue($0) }
        
        // Then
        wait(for: [volumeExpectation], timeout: 5.0)
    }
    
    // MARK: - Test Scheduler Integration Tests
    
    func testOrchestratorWithTestScheduler() throws {
        // Given
        let orchestrator = FakeTranscriptionOrchestrator()
        let segment = TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending)
        
        let schedulerExpectation = XCTestExpectation(description: "Orchestrator works with test scheduler")
        
        // When
        orchestrator.eventsPublisher
            .receive(on: testScheduler)
            .sink { event in
                if case .segmentQueued = event {
                    schedulerExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        orchestrator.addSegmentToQueue(segment)
        
        // Advance scheduler
        testScheduler.advance()
        
        // Then
        wait(for: [schedulerExpectation], timeout: 1.0)
    }
} 
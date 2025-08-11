import XCTest
import Combine
import SwiftData
@testable import TwinMindAssignment

/// Tests for the transcription pipeline functionality
final class TranscriptionPipelineTests: XCTestCase {
    
    // MARK: - Properties
    
    private var environment: EnvironmentHolder!
    private var transcriptionOrchestrator: TranscriptionOrchestrator!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        // Create test environment
        environment = EnvironmentHolder.createDefault()
        
        // Create transcription orchestrator with default dependencies
        transcriptionOrchestrator = TranscriptionOrchestrator(
            sessionRepository: environment.recordingSessionRepository,
            segmentRepository: environment.transcriptSegmentRepository
        )
        
        // Create test session
        let session = RecordingSession(title: "Test Session")
        environment.recordingSessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Wait for session creation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testOrchestratorStartStop() throws {
        // Test basic start/stop functionality
        
        let expectation = XCTestExpectation(description: "Orchestrator start/stop")
        
        // Verify initial state
        XCTAssertFalse(transcriptionOrchestrator.isRunning, "Orchestrator should not be running initially")
        
        // Start orchestrator
        transcriptionOrchestrator.start()
        XCTAssertTrue(transcriptionOrchestrator.isRunning, "Orchestrator should be running after start")
        
        // Stop orchestrator
        transcriptionOrchestrator.stop()
        XCTAssertFalse(transcriptionOrchestrator.isRunning, "Orchestrator should not be running after stop")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testQueueStatusInitialization() throws {
        // Test queue status initialization
        
        let expectation = XCTestExpectation(description: "Queue status")
        
        // Verify initial queue status
        let queueStatus = transcriptionOrchestrator.queueStatus
        XCTAssertEqual(queueStatus.queuedCount, 0, "Initial queue should be empty")
        XCTAssertEqual(queueStatus.processingCount, 0, "No segments should be processing initially")
        XCTAssertEqual(queueStatus.completedCount, 0, "No segments should be completed initially")
        XCTAssertEqual(queueStatus.failedCount, 0, "No segments should have failed initially")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testEventsPublisher() throws {
        // Test that events publisher emits events
        
        let expectation = XCTestExpectation(description: "Events publisher")
        var eventsReceived = 0
        
        // Subscribe to events
        transcriptionOrchestrator.eventsPublisher
            .sink { event in
                eventsReceived += 1
                if eventsReceived >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start orchestrator to trigger events
        transcriptionOrchestrator.start()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThanOrEqual(eventsReceived, 1, "Should receive at least one event")
    }
    
    func testTranscriptionSegmentsPublisher() throws {
        // Test that transcription segments publisher works
        
        let expectation = XCTestExpectation(description: "Transcription segments publisher")
        var segmentsReceived = 0
        
        // Subscribe to transcription segments
        transcriptionOrchestrator.transcriptionSegmentsPublisher
            .sink { segments in
                segmentsReceived += 1
                if segmentsReceived >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start orchestrator to trigger updates
        transcriptionOrchestrator.start()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertGreaterThanOrEqual(segmentsReceived, 1, "Should receive at least one segments update")
    }
} 
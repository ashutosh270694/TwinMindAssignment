import XCTest
import Combine
@testable import TwinMindAssignment

final class RepositoryTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Recording Session Repository Tests
    
    func testFetchSessionsEmitsValues() throws {
        // Given
        let repository = FakeRecordingSessionRepository.withSampleSessions()
        let expectation = XCTestExpectation(description: "Fetch sessions emits values")
        
        // When
        repository.fetchSessions()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { sessions in
                    XCTAssertEqual(sessions.count, 3)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchSessionByIdEmitsCorrectSession() throws {
        // Given
        let sessions = [
            RecordingSession(title: "Test Session", notes: "Test notes")
        ]
        let repository = FakeRecordingSessionRepository(sessions: sessions)
        let sessionId = sessions[0].id
        let expectation = XCTestExpectation(description: "Fetch session by ID emits correct session")
        
        // When
        repository.fetchSession(id: sessionId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { session in
                    XCTAssertNotNil(session)
                    XCTAssertEqual(session?.title, "Test Session")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testCreateSessionEmitsUpdatedSessions() throws {
        // Given
        let repository = FakeRecordingSessionRepository.empty()
        let newSession = RecordingSession(title: "New Session", notes: "New notes")
        let expectation = XCTestExpectation(description: "Create session emits updated sessions")
        
        // When
        repository.createSession(newSession)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    // Verify the sessions list was updated
                    repository.fetchSessions()
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { sessions in
                                XCTAssertEqual(sessions.count, 1)
                                XCTAssertEqual(sessions[0].title, "New Session")
                                expectation.fulfill()
                            }
                        )
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateSessionEmitsUpdatedSession() throws {
        // Given
        let session = RecordingSession(title: "Original Title", notes: "Original notes")
        let repository = FakeRecordingSessionRepository(sessions: [session])
        let updatedSession = RecordingSession(
            id: session.id,
            title: "Updated Title",
            notes: "Updated notes"
        )
        let expectation = XCTestExpectation(description: "Update session emits updated session")
        
        // When
        repository.updateSession(updatedSession)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { result in
                    XCTAssertEqual(result.title, "Updated Title")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDeleteSessionEmitsUpdatedSessions() throws {
        // Given
        let session = RecordingSession(title: "To Delete", notes: "Will be deleted")
        let repository = FakeRecordingSessionRepository(sessions: [session])
        let expectation = XCTestExpectation(description: "Delete session emits updated sessions")
        
        // When
        repository.deleteSession(session)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    // Verify the sessions list was updated
                    repository.fetchSessions()
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { sessions in
                                XCTAssertEqual(sessions.count, 0)
                                expectation.fulfill()
                            }
                        )
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSearchSessionsFiltersCorrectly() throws {
        // Given
        let sessions = [
            RecordingSession(title: "Apple Session", notes: "About apples"),
            RecordingSession(title: "Banana Session", notes: "About bananas"),
            RecordingSession(title: "Cherry Session", notes: "About cherries")
        ]
        let repository = FakeRecordingSessionRepository(sessions: sessions)
        let expectation = XCTestExpectation(description: "Search sessions filters correctly")
        
        // When
        repository.searchSessions(query: "Apple")
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results in
                    XCTAssertEqual(results.count, 1)
                    XCTAssertEqual(results[0].title, "Apple Session")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Transcript Segment Repository Tests
    
    func testFetchSegmentsForSessionEmitsCorrectSegments() throws {
        // Given
        let sessionId = UUID()
        let segments = [
            TranscriptSegment(sessionID: sessionId, index: 1, startTime: 0, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: sessionId, index: 2, startTime: 30, duration: 30.0, status: .transcribed)
        ]
        let repository = FakeTranscriptSegmentRepository(segments: segments)
        let expectation = XCTestExpectation(description: "Fetch segments for session emits correct segments")
        
        // When
        repository.fetchSegments(for: sessionId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results in
                    XCTAssertEqual(results.count, 2)
                    XCTAssertEqual(results[0].index, 1)
                    XCTAssertEqual(results[1].index, 2)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchPendingSegmentsEmitsOnlyPending() throws {
        // Given
        let sessionId = UUID()
        let segments = [
            TranscriptSegment(sessionID: sessionId, index: 1, startTime: 0, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: sessionId, index: 2, startTime: 30, duration: 30.0, status: .transcribed),
            TranscriptSegment(sessionID: sessionId, index: 3, startTime: 60, duration: 30.0, status: .pending)
        ]
        let repository = FakeTranscriptSegmentRepository(segments: segments)
        let expectation = XCTestExpectation(description: "Fetch pending segments emits only pending")
        
        // When
        repository.fetchPendingSegments()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { results in
                    XCTAssertEqual(results.count, 2)
                    XCTAssertTrue(results.allSatisfy { $0.status == .pending })
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testUpdateSegmentEmitsUpdatedSegment() throws {
        // Given
        let segment = TranscriptSegment(sessionID: UUID(), index: 1, startTime: 0, duration: 30.0, status: .pending)
        let repository = FakeTranscriptSegmentRepository(segments: [segment])
        var updatedSegment = segment
        updatedSegment.status = .transcribed
        updatedSegment.transcriptText = "Updated transcript"
        let expectation = XCTestExpectation(description: "Update segment emits updated segment")
        
        // When
        repository.updateSegment(updatedSegment)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { result in
                    XCTAssertEqual(result.status, .transcribed)
                    XCTAssertEqual(result.transcriptText, "Updated transcript")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRetrySegmentResetsFailureCount() throws {
        // Given
        let segment = TranscriptSegment(
            sessionID: UUID(),
            index: 1,
            startTime: 0,
            duration: 30.0,
            status: .failed
        )
        segment.failureCount = 3
        segment.lastError = "Previous error"
        
        let repository = FakeTranscriptSegmentRepository(segments: [segment])
        let expectation = XCTestExpectation(description: "Retry segment resets failure count")
        
        // When
        repository.retrySegment(segment)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { result in
                    XCTAssertEqual(result.failureCount, 0)
                    XCTAssertEqual(result.status, .pending)
                    XCTAssertNil(result.lastError)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testRepositorySimulatesError() throws {
        // Given
        let repository = FakeRecordingSessionRepository()
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: nil)
        let expectation = XCTestExpectation(description: "Repository simulates error")
        
        // When
        repository.fetchSessions()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error as NSError, testError)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Simulate error
        repository.simulateError(testError)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Publisher Behavior Tests
    
    func testRepositoryPublishersCompleteImmediately() throws {
        // Given
        let repository = FakeRecordingSessionRepository()
        let expectation = XCTestExpectation(description: "Repository publishers complete immediately")
        expectation.expectedFulfillmentCount = 2
        
        // When
        repository.fetchSessions()
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        repository.fetchSession(id: UUID())
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRepositoryPublishersEmitSingleValue() throws {
        // Given
        let repository = FakeRecordingSessionRepository.withSampleSessions()
        let expectation = XCTestExpectation(description: "Repository publishers emit single value")
        expectation.expectedFulfillmentCount = 2
        
        // When
        repository.fetchSessions()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        repository.fetchSession(id: UUID())
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
} 
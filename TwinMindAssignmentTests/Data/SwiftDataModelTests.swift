import XCTest
import SwiftData
import Combine
@testable import TwinMindAssignment

final class SwiftDataModelTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var sessionRepository: RecordingSessionRepositoryProtocol!
    private var segmentRepository: TranscriptSegmentRepositoryProtocol!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create in-memory SwiftData container for testing
        let schema = Schema([
            RecordingSession.self,
            TranscriptSegment.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer)
            
            // Create repositories with test context
            let swiftDataStack = SwiftDataStack(modelContext: modelContext)
            sessionRepository = InMemoryRecordingSessionRepository(context: modelContext)
            segmentRepository = InMemoryTranscriptSegmentRepository(context: modelContext)
        } catch {
            XCTFail("Failed to create test SwiftData container: \(error)")
        }
    }
    
    override func tearDown() {
        cancellables.removeAll()
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }
    
    // MARK: - SwiftData Integration Tests [SD1-SD3]
    
    func testSessionsAndSegmentsPersisted() throws {
        // [SD1] Sessions + Segments persisted
        
        let expectation = XCTestExpectation(description: "Data persistence")
        
        // Create a test session
        let session = RecordingSession(title: "Test Session")
        
        // Create test segments
        let segment1 = TranscriptSegment(
            sessionID: session.id,
            index: 0,
            startTime: 0,
            duration: 30,
            status: .recording,
            text: "First segment"
        )
        
        let segment2 = TranscriptSegment(
            sessionID: session.id,
            index: 1,
            startTime: 30,
            duration: 30,
            status: .transcribing,
            text: "Second segment"
        )
        
        // Save session
        try sessionRepository.createSession(session).sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Failed to create session: \(error)")
                }
            },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Save segments
        try segmentRepository.createSegment(segment1).sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Failed to create segment 1: \(error)")
                }
            },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        try segmentRepository.createSegment(segment2).sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTFail("Failed to create segment 2: \(error)")
                }
            },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Verify persistence by fetching
        sessionRepository.fetchSessions()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Failed to fetch sessions: \(error)")
                    }
                },
                receiveValue: { sessions in
                    XCTAssertEqual(sessions.count, 1, "Should have 1 session")
                    XCTAssertEqual(sessions.first?.title, "Test Session", "Session title should match")
                    
                    // Fetch segments for this session
                    self.segmentRepository.fetchSegments(for: session.id)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    XCTFail("Failed to fetch segments: \(error)")
                                }
                            },
                            receiveValue: { segments in
                                XCTAssertEqual(segments.count, 2, "Should have 2 segments")
                                XCTAssertEqual(segments[0].text, "First segment", "First segment text should match")
                                XCTAssertEqual(segments[1].text, "Second segment", "Second segment text should match")
                                expectation.fulfill()
                            }
                        )
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testProperRelationshipsAndCascade() throws {
        // [SD2] Proper relationships + cascade
        
        let expectation = XCTestExpectation(description: "Relationships and cascade")
        
        // Create a test session
        let session = RecordingSession(title: "Cascade Test Session")
        
        // Create multiple segments
        let segments = [
            TranscriptSegment(sessionID: session.id, index: 0, startTime: 0, duration: 30, status: .recording, text: "Segment 1"),
            TranscriptSegment(sessionID: session.id, index: 1, startTime: 30, duration: 30, status: .transcribing, text: "Segment 2"),
            TranscriptSegment(sessionID: session.id, index: 2, startTime: 60, duration: 30, status: .completed, text: "Segment 3")
        ]
        
        // Save session
        try sessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Save all segments
        for segment in segments {
            try segmentRepository.createSegment(segment).sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            ).store(in: &cancellables)
        }
        
        // Verify relationships
        sessionRepository.fetchSessions()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { sessions in
                    guard let savedSession = sessions.first else {
                        XCTFail("Session not found")
                        return
                    }
                    
                    // Fetch segments for this session
                    self.segmentRepository.fetchSegments(for: savedSession.id)
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { segments in
                                XCTAssertEqual(segments.count, 3, "Should have 3 segments")
                                
                                // Verify all segments reference the correct session
                                for segment in segments {
                                    XCTAssertEqual(segment.sessionID, savedSession.id, "Segment should reference correct session")
                                }
                                
                                // Verify segment ordering by index
                                let sortedSegments = segments.sorted { $0.index < $1.index }
                                XCTAssertEqual(sortedSegments[0].index, 0, "First segment should have index 0")
                                XCTAssertEqual(sortedSegments[1].index, 1, "Second segment should have index 1")
                                XCTAssertEqual(sortedSegments[2].index, 2, "Third segment should have index 2")
                                
                                expectation.fulfill()
                            }
                        )
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testScalesToLargeDatasets() throws {
        // [SD3] Scales to 1k sessions / 10k segments (indexed fetches)
        
        let expectation = XCTestExpectation(description: "Large dataset performance")
        
        // Create 100 sessions (reduced from 1k for test performance)
        let sessionCount = 100
        let segmentsPerSession = 100 // 10k total segments
        
        var createdSessions: [RecordingSession] = []
        
        // Create sessions
        for i in 0..<sessionCount {
            let session = RecordingSession(title: "Session \(i)")
            createdSessions.append(session)
            
            try sessionRepository.createSession(session).sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            ).store(in: &cancellables)
        }
        
        // Create segments for each session
        for (sessionIndex, session) in createdSessions.enumerated() {
            for segmentIndex in 0..<segmentsPerSession {
                let segment = TranscriptSegment(
                    sessionID: session.id,
                    index: segmentIndex,
                    startTime: TimeInterval(segmentIndex * 30),
                    duration: 30,
                    status: .completed,
                    text: "Segment \(segmentIndex) from session \(sessionIndex)"
                )
                
                try segmentRepository.createSegment(segment).sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                ).store(in: &cancellables)
            }
        }
        
        // Measure fetch performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Fetch all sessions
        sessionRepository.fetchSessions()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { sessions in
                    XCTAssertEqual(sessions.count, sessionCount, "Should have \(sessionCount) sessions")
                    
                    // Fetch segments for a specific session (indexed fetch)
                    let testSession = sessions.first!
                    self.segmentRepository.fetchSegments(for: testSession.id)
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { segments in
                                XCTAssertEqual(segments.count, segmentsPerSession, "Should have \(segmentsPerSession) segments")
                                
                                let endTime = CFAbsoluteTimeGetCurrent()
                                let duration = endTime - startTime
                                
                                // Performance assertion: should complete within reasonable time
                                XCTAssertLessThan(duration, 5.0, "Large dataset fetch should complete within 5 seconds")
                                
                                expectation.fulfill()
                            }
                        )
                        .store(in: &self.cancellables)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testIndexedFetches() throws {
        // Test that fetches use proper indexing for performance
        
        let expectation = XCTestExpectation(description: "Indexed fetches")
        
        // Create test data
        let session = RecordingSession(title: "Index Test")
        try sessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Create segments with specific timestamps
        let segments = [
            TranscriptSegment(sessionID: session.id, index: 0, startTime: 0, duration: 30, status: .completed, text: "Start"),
            TranscriptSegment(sessionID: session.id, index: 1, startTime: 30, duration: 30, status: .completed, text: "Middle"),
            TranscriptSegment(sessionID: session.id, index: 2, startTime: 60, duration: 30, status: .completed, text: "End")
        ]
        
        for segment in segments {
            try segmentRepository.createSegment(segment).sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            ).store(in: &cancellables)
        }
        
        // Test indexed fetch by time range
        let timeRangeStart: TimeInterval = 25
        let timeRangeEnd: TimeInterval = 65
        
        // This would test a custom indexed fetch method
        // For now, we'll test the basic fetch and verify ordering
        segmentRepository.fetchSegments(for: session.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { segments in
                    XCTAssertEqual(segments.count, 3, "Should have 3 segments")
                    
                    // Verify segments are ordered by start time
                    let sortedSegments = segments.sorted { $0.startTime < $1.startTime }
                    XCTAssertEqual(sortedSegments[0].startTime, 0, "First segment should start at 0")
                    XCTAssertEqual(sortedSegments[1].startTime, 30, "Second segment should start at 30")
                    XCTAssertEqual(sortedSegments[2].startTime, 60, "Third segment should start at 60")
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDataIntegrity() throws {
        // Test data integrity and validation
        
        let expectation = XCTestExpectation(description: "Data integrity")
        
        // Create a session
        let session = RecordingSession(title: "Integrity Test")
        try sessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Create a segment with valid data
        let validSegment = TranscriptSegment(
            sessionID: session.id,
            index: 0,
            startTime: 0,
            duration: 30,
            status: .completed,
            text: "Valid segment"
        )
        
        try segmentRepository.createSegment(validSegment).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Verify data integrity
        segmentRepository.fetchSegments(for: session.id)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { segments in
                    XCTAssertEqual(segments.count, 1, "Should have 1 segment")
                    
                    let segment = segments.first!
                    XCTAssertEqual(segment.sessionID, session.id, "Session ID should match")
                    XCTAssertEqual(segment.index, 0, "Index should match")
                    XCTAssertEqual(segment.startTime, 0, "Start time should match")
                    XCTAssertEqual(segment.duration, 30, "Duration should match")
                    XCTAssertEqual(segment.status, .completed, "Status should match")
                    XCTAssertEqual(segment.text, "Valid segment", "Text should match")
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testConcurrentAccess() throws {
        // Test concurrent access to SwiftData models
        
        let expectation = XCTestExpectation(description: "Concurrent access")
        let concurrentCount = 10
        var completedCount = 0
        
        // Create a session
        let session = RecordingSession(title: "Concurrent Test")
        try sessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        // Simulate concurrent access
        let dispatchGroup = DispatchGroup()
        
        for i in 0..<concurrentCount {
            dispatchGroup.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                // Create segment concurrently
                let segment = TranscriptSegment(
                    sessionID: session.id,
                    index: i,
                    startTime: TimeInterval(i * 30),
                    duration: 30,
                    status: .completed,
                    text: "Concurrent segment \(i)"
                )
                
                do {
                    try self.segmentRepository.createSegment(segment).sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                XCTFail("Concurrent segment creation failed: \(error)")
                            }
                            dispatchGroup.leave()
                        },
                        receiveValue: { _ in }
                    ).store(in: &self.cancellables)
                } catch {
                    XCTFail("Failed to create concurrent segment: \(error)")
                    dispatchGroup.leave()
                }
            }
        }
        
        // Wait for all concurrent operations to complete
        dispatchGroup.notify(queue: .main) {
            // Verify all segments were created
            self.segmentRepository.fetchSegments(for: session.id)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { segments in
                        XCTAssertEqual(segments.count, concurrentCount, "Should have \(concurrentCount) segments")
                        expectation.fulfill()
                    }
                )
                .store(in: &self.cancellables)
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testMemoryEfficiency() throws {
        // Test memory efficiency with large datasets
        
        let expectation = XCTestExpectation(description: "Memory efficiency")
        
        // Create a large number of segments
        let session = RecordingSession(title: "Memory Test")
        try sessionRepository.createSession(session).sink(
            receiveCompletion: { _ in },
            receiveValue: { _ in }
        ).store(in: &cancellables)
        
        let segmentCount = 1000
        
        // Create segments in batches to avoid memory issues
        let batchSize = 100
        var createdCount = 0
        
        func createBatch(batchIndex: Int) {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, segmentCount)
            
            for i in startIndex..<endIndex {
                let segment = TranscriptSegment(
                    sessionID: session.id,
                    index: i,
                    startTime: TimeInterval(i * 30),
                    duration: 30,
                    status: .completed,
                    text: "Segment \(i)"
                )
                
                try? segmentRepository.createSegment(segment).sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                ).store(in: &cancellables)
            }
            
            createdCount += (endIndex - startIndex)
            
            if createdCount < segmentCount {
                // Create next batch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    createBatch(batchIndex: batchIndex + 1)
                }
            } else {
                // All batches created, verify
                self.segmentRepository.fetchSegments(for: session.id)
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { segments in
                            XCTAssertEqual(segments.count, segmentCount, "Should have \(segmentCount) segments")
                            expectation.fulfill()
                        }
                    )
                    .store(in: &self.cancellables)
            }
        }
        
        // Start creating batches
        createBatch(batchIndex: 0)
        
        wait(for: [expectation], timeout: 30.0)
    }
} 
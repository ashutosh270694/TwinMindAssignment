import XCTest
import SwiftData
import Combine
@testable import TwinMindAssignment

@MainActor
final class CoreDataTests: XCTestCase {
    
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var sessionRepository: RecordingSessionRepositoryProtocol!
    private var segmentRepository: TranscriptSegmentRepositoryProtocol!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        let schema = Schema([
            RecordingSession.self,
            TranscriptSegment.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        
        sessionRepository = SwiftDataRecordingSessionRepository(modelContext: modelContext)
        segmentRepository = SwiftDataTranscriptSegmentRepository(modelContext: modelContext)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        sessionRepository = nil
        segmentRepository = nil
        
        try await super.tearDown()
    }
    
    // MARK: - SessionRepository Tests
    
    func testCreateSession() async throws {
        // Given
        let title = "Test Recording Session"
        let deviceRoute = "Built-in Microphone"
        let notes = "Test notes"
        
        let session = RecordingSession(
            title: title,
            deviceRouteAtStart: deviceRoute,
            notes: notes
        )
        
        // When
        let result = try await sessionRepository.createSession(session).async()
        
        // Then
        XCTAssertEqual(result.title, title)
        XCTAssertEqual(result.deviceRouteAtStart, deviceRoute)
        XCTAssertEqual(result.notes, notes)
        XCTAssertFalse(result.isArchived)
        XCTAssertNil(result.endedAt)
        XCTAssertNotNil(result.startedAt)
        XCTAssertTrue(result.segments.isEmpty)
        
        // Verify session is persisted
        let fetchedSessions = try await sessionRepository.fetchSessions().async()
        XCTAssertEqual(fetchedSessions.count, 1)
        XCTAssertEqual(fetchedSessions.first?.id, session.id)
    }
    
    func testCreateSessionMinimalParameters() async throws {
        // Given
        let title = "Minimal Session"
        let session = RecordingSession(title: title)
        
        // When
        let result = try await sessionRepository.createSession(session).async()
        
        // Then
        XCTAssertEqual(result.title, title)
        XCTAssertNil(result.deviceRouteAtStart)
        XCTAssertNil(result.notes)
        XCTAssertFalse(result.isArchived)
    }
    
    // MARK: - SegmentRepository Tests
    
    func testAddSegment() async throws {
        // Given
        let session = RecordingSession(title: "Test Session")
        let _ = try await sessionRepository.createSession(session).async()
        let sessionID = session.id
        let index = 0
        let startTime: TimeInterval = 0.0
        let duration: TimeInterval = 30.0
        let audioURL = URL(string: "file:///path/to/audio.m4a")
        
        let segment = TranscriptSegment(
            sessionID: sessionID,
            index: index,
            startTime: startTime,
            duration: duration,
            audioFileURL: audioURL
        )
        
        // When
        let result = try await segmentRepository.createSegment(segment).async()
        
        // Then
        XCTAssertEqual(result.sessionID, sessionID)
        XCTAssertEqual(result.index, index)
        XCTAssertEqual(result.startTime, startTime)
        XCTAssertEqual(result.duration, duration)
        XCTAssertEqual(result.audioFileURL, audioURL)
        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.transcriptText)
        XCTAssertNil(result.lastError)
        XCTAssertEqual(result.failureCount, 0)
        XCTAssertNotNil(result.createdAt)
    }
    
    func testAddSegmentMinimalParameters() async throws {
        // Given
        let session = RecordingSession(title: "Test Session")
        let _ = try await sessionRepository.createSession(session).async()
        let sessionID = session.id
        
        let segment = TranscriptSegment(
            sessionID: sessionID,
            index: 0,
            startTime: 0.0,
            duration: 15.0
        )
        
        // When
        let result = try await segmentRepository.createSegment(segment).async()
        
        // Then
        XCTAssertEqual(result.sessionID, sessionID)
        XCTAssertNil(result.audioFileURL)
        XCTAssertEqual(result.status, .pending)
    }
    
    func testAddSegmentWithInvalidSessionID() async throws {
        // Given
        let invalidSessionID = UUID()
        let segment = TranscriptSegment(
            sessionID: invalidSessionID,
            index: 0,
            startTime: 0.0,
            duration: 15.0
        )
        
        // When
        let result = try await segmentRepository.createSegment(segment).async()
        
        // Then
        XCTAssertEqual(result.sessionID, invalidSessionID)
    }
    
    // MARK: - Integration Tests
    
    func testSessionWithSegments() async throws {
        // Given
        let session = RecordingSession(title: "Session with Segments")
        let _ = try await sessionRepository.createSession(session).async()
        
        // When - Add multiple segments
        let segment1 = TranscriptSegment(
            sessionID: session.id,
            index: 0,
            startTime: 0.0,
            duration: 30.0
        )
        let _ = try await segmentRepository.createSegment(segment1).async()
        
        let segment2 = TranscriptSegment(
            sessionID: session.id,
            index: 1,
            startTime: 30.0,
            duration: 25.0
        )
        let _ = try await segmentRepository.createSegment(segment2).async()
        
        // Then - Verify relationship
        let fetchedSessions = try await sessionRepository.fetchSessions().async()
        let fetchedSession = fetchedSessions.first!
        
        XCTAssertEqual(fetchedSession.segments.count, 2)
        
        let segmentIDs = Set(fetchedSession.segments.map { $0.id })
        XCTAssertTrue(segmentIDs.contains(segment1.id))
        XCTAssertTrue(segmentIDs.contains(segment2.id))
    }
}

// MARK: - Combine Extensions for Testing

extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
} 
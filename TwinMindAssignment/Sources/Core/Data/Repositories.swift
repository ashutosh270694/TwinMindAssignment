import Foundation
import SwiftData
import Combine

// MARK: - RecordingSession Repository

/// SwiftData-backed repository for RecordingSession entities
final class SwiftDataRecordingSessionRepository: RecordingSessionRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let sessionsSubject = PassthroughSubject<[RecordingSession], Never>()
    
    // MARK: - Publishers
    
    var sessionsPublisher: AnyPublisher<[RecordingSession], Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func fetchSessions() -> AnyPublisher<[RecordingSession], Error> {
        do {
            let fetchDescriptor = FetchDescriptor<RecordingSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            let sessions = try modelContext.fetch(fetchDescriptor)
            sessionsSubject.send(sessions)
            return Just(sessions).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            sessionsSubject.send([])
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func fetchSession(id: UUID) -> AnyPublisher<RecordingSession?, Error> {
        do {
            let fetchDescriptor = FetchDescriptor<RecordingSession>(
                predicate: #Predicate<RecordingSession> { session in
                    session.id == id
                }
            )
            let sessions = try modelContext.fetch(fetchDescriptor)
            let session = sessions.first
            return Just(session).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func createSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        do {
            modelContext.insert(session)
            try modelContext.save()
            
            // Refresh and publish updated sessions
            let _ = fetchSessions()
            
            return Just(session).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func updateSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        do {
            try modelContext.save()
            
            // Refresh and publish updated sessions
            let _ = fetchSessions()
            
            return Just(session).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func deleteSession(_ session: RecordingSession) -> AnyPublisher<Void, Error> {
        do {
            modelContext.delete(session)
            try modelContext.save()
            
            // Refresh and publish updated sessions
            let _ = fetchSessions()
            
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func searchSessions(query: String) -> AnyPublisher<[RecordingSession], Error> {
        do {
            let fetchDescriptor = FetchDescriptor<RecordingSession>(
                predicate: #Predicate<RecordingSession> { session in
                    query.isEmpty || session.title.localizedStandardContains(query)
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            let sessions = try modelContext.fetch(fetchDescriptor)
            return Just(sessions).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // SwiftData automatically handles context changes
        // We'll refresh data when needed
    }
}

// MARK: - TranscriptSegment Repository

/// SwiftData-backed repository for TranscriptSegment entities
final class SwiftDataTranscriptSegmentRepository: TranscriptSegmentRepositoryProtocol {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let segmentsSubject = PassthroughSubject<[TranscriptSegment], Never>()
    
    // MARK: - Publishers
    
    var segmentsPublisher: AnyPublisher<[TranscriptSegment], Never> {
        return segmentsSubject.eraseToAnyPublisher()
    }
    
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> {
        // For now, return an empty publisher since we don't have segment closing logic yet
        return Empty().eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    func fetchSegments(for sessionID: UUID) -> AnyPublisher<[TranscriptSegment], Error> {
        do {
            let fetchDescriptor = FetchDescriptor<TranscriptSegment>(
                predicate: #Predicate<TranscriptSegment> { segment in
                    segment.sessionID == sessionID
                },
                sortBy: [SortDescriptor(\.index, order: .forward)]
            )
            let segments = try modelContext.fetch(fetchDescriptor)
            segmentsSubject.send(segments)
            return Just(segments).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            segmentsSubject.send([])
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func fetchSegment(by id: UUID) -> AnyPublisher<TranscriptSegment?, Error> {
        do {
            let fetchDescriptor = FetchDescriptor<TranscriptSegment>(
                predicate: #Predicate<TranscriptSegment> { segment in
                    segment.id == id
                }
            )
            let segments = try modelContext.fetch(fetchDescriptor)
            let segment = segments.first
            return Just(segment).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func createSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        do {
            modelContext.insert(segment)
            try modelContext.save()
            
            // Refresh and publish updated segments for the session
            let _ = fetchSegments(for: segment.sessionID)
            
            return Just(segment).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func updateSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        do {
            try modelContext.save()
            
            // Refresh and publish updated segments for the session
            let _ = fetchSegments(for: segment.sessionID)
            
            return Just(segment).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func deleteSegment(_ segment: TranscriptSegment) -> AnyPublisher<Void, Error> {
        do {
            modelContext.delete(segment)
            try modelContext.save()
            
            // Refresh and publish updated segments for the session
            let _ = fetchSegments(for: segment.sessionID)
            
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func fetchSegmentsByStatus(_ status: SegmentStatus) -> AnyPublisher<[TranscriptSegment], Error> {
        do {
            let fetchDescriptor = FetchDescriptor<TranscriptSegment>(
                predicate: #Predicate<TranscriptSegment> { segment in
                    segment.status == status
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let segments = try modelContext.fetch(fetchDescriptor)
            return Just(segments).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    func fetchPendingSegments() -> AnyPublisher<[TranscriptSegment], Error> {
        return fetchSegmentsByStatus(.pending)
    }
    
    func retrySegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        do {
            // Update segment status to retry
            segment.status = .pending
            segment.failureCount += 1
            segment.lastError = nil
            
            try modelContext.save()
            
            // Refresh and publish updated segments for the session
            let _ = fetchSegments(for: segment.sessionID)
            
            return Just(segment).setFailureType(to: Error.self).eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // SwiftData automatically handles context changes
        // We'll refresh data when needed
    }
}

// MARK: - Repository Factory

/// Factory for creating SwiftData-backed repositories
struct SwiftDataRepositoryFactory {
    
    static func createSessionRepository(modelContext: ModelContext) -> RecordingSessionRepositoryProtocol {
        return SwiftDataRecordingSessionRepository(modelContext: modelContext)
    }
    
    static func createSegmentRepository(modelContext: ModelContext) -> TranscriptSegmentRepositoryProtocol {
        return SwiftDataTranscriptSegmentRepository(modelContext: modelContext)
    }
} 
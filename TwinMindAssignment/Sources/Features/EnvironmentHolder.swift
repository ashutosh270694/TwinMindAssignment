import Foundation
import Combine
import SwiftUI

/// Protocol for recording session repository operations
protocol RecordingSessionRepositoryProtocol {
    func fetchSessions() -> AnyPublisher<[RecordingSession], Error>
    func fetchSession(id: UUID) -> AnyPublisher<RecordingSession?, Error>
    func createSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error>
    func updateSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error>
    func deleteSession(_ session: RecordingSession) -> AnyPublisher<Void, Error>
    func searchSessions(query: String) -> AnyPublisher<[RecordingSession], Error>
}

/// Protocol for transcript segment repository operations
protocol TranscriptSegmentRepositoryProtocol {
    func fetchSegments(for sessionID: UUID) -> AnyPublisher<[TranscriptSegment], Error>
    func fetchPendingSegments() -> AnyPublisher<[TranscriptSegment], Error>
    func fetchSegmentsByStatus(_ status: SegmentStatus) -> AnyPublisher<[TranscriptSegment], Error>
    func createSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error>
    func updateSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error>
    func retrySegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error>
    
    /// Publisher that emits when segments are closed and ready for processing
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> { get }
}

// MARK: - Audio Recorder Protocol
protocol AudioRecorderProtocol: ObservableObject {
    var isRecording: Bool { get }
    var recordingState: RecordingState { get }
    var levelPublisher: AnyPublisher<Float, Never> { get }
    var statePublisher: AnyPublisher<RecordingState, Never> { get }
    
    func startRecording(session: RecordingSession, segmentSink: AudioSegmentSink) async throws
    func stop() async
    func pause() async
    func resume() async
}

// MARK: - Simple Audio Recorder Implementation
class SimpleAudioRecorder: AudioRecorderProtocol {
    @Published var isRecording: Bool = false
    @Published var recordingState: RecordingState = .idle
    
    var levelPublisher: AnyPublisher<Float, Never> {
        return Just(0.5).eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<RecordingState, Never> {
        return $recordingState.eraseToAnyPublisher()
    }
    
    func startRecording(session: RecordingSession, segmentSink: AudioSegmentSink) async throws {
        await MainActor.run {
            isRecording = true
            recordingState = .recording
        }
        // In a real implementation, this would start actual audio recording
    }
    
    func stop() async {
        await MainActor.run {
            isRecording = false
            recordingState = .stopped
        }
    }
    
    func pause() async {
        await MainActor.run {
            recordingState = .paused
        }
    }
    
    func resume() async {
        await MainActor.run {
            recordingState = .recording
        }
    }
}

// MARK: - Audio Segment Sink Protocol
protocol AudioSegmentSink {
    func addPCMData(_ data: Data)
}

// MARK: - Simple Audio Segment Sink
class SimpleAudioSegmentSink: AudioSegmentSink {
    func addPCMData(_ data: Data) {
        // In a real implementation, this would process the PCM data
        // For now, just log it
        print("Received PCM data: \(data.count) bytes")
    }
}

// MARK: - Recording State Enum
enum RecordingState: Equatable {
    case idle
    case preparing
    case recording
    case paused
    case stopped
    case error(Error)
    
    static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.recording, .recording), (.paused, .paused), (.stopped, .stopped):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
    
    var isRecording: Bool {
        switch self {
        case .recording:
            return true
        default:
            return false
        }
    }
    
    var canStart: Bool {
        switch self {
        case .idle, .stopped, .error:
            return true
        default:
            return false
        }
    }
    
    var canStop: Bool {
        switch self {
        case .recording, .paused:
            return true
        default:
            return false
        }
    }
    
    var canResume: Bool {
        switch self {
        case .paused:
            return true
        default:
            return false
        }
    }
}

/// Protocol for transcription orchestration
protocol TranscriptionOrchestratorProtocol {
    var isRunning: Bool { get }
    var queueStatus: TranscriptionOrchestrator.QueueStatus { get }
    var eventsPublisher: AnyPublisher<OrchestratorEvent, Never> { get }
    
    func start() -> Void
    func stop() -> Void
    func addSegmentToQueue(_ segment: TranscriptSegment) -> Void
}

/// Protocol for network reachability
protocol ReachabilityProtocol {
    var isReachable: Bool { get }
    var connectionType: Reachability.ConnectionType { get }
    var isExpensive: Bool { get }
    var reachabilityPublisher: AnyPublisher<Bool, Never> { get }
}

/// Protocol for background task management
protocol BackgroundTaskManagerProtocol {
    var isRegistered: Bool { get }
    var isBackgroundTasksSupported: Bool { get }
    
    func registerBackgroundTasks() -> Void
    func scheduleTranscriptionProcessing(sessionID: UUID?) -> Void
    func scheduleOfflineQueueProcessing(sessionID: UUID?) -> Void
}

struct EnvironmentHolder {
    let recordingSessionRepository: RecordingSessionRepositoryProtocol
    let transcriptSegmentRepository: TranscriptSegmentRepositoryProtocol
    let audioRecorder: any AudioRecorderProtocol
    let transcriptionOrchestrator: TranscriptionOrchestratorProtocol
    let reachability: ReachabilityProtocol
    let backgroundTaskManager: BackgroundTaskManagerProtocol
    let segmentWriter: SegmentWriter
    let swiftDataStack: SwiftDataStack
    
    init(
        recordingSessionRepository: RecordingSessionRepositoryProtocol,
        transcriptSegmentRepository: TranscriptSegmentRepositoryProtocol,
        audioRecorder: any AudioRecorderProtocol,
        transcriptionOrchestrator: TranscriptionOrchestratorProtocol,
        reachability: ReachabilityProtocol,
        backgroundTaskManager: BackgroundTaskManagerProtocol,
        segmentWriter: SegmentWriter,
        swiftDataStack: SwiftDataStack
    ) {
        self.recordingSessionRepository = recordingSessionRepository
        self.transcriptSegmentRepository = transcriptSegmentRepository
        self.audioRecorder = audioRecorder
        self.transcriptionOrchestrator = transcriptionOrchestrator
        self.reachability = reachability
        self.backgroundTaskManager = backgroundTaskManager
        self.segmentWriter = segmentWriter
        self.swiftDataStack = swiftDataStack
    }
}

// MARK: - Environment Key

struct EnvironmentHolderKey: EnvironmentKey {
    static let defaultValue: EnvironmentHolder = EnvironmentHolder.createDefault()
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    var environmentHolder: EnvironmentHolder {
        get { self[EnvironmentHolderKey.self] }
        set { self[EnvironmentHolderKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func environmentHolder(_ holder: EnvironmentHolder) -> some View {
        self.environment(\.environmentHolder, holder)
    }
}

// MARK: - Environment Configuration

extension EnvironmentHolder {
    
    /// Flag to control whether to use fake implementations (for previews/testing)
    static var useFakes: Bool = false
    
    /// Creates a default environment with production implementations
    static func createDefault() -> EnvironmentHolder {
        if useFakes {
            return createForPreview()
        }
        
        do {
            let swiftDataStack = try SwiftDataStack()
            let modelContext = swiftDataStack.getContext()
            
            let sessionRepository = SwiftDataRepositoryFactory.createSessionRepository(modelContext: modelContext)
            let segmentRepository = SwiftDataRepositoryFactory.createSegmentRepository(modelContext: modelContext)
            
            let reachability = Reachability()
            let backgroundTaskManager = BackgroundTaskManager()
            let transcriptionClient = TranscriptionAPIClient()
            let speechFallback = SpeechRecognitionFallback()
            
            let orchestrator = TranscriptionOrchestrator(
                transcriptionClient: transcriptionClient,
                speechFallback: speechFallback,
                backgroundTaskManager: backgroundTaskManager,
                reachability: reachability,
                sessionRepository: sessionRepository,
                segmentRepository: segmentRepository
            )
            
            // Start the orchestrator immediately
            orchestrator.start()
            
            return EnvironmentHolder(
                recordingSessionRepository: sessionRepository,
                transcriptSegmentRepository: segmentRepository,
                audioRecorder: AudioRecorderEngine(),
                transcriptionOrchestrator: orchestrator,
                reachability: reachability,
                backgroundTaskManager: backgroundTaskManager,
                segmentWriter: SegmentWriter(),
                swiftDataStack: swiftDataStack
            )
        } catch {
            fatalError("Failed to create SwiftDataStack: \(error)")
        }
    }
    
    /// Creates an environment for SwiftUI previews
    static func createForPreview() -> EnvironmentHolder {
        do {
            let swiftDataStack = try SwiftDataStack(preview: true)
            let modelContext = swiftDataStack.getContext()
            
            return EnvironmentHolder(
                recordingSessionRepository: SwiftDataRepositoryFactory.createSessionRepository(modelContext: modelContext),
                transcriptSegmentRepository: SwiftDataRepositoryFactory.createSegmentRepository(modelContext: modelContext),
                audioRecorder: FakeAudioRecorder(),
                transcriptionOrchestrator: FakeTranscriptionOrchestrator(),
                reachability: FakeReachability(),
                backgroundTaskManager: FakeBackgroundTaskManager(),
                segmentWriter: SegmentWriter(),
                swiftDataStack: swiftDataStack
            )
        } catch {
            fatalError("Failed to create preview SwiftDataStack: \(error)")
        }
    }
    
    /// Creates an environment for testing (uses fakes)
    static func createForTesting() -> EnvironmentHolder {
        useFakes = true
        return createForPreview()
    }
}

// MARK: - In-Memory Repositories for Preview

class InMemoryRecordingSessionRepository: RecordingSessionRepositoryProtocol {
    private var sessions: [RecordingSession] = []
    
    func fetchSessions() -> AnyPublisher<[RecordingSession], Error> {
        return Just(sessions)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchSession(id: UUID) -> AnyPublisher<RecordingSession?, Error> {
        let session = sessions.first { $0.id == id }
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        sessions.append(session)
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteSession(_ session: RecordingSession) -> AnyPublisher<Void, Error> {
        sessions.removeAll { $0.id == session.id }
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func searchSessions(query: String) -> AnyPublisher<[RecordingSession], Error> {
        let filtered = sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
        return Just(filtered)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

class InMemoryTranscriptSegmentRepository: TranscriptSegmentRepositoryProtocol {
    private var segments: [TranscriptSegment] = []
    
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> {
        // For now, return an empty publisher since we don't have segment closing logic yet
        return Empty().eraseToAnyPublisher()
    }
    
    func fetchSegments(for sessionID: UUID) -> AnyPublisher<[TranscriptSegment], Error> {
        let filtered = segments.filter { $0.sessionID == sessionID }
        return Just(filtered)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchPendingSegments() -> AnyPublisher<[TranscriptSegment], Error> {
        let pending = segments.filter { $0.status == .pending }
        return Just(pending)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchSegmentsByStatus(_ status: SegmentStatus) -> AnyPublisher<[TranscriptSegment], Error> {
        let filtered = segments.filter { $0.status == status }
        return Just(filtered)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        segments.append(segment)
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        if let index = segments.firstIndex(where: { $0.id == segment.id }) {
            segments[index] = segment
        }
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func retrySegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        let updatedSegment = segment
        updatedSegment.failureCount = 0
        updatedSegment.status = .pending
        updatedSegment.lastError = nil
        
        if let index = segments.firstIndex(where: { $0.id == segment.id }) {
            segments[index] = updatedSegment
        }
        
        return Just(updatedSegment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Real Repository Implementations

class RecordingSessionRepository: RecordingSessionRepositoryProtocol {
    func fetchSessions() -> AnyPublisher<[RecordingSession], Error> {
        // In a real implementation, this would fetch from SwiftData
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchSession(id: UUID) -> AnyPublisher<RecordingSession?, Error> {
        // In a real implementation, this would fetch from SwiftData
        return Just(nil)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        // In a real implementation, this would save to SwiftData
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        // In a real implementation, this would update in SwiftData
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteSession(_ session: RecordingSession) -> AnyPublisher<Void, Error> {
        // In a real implementation, this would delete from SwiftData
        return Just(())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func searchSessions(query: String) -> AnyPublisher<[RecordingSession], Error> {
        // In a real implementation, this would search SwiftData
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

class TranscriptSegmentRepository: TranscriptSegmentRepositoryProtocol {
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> {
        // For now, return an empty publisher since we don't have segment closing logic yet
        return Empty().eraseToAnyPublisher()
    }
    
    func fetchSegments(for sessionID: UUID) -> AnyPublisher<[TranscriptSegment], Error> {
        // In a real implementation, this would fetch from SwiftData
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchPendingSegments() -> AnyPublisher<[TranscriptSegment], Error> {
        // In a real implementation, this would fetch from SwiftData
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchSegmentsByStatus(_ status: SegmentStatus) -> AnyPublisher<[TranscriptSegment], Error> {
        // In a real implementation, this would fetch from SwiftData
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        // In a real implementation, this would save to SwiftData
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        // In a real implementation, this would update in SwiftData
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func retrySegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        // In a real implementation, this would update the segment status
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

// MARK: - Fake Implementations for Preview

class FakeAudioRecorder: AudioRecorderProtocol {
    @Published var isRecording = false
    @Published var recordingState: RecordingState = .idle
    
    var levelPublisher: AnyPublisher<Float, Never> {
        return Just(0.5).eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<RecordingState, Never> {
        return $recordingState.eraseToAnyPublisher()
    }
    
    func startRecording(session: RecordingSession, segmentSink: AudioSegmentSink) async throws {
        await MainActor.run {
            isRecording = true
            recordingState = .recording
        }
    }
    
    func stop() async {
        await MainActor.run {
            isRecording = false
            recordingState = .stopped
        }
    }
    
    func pause() async {
        await MainActor.run {
            recordingState = .paused
        }
    }
    
    func resume() async {
        await MainActor.run {
            recordingState = .recording
        }
    }
}

class FakeTranscriptionOrchestrator: TranscriptionOrchestratorProtocol {
    @Published var isRunning = false
    @Published var queueStatus = TranscriptionOrchestrator.QueueStatus()
    
    var eventsPublisher: AnyPublisher<OrchestratorEvent, Never> {
        return Empty().eraseToAnyPublisher()
    }
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func addSegmentToQueue(_ segment: TranscriptSegment) {
        // No-op for preview
    }
}

class FakeReachability: ReachabilityProtocol {
    @Published var isReachable = true
    @Published var connectionType: Reachability.ConnectionType = .wifi
    @Published var isExpensive = false
    
    var reachabilityPublisher: AnyPublisher<Bool, Never> {
        return $isReachable.eraseToAnyPublisher()
    }
}

class FakeBackgroundTaskManager: BackgroundTaskManagerProtocol {
    @Published var isRegistered = false
    
    var isBackgroundTasksSupported: Bool = true
    
    func registerBackgroundTasks() {
        isRegistered = true
    }
    
    func scheduleTranscriptionProcessing(sessionID: UUID?) {
        // No-op for preview
    }
    
    func scheduleOfflineQueueProcessing(sessionID: UUID?) {
        // No-op for preview
    }
} 

// MARK: - Simple Protocol Implementations

class SimpleTranscriptionOrchestrator: TranscriptionOrchestratorProtocol {
    @Published var isRunning = false
    @Published var queueStatus = TranscriptionOrchestrator.QueueStatus()
    
    var eventsPublisher: AnyPublisher<OrchestratorEvent, Never> {
        return Empty().eraseToAnyPublisher()
    }
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func addSegmentToQueue(_ segment: TranscriptSegment) {
        // No-op for now
    }
}

class SimpleReachability: ReachabilityProtocol {
    @Published var isReachable = true
    @Published var connectionType: Reachability.ConnectionType = .wifi
    @Published var isExpensive = false
    
    var reachabilityPublisher: AnyPublisher<Bool, Never> {
        return $isReachable.eraseToAnyPublisher()
    }
}

class SimpleBackgroundTaskManager: BackgroundTaskManagerProtocol {
    @Published var isRegistered = false
    
    var isBackgroundTasksSupported: Bool = true
    
    func registerBackgroundTasks() {
        isRegistered = true
    }
    
    func scheduleTranscriptionProcessing(sessionID: UUID?) {
        // No-op for now
    }
    
    func scheduleOfflineQueueProcessing(sessionID: UUID?) {
        // No-op for now
    }
} 
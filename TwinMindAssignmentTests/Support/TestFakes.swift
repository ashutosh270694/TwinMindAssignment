import Foundation
import Combine
import SwiftUI
@testable import TwinMindAssignment

// MARK: - Fake Recording Session Repository

final class FakeRecordingSessionRepository: RecordingSessionRepositoryProtocol {
    
    private var sessions: [RecordingSession] = []
    private let sessionsSubject = PassthroughSubject<[RecordingSession], Error>()
    
    init(sessions: [RecordingSession] = []) {
        self.sessions = sessions
    }
    
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
        sessionsSubject.send(sessions)
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSession(_ session: RecordingSession) -> AnyPublisher<RecordingSession, Error> {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            sessionsSubject.send(sessions)
        }
        return Just(session)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func deleteSession(_ session: RecordingSession) -> AnyPublisher<Void, Error> {
        sessions.removeAll { $0.id == session.id }
        sessionsSubject.send(sessions)
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
    
    // MARK: - Test Support
    
    func addSession(_ session: RecordingSession) {
        sessions.append(session)
        sessionsSubject.send(sessions)
    }
    
    func clearSessions() {
        sessions.removeAll()
        sessionsSubject.send(sessions)
    }
    
    func simulateError(_ error: Error) {
        sessionsSubject.send(completion: .failure(error))
    }
}

// MARK: - Fake Transcript Segment Repository

final class FakeTranscriptSegmentRepository: TranscriptSegmentRepositoryProtocol {
    
    private var segments: [TranscriptSegment] = []
    private let segmentsSubject = PassthroughSubject<[TranscriptSegment], Error>()
    
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> {
        // For now, return an empty publisher since we don't have segment closing logic yet
        return Empty().eraseToAnyPublisher()
    }
    
    init(segments: [TranscriptSegment] = []) {
        self.segments = segments
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
        segmentsSubject.send(segments)
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        if let index = segments.firstIndex(where: { $0.id == segment.id }) {
            segments[index] = segment
            segmentsSubject.send(segments)
        }
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func retrySegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        var updatedSegment = segment
        updatedSegment.failureCount = 0
        updatedSegment.status = .pending
        updatedSegment.lastError = nil
        
        if let index = segments.firstIndex(where: { $0.id == segment.id }) {
            segments[index] = updatedSegment
            segmentsSubject.send(segments)
        }
        
        return Just(updatedSegment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Test Support
    
    func addSegment(_ segment: TranscriptSegment) {
        segments.append(segment)
        segmentsSubject.send(segments)
    }
    
    func clearSegments() {
        segments.removeAll()
        segmentsSubject.send(segments)
    }
    
    func simulateError(_ error: Error) {
        segmentsSubject.send(completion: .failure(error))
    }
}

// MARK: - Fake Audio Recorder

final class FakeAudioRecorder: AudioRecorderProtocol {
    
    @Published var isRecording = false
    @Published var recordingState: RecordingState = .idle
    
    private let levelSubject = PassthroughSubject<Float, Never>()
    private let stateSubject = PassthroughSubject<RecordingState, Never>()
    
    var levelPublisher: AnyPublisher<Float, Never> {
        return levelSubject.eraseToAnyPublisher()
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
    
    // MARK: - Test Support
    
    func simulateLevelChange(_ level: Float) {
        levelSubject.send(level)
    }
    
    func simulateRecordingState(_ state: RecordingState) {
        recordingState = state
        stateSubject.send(state)
    }
    
    func simulateError(_ error: Error) {
        // Simulate error in recording operations
    }
}

// MARK: - Fake Transcription Orchestrator

final class FakeTranscriptionOrchestrator: TranscriptionOrchestratorProtocol {
    
    @Published var isRunning = false
    @Published var queueStatus = TranscriptionOrchestrator.QueueStatus()
    
    private let eventsSubject = PassthroughSubject<OrchestratorEvent, Never>()
    
    var eventsPublisher: AnyPublisher<OrchestratorEvent, Never> {
        return eventsSubject.eraseToAnyPublisher()
    }
    
    func start() {
        isRunning = true
        eventsSubject.send(.segmentQueued(sessionID: UUID(), segmentIndex: 0))
    }
    
    func stop() {
        isRunning = false
        eventsSubject.send(.orchestratorPaused(reason: "Stopped"))
    }
    
    func addSegmentToQueue(_ segment: TranscriptSegment) {
        eventsSubject.send(.segmentQueued(sessionID: segment.sessionID, segmentIndex: segment.index))
    }
    
    // MARK: - Test Support
    
    func simulateSegmentProcessing(sessionID: UUID, segmentIndex: Int) {
        eventsSubject.send(.segmentProcessing(sessionID: sessionID, segmentIndex: segmentIndex))
    }
    
    func simulateSegmentCompleted(sessionID: UUID, segmentIndex: Int, result: TranscriptionResult) {
        eventsSubject.send(.segmentCompleted(sessionID: sessionID, segmentIndex: segmentIndex, result: result))
    }
    
    func simulateSegmentFailed(sessionID: UUID, segmentIndex: Int, error: APIError, failureCount: Int) {
        eventsSubject.send(.segmentFailed(sessionID: sessionID, segmentIndex: segmentIndex, error: error, failureCount: failureCount))
    }
    
    func simulateFallbackTriggered(sessionID: UUID, segmentIndex: Int, reason: String) {
        eventsSubject.send(.fallbackTriggered(sessionID: sessionID, segmentIndex: segmentIndex, reason: reason))
    }
    
    func simulateNetworkReachabilityChange(isReachable: Bool, connectionType: Reachability.ConnectionType) {
        eventsSubject.send(.networkReachabilityChanged(isReachable: isReachable, connectionType: connectionType))
    }
}

// MARK: - Fake Reachability

final class FakeReachability: ReachabilityProtocol {
    
    @Published var isReachable = true
    @Published var connectionType: Reachability.ConnectionType = .wifi
    @Published var isExpensive = false
    
    private let reachabilitySubject = PassthroughSubject<Bool, Never>()
    
    var reachabilityPublisher: AnyPublisher<Bool, Never> {
        return reachabilitySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Test Support
    
    func simulateNetworkChange(isReachable: Bool, connectionType: Reachability.ConnectionType = .wifi, isExpensive: Bool = false) {
        self.isReachable = isReachable
        self.connectionType = connectionType
        self.isExpensive = isExpensive
        reachabilitySubject.send(isReachable)
    }
    
    func simulateNetworkLoss() {
        simulateNetworkChange(isReachable: false, connectionType: .unknown)
    }
    
    func simulateNetworkRestoration() {
        simulateNetworkChange(isReachable: true, connectionType: .wifi)
    }
}

// MARK: - Fake Background Task Manager

final class FakeBackgroundTaskManager: BackgroundTaskManagerProtocol {
    
    @Published var isRegistered = false
    
    var isBackgroundTasksSupported: Bool = true
    
    func registerBackgroundTasks() {
        isRegistered = true
    }
    
    func scheduleTranscriptionProcessing(sessionID: UUID?) {
        // No-op for testing
    }
    
    func scheduleOfflineQueueProcessing(sessionID: UUID?) {
        // No-op for testing
    }
    
    // MARK: - Test Support
    
    func simulateRegistration() {
        isRegistered = true
    }
    
    func simulateUnregistration() {
        isRegistered = false
    }
}

// MARK: - Fake Permission Manager

final class FakePermissionManager: ObservableObject {
    
    @Published var microphonePermission: PermissionManager.PermissionState = .authorized
    @Published var speechRecognitionPermission: PermissionManager.PermissionState = .authorized
    
    private let permissionStateSubject = PassthroughSubject<PermissionManager.PermissionState, Never>()
    
    var permissionStatePublisher: AnyPublisher<PermissionManager.PermissionState, Never> {
        return Publishers.CombineLatest($microphonePermission, $speechRecognitionPermission)
            .map { mic, speech in
                if mic == .denied || speech == .denied {
                    return .denied
                } else if mic == .restricted || speech == .restricted {
                    return .restricted
                } else if mic == .authorized && speech == .authorized {
                    return .authorized
                } else if mic == .notDetermined || speech == .notDetermined {
                    return .notDetermined
                } else {
                    return .unavailable
                }
            }
            .eraseToAnyPublisher()
    }
    
    func requestMicrophonePermission() -> AnyPublisher<PermissionManager.PermissionState, Never> {
        return Just(microphonePermission)
            .eraseToAnyPublisher()
    }
    
    func requestSpeechRecognitionPermission() -> AnyPublisher<PermissionManager.PermissionState, Never> {
        return Just(speechRecognitionPermission)
            .eraseToAnyPublisher()
    }
    
    func requestAllPermissions() -> AnyPublisher<[PermissionManager.PermissionState], Never> {
        return Just([microphonePermission, speechRecognitionPermission])
            .eraseToAnyPublisher()
    }
    
    func openAppSettings() {
        // No-op for testing
    }
    
    func getPermissionState(for type: PermissionManager.PermissionType) -> PermissionManager.PermissionState {
        switch type {
        case .microphone:
            return microphonePermission
        case .speechRecognition:
            return speechRecognitionPermission
        }
    }
    
    var allPermissionsGranted: Bool {
        return microphonePermission.isAuthorized && speechRecognitionPermission.isAuthorized
    }
    
    var permissionSummary: String {
        let micStatus = "Microphone: \(microphonePermission.rawValue)"
        let speechStatus = "Speech Recognition: \(speechRecognitionPermission.rawValue)"
        return "\(micStatus), \(speechStatus)"
    }
    
    // MARK: - Test Support
    
    func simulatePermissionChange(for type: PermissionManager.PermissionType, to state: PermissionManager.PermissionState) {
        switch type {
        case .microphone:
            microphonePermission = state
        case .speechRecognition:
            speechRecognitionPermission = state
        }
    }
    
    func resetPermissionsForTesting() {
        microphonePermission = .notDetermined
        speechRecognitionPermission = .notDetermined
    }
    
    func simulatePermissionRequest(for type: PermissionManager.PermissionType, willGrant: Bool) {
        let newState: PermissionManager.PermissionState = willGrant ? .authorized : .denied
        simulatePermissionChange(for: type, to: newState)
    }
}

// MARK: - Fake Error Presenter

final class FakeErrorPresenter: ObservableObject {
    
    @Published var currentError: UserFacingError?
    @Published var errorHistory: [UserFacingError] = []
    @Published var isShowingError = false
    
    private let errorEventsSubject = PassthroughSubject<UserFacingError, Never>()
    
    let errorEvents = PassthroughSubject<UserFacingError, Never>()
    
    func presentError(_ error: UserFacingError) {
        currentError = error
        errorHistory.append(error)
        isShowingError = true
        errorEvents.send(error)
    }
    
    func dismissCurrentError() {
        currentError = nil
        isShowingError = false
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    func getErrorsByCategory(_ category: ErrorCategory) -> [UserFacingError] {
        return errorHistory.filter { $0.category == category }
    }
    
    func getErrorsBySeverity(_ severity: ErrorSeverity) -> [UserFacingError] {
        return errorHistory.filter { $0.severity == severity }
    }
    
    // MARK: - Test Support
    
    func simulateError(_ error: UserFacingError) {
        presentError(error)
    }
    
    func clearAllErrors() {
        currentError = nil
        errorHistory.removeAll()
        isShowingError = false
    }
}

// MARK: - Fake Export Service

final class FakeExportService: ObservableObject {
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportURL: URL?
    
    func exportSession(
        _ session: RecordingSession,
        options: ExportService.ExportOptions = .default
    ) -> AnyPublisher<URL, Error> {
        isExporting = true
        exportProgress = 0.0
        
        // Simulate export progress
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if self.exportProgress < 1.0 {
                    self.exportProgress += 0.1
                } else {
                    self.isExporting = false
                    self.lastExportURL = URL(fileURLWithPath: "/tmp/fake_export.txt")
                }
            }
            .store(in: &cancellables)
        
        return Just(URL(fileURLWithPath: "/tmp/fake_export.txt"))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func exportSessions(
        _ sessions: [RecordingSession],
        options: ExportService.ExportOptions = .default
    ) -> AnyPublisher<URL, Error> {
        isExporting = true
        exportProgress = 0.0
        
        // Simulate export progress
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if self.exportProgress < 1.0 {
                    self.exportProgress += 0.1
                } else {
                    self.isExporting = false
                    self.lastExportURL = URL(fileURLWithPath: "/tmp/fake_batch_export.txt")
                }
            }
            .store(in: &cancellables)
        
        return Just(URL(fileURLWithPath: "/tmp/fake_batch_export.txt"))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func shareExportedFile(_ fileURL: URL) {
        // No-op for testing
    }
    
    // MARK: - Test Support
    
    private var cancellables = Set<AnyCancellable>()
    
    func simulateExportFailure(_ error: Error) {
        isExporting = false
        exportProgress = 0.0
    }
    
    func resetExportState() {
        isExporting = false
        exportProgress = 0.0
        lastExportURL = nil
    }
}

// MARK: - Convenience Initializers

extension FakeRecordingSessionRepository {
    
    static func withSampleSessions() -> FakeRecordingSessionRepository {
        let sessions = [
            RecordingSession(title: "Test Session 1", notes: "First test session"),
            RecordingSession(title: "Test Session 2", notes: "Second test session"),
            RecordingSession(title: "Test Session 3", notes: "Third test session")
        ]
        return FakeRecordingSessionRepository(sessions: sessions)
    }
    
    static func empty() -> FakeRecordingSessionRepository {
        return FakeRecordingSessionRepository(sessions: [])
    }
}

extension FakeTranscriptSegmentRepository {
    
    static func withSampleSegments() -> FakeTranscriptSegmentRepository {
        let sessionID = UUID()
        let segments = [
            TranscriptSegment(sessionID: sessionID, index: 1, startTime: 0, duration: 30.0, status: .pending),
            TranscriptSegment(sessionID: sessionID, index: 2, startTime: 30, duration: 30.0, status: .transcribed),
            TranscriptSegment(sessionID: sessionID, index: 3, startTime: 60, duration: 30.0, status: .failed)
        ]
        return FakeTranscriptSegmentRepository(segments: segments)
    }
    
    static func empty() -> FakeTranscriptSegmentRepository {
        return FakeTranscriptSegmentRepository(segments: [])
    }
}

extension FakeAudioRecorder {
    
    static func recording() -> FakeAudioRecorder {
        let recorder = FakeAudioRecorder()
        recorder.isRecording = true
        recorder.recordingState = .recording
        return recorder
    }
    
    static func idle() -> FakeAudioRecorder {
        let recorder = FakeAudioRecorder()
        recorder.isRecording = false
        recorder.recordingState = .idle
        return recorder
    }
}

extension FakeTranscriptionOrchestrator {
    
    static func running() -> FakeTranscriptionOrchestrator {
        let orchestrator = FakeTranscriptionOrchestrator()
        orchestrator.isRunning = true
        return orchestrator
    }
    
    static func stopped() -> FakeTranscriptionOrchestrator {
        let orchestrator = FakeTranscriptionOrchestrator()
        orchestrator.isRunning = false
        return orchestrator
    }
}

extension FakeReachability {
    
    static func online() -> FakeReachability {
        let reachability = FakeReachability()
        reachability.isReachable = true
        reachability.connectionType = .wifi
        return reachability
    }
    
    static func offline() -> FakeReachability {
        let reachability = FakeReachability()
        reachability.isReachable = false
        reachability.connectionType = .unknown
        return reachability
    }
}

extension FakePermissionManager {
    
    static func allGranted() -> FakePermissionManager {
        let manager = FakePermissionManager()
        manager.microphonePermission = .authorized
        manager.speechRecognitionPermission = .authorized
        return manager
    }
    
    static func allDenied() -> FakePermissionManager {
        let manager = FakePermissionManager()
        manager.microphonePermission = .denied
        manager.speechRecognitionPermission = .denied
        return manager
    }
    
    static func mixed() -> FakePermissionManager {
        let manager = FakePermissionManager()
        manager.microphonePermission = .authorized
        manager.speechRecognitionPermission = .denied
        return manager
    }
} 
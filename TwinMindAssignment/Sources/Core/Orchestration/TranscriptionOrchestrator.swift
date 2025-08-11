import Foundation
import Combine
import SwiftData

/// Orchestrates transcription processing with queue management and fallback strategies
final class TranscriptionOrchestrator: ObservableObject, TranscriptionOrchestratorProtocol {
    
    // MARK: - Properties
    
    /// Publisher that emits orchestrator events
    var eventsPublisher: AnyPublisher<OrchestratorEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }
    
    /// Publisher that emits current transcription segments for real-time display
    var transcriptionSegmentsPublisher: AnyPublisher<[TranscriptSegment], Never> {
        return segmentsSubject.eraseToAnyPublisher()
    }
    
    @Published var isRunning = false
    @Published var queueStatus = QueueStatus()
    
    private let eventsSubject = PassthroughSubject<OrchestratorEvent, Never>()
    private let segmentsSubject = PassthroughSubject<[TranscriptSegment], Never>()
    private let workQueue = DispatchQueue(label: "TranscriptionOrchestrator", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    // Dependencies
    private let transcriptionClient: TranscriptionAPIClient
    private let speechFallback: SpeechRecognitionFallback
    private let backgroundTaskManager: BackgroundTaskManager
    private let reachability: Reachability
    private let sessionRepository: RecordingSessionRepositoryProtocol
    private let segmentRepository: TranscriptSegmentRepositoryProtocol
    
    // Configuration
    private let maxConcurrentUploads = 3
    private let maxRetriesBeforeFallback = 5
    
    // Session tracking
    private var currentSessionID: UUID?
    
    // MARK: - Queue Status
    
    struct QueueStatus {
        var queuedCount = 0
        var processingCount = 0
        var failedCount = 0
        var completedCount = 0
        var offlineCount = 0
    }
    
    // MARK: - Initialization
    
    init(
        transcriptionClient: TranscriptionAPIClient = TranscriptionAPIClient(),
        speechFallback: SpeechRecognitionFallback = SpeechRecognitionFallback(),
        backgroundTaskManager: BackgroundTaskManager = BackgroundTaskManager(),
        reachability: Reachability = Reachability(),
        sessionRepository: RecordingSessionRepositoryProtocol,
        segmentRepository: TranscriptSegmentRepositoryProtocol
    ) {
        self.transcriptionClient = transcriptionClient
        self.speechFallback = speechFallback
        self.backgroundTaskManager = backgroundTaskManager
        self.reachability = reachability
        self.sessionRepository = sessionRepository
        self.segmentRepository = segmentRepository
        
        setupReachabilityMonitoring()
        setupRepositoryObservers()
    }
    
    // MARK: - Public Methods
    
    /// Starts the orchestrator and begins processing pending segments
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        eventsSubject.send(.orchestratorResumed)
        
        // Start processing pending segments
        processPendingSegments()
        
        print("TranscriptionOrchestrator: Started")
    }
    
    /// Stops the orchestrator and pauses processing
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        eventsSubject.send(.orchestratorPaused(reason: "Manually stopped"))
        
        print("TranscriptionOrchestrator: Stopped")
    }
    
    /// Manually adds a segment to the processing queue
    /// - Parameter segment: Segment to add to the queue
    func addSegmentToQueue(_ segment: TranscriptSegment) {
        print("TranscriptionOrchestrator: Adding segment \(segment.index) to queue")
        print("TranscriptionOrchestrator: Segment details - ID: \(segment.id), Session: \(segment.sessionID), Status: \(segment.status)")
        currentSessionID = segment.sessionID
        queueSegment(segment)
    }
    
    /// Sets the current session for real-time updates
    /// - Parameter sessionID: The session ID to track
    func setCurrentSession(_ sessionID: UUID) {
        currentSessionID = sessionID
        // Emit current segments for this session
        emitUpdatedSegments()
    }
    
    /// Gets the current queue statistics
    /// - Returns: Current queue status
    func getQueueStatus() -> QueueStatus {
        return queueStatus
    }
    
    // MARK: - Private Methods
    
    private func setupReachabilityMonitoring() {
        reachability.networkPublisher
            .sink { [weak self] status in
                self?.handleNetworkStatusChange(status)
            }
            .store(in: &cancellables)
    }
    
    private func setupRepositoryObservers() {
        // Observe pending segments from repository
        segmentRepository.fetchPendingSegments()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] segments in
                    self?.handlePendingSegmentsUpdate(segments)
                }
            )
            .store(in: &cancellables)
        
        // Subscribe to segment closed events for immediate processing
        segmentRepository.segmentClosedPublisher
            .sink { [weak self] segment in
                self?.handleSegmentClosed(segment)
            }
            .store(in: &cancellables)
    }
    
    private func handlePendingSegmentsUpdate(_ segments: [TranscriptSegment]) {
        guard isRunning else { return }
        
        // Process new pending segments
        for segment in segments {
            if segment.status == .pending {
                queueSegment(segment)
            }
        }
    }
    
    private func handleNetworkStatusChange(_ status: (isReachable: Bool, connectionType: Reachability.ConnectionType, isExpensive: Bool)) {
        let event = OrchestratorEvent.networkReachabilityChanged(
            isReachable: status.isReachable,
            connectionType: status.connectionType
        )
        eventsSubject.send(event)
        
        if status.isReachable {
            // Resume processing when network becomes available
            processOfflineQueue()
        }
    }
    
    private func queueSegment(_ segment: TranscriptSegment) {
        guard isRunning else { 
            print("TranscriptionOrchestrator: Not running, cannot queue segment \(segment.index)")
            return 
        }
        
        print("TranscriptionOrchestrator: Queueing segment \(segment.index) for processing")
        
        // Check if network is available
        if !reachability.isReachable {
            print("TranscriptionOrchestrator: Network not reachable, marking segment \(segment.index) as offline")
            // Mark as offline and schedule background task
            markSegmentAsOffline(segment)
            backgroundTaskManager.scheduleOfflineQueueProcessing(sessionID: segment.sessionID)
            return
        }
        
        // Update queue status
        queueStatus.queuedCount += 1
        updateQueueStatus()
        
        // Emit event
        eventsSubject.send(.segmentQueued(sessionID: segment.sessionID, segmentIndex: segment.index))
        
        // Process the segment
        processSegment(segment)
    }
    
    private func handleSegmentClosed(_ segment: TranscriptSegment) {
        // Immediately queue the segment for processing
        queueSegment(segment)
        
        // Emit event for UI updates
        eventsSubject.send(.segmentClosed(sessionID: segment.sessionID, segmentIndex: segment.index))
    }
    
    private func processSegment(_ segment: TranscriptSegment) {
        print("TranscriptionOrchestrator: Processing segment \(segment.index)")
        
        guard let audioFileURL = segment.audioFileURL else {
            print("TranscriptionOrchestrator: No audio file URL for segment \(segment.index)")
            handleSegmentFailure(segment, error: APIError.fileNotFound, failureCount: segment.failureCount)
            return
        }
        
        print("TranscriptionOrchestrator: Audio file URL: \(audioFileURL.path)")
        
        // Update status to uploading
        updateSegmentStatus(segment, status: .uploading)
        
        // Update queue status
        queueStatus.queuedCount -= 1
        queueStatus.processingCount += 1
        updateQueueStatus()
        
        // Emit processing event
        eventsSubject.send(.segmentProcessing(sessionID: segment.sessionID, segmentIndex: segment.index))
        
        // Read audio data and create transcription request
        do {
            let audioData = try Data(contentsOf: audioFileURL)
            print("TranscriptionOrchestrator: Read \(audioData.count) bytes from audio file")
            
            let request = TranscriptionAPIClient.TranscriptionRequest(
                audioData: audioData,
                segmentIndex: segment.index,
                sessionID: segment.sessionID
            )
            
            print("TranscriptionOrchestrator: Sending transcription request for segment \(segment.index)")
            
            // Attempt transcription via API
            transcriptionClient.transcribe(request)
                .flatMap(maxPublishers: .max(maxConcurrentUploads)) { [weak self] result in
                    // Success - update segment and emit completion event
                    print("TranscriptionOrchestrator: Transcription successful for segment \(segment.index): '\(result.text)'")
                    self?.handleSegmentSuccess(segment, result: result)
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }
                .catch { [weak self] error in
                    // Failure - handle based on error type and retry count
                    print("TranscriptionOrchestrator: Transcription failed for segment \(segment.index): \(error.localizedDescription)")
                    self?.handleSegmentFailure(segment, error: error, failureCount: segment.failureCount)
                    return Empty<Void, Never>().eraseToAnyPublisher()
                }
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        } catch {
            // Handle file reading error
            print("TranscriptionOrchestrator: Failed to read audio file for segment \(segment.index): \(error.localizedDescription)")
            handleSegmentFailure(segment, error: error, failureCount: segment.failureCount)
        }
    }
    
    private func handleSegmentSuccess(_ segment: TranscriptSegment, result: TranscriptionResult) {
        // Update queue status
        queueStatus.processingCount -= 1
        queueStatus.completedCount += 1
        updateQueueStatus()
        
        // Emit completion event
        eventsSubject.send(.segmentCompleted(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            result: result
        ))
        
        // Update segment in database
        updateSegmentStatus(segment, status: .transcribed, transcriptText: result.text)
    }
    
    private func handleSegmentFailure(_ segment: TranscriptSegment, error: Error, failureCount: Int) {
        let newFailureCount = failureCount + 1
        
        // Update queue status
        queueStatus.processingCount -= 1
        
        if newFailureCount >= maxRetriesBeforeFallback {
            // Max retries exceeded - try fallback
            queueStatus.failedCount += 1
            tryFallbackTranscription(segment)
        } else {
            // Retry with exponential backoff
            queueStatus.queuedCount += 1
            scheduleRetry(segment, failureCount: newFailureCount)
        }
        
        updateQueueStatus()
        
        // Convert error to APIError if needed
        let apiError: APIError
        if let transcriptionError = error as? TranscriptionAPIClient.TranscriptionError {
            switch transcriptionError {
            case .missingToken:
                apiError = .invalidToken
            case .invalidResponse:
                apiError = .invalidResponse
            case .networkError:
                apiError = .networkError(error)
            case .httpError(let code):
                apiError = .invalidStatusCode(code)
            case .maxRetriesExceeded:
                apiError = .requestTimeout
            }
        } else {
            apiError = .networkError(error)
        }
        
        // Emit failure event
        eventsSubject.send(.segmentFailed(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            error: apiError,
            failureCount: newFailureCount
        ))
        
        // Update segment failure count
        updateSegmentFailureCount(segment, failureCount: newFailureCount)
    }
    
    private func markSegmentAsOffline(_ segment: TranscriptSegment) {
        // Update segment status to offline
        updateSegmentStatus(segment, status: .queuedOffline)
        
        // Update queue status
        queueStatus.offlineCount += 1
        updateQueueStatus()
        
        // Emit offline event
        eventsSubject.send(.segmentQueuedOffline(
            sessionID: segment.sessionID,
            segmentIndex: segment.index
        ))
    }
    
    private func tryFallbackTranscription(_ segment: TranscriptSegment) {
        guard let audioFileURL = segment.audioFileURL else {
            // No audio file - mark as failed
            updateSegmentStatus(segment, status: .failed, lastError: "No audio file available")
            return
        }
        
        // Emit fallback event
        eventsSubject.send(.fallbackTriggered(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            reason: "Max retries exceeded, using Apple SFSpeechRecognizer"
        ))
        
        // Attempt fallback transcription
        speechFallback.transcribe(audioFileURL: audioFileURL)
            .sink(
                receiveCompletion: { [weak self] completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        self?.handleFallbackFailure(segment, error: error)
                    }
                },
                receiveValue: { [weak self] transcriptText in
                    self?.handleFallbackSuccess(segment, transcriptText: transcriptText)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleFallbackSuccess(_ segment: TranscriptSegment, transcriptText: String) {
        // Update queue status
        queueStatus.failedCount -= 1
        queueStatus.completedCount += 1
        updateQueueStatus()
        
        // Emit fallback completion event
        eventsSubject.send(.fallbackCompleted(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            result: transcriptText
        ))
        
        // Update segment status
        updateSegmentStatus(segment, status: .transcribed, transcriptText: transcriptText)
    }
    
    private func handleFallbackFailure(_ segment: TranscriptSegment, error: Error) {
        // Emit fallback failure event
        eventsSubject.send(.fallbackFailed(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            error: error
        ))
        
        // Mark segment as failed
        updateSegmentStatus(segment, status: .failed, lastError: error.localizedDescription)
    }
    
    private func scheduleRetry(_ segment: TranscriptSegment, failureCount: Int) {
        // Calculate retry delay with exponential backoff and jitter
        let baseDelay = TimeInterval(pow(2.0, Double(failureCount)))
        let jitter = Double.random(in: 0.8...1.2)
        let delay = baseDelay * jitter
        
        // Emit retry event
        eventsSubject.send(.segmentRetried(
            sessionID: segment.sessionID,
            segmentIndex: segment.index,
            attempt: failureCount
        ))
        
        // Schedule retry
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.processSegment(segment)
        }
    }
    
    private func processOfflineQueue() {
        // Fetch offline segments and process them
        segmentRepository.fetchSegmentsByStatus(.queuedOffline)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] offlineSegments in
                    for segment in offlineSegments {
                        // Mark as pending to be processed
                        self?.updateSegmentStatus(segment, status: .pending)
                        self?.queueStatus.offlineCount -= 1
                    }
                    self?.updateQueueStatus()
                }
            )
            .store(in: &cancellables)
    }
    
    private func processPendingSegments() {
        // Fetch and process pending segments
        segmentRepository.fetchPendingSegments()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] pendingSegments in
                    for segment in pendingSegments {
                        self?.queueSegment(segment)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func updateQueueStatus() {
        eventsSubject.send(.queueStatusChanged(
            queuedCount: queueStatus.queuedCount,
            processingCount: queueStatus.processingCount,
            failedCount: queueStatus.failedCount
        ))
    }
    
    // MARK: - Database Operations
    
    private func updateSegmentStatus(_ segment: TranscriptSegment, status: SegmentStatus, transcriptText: String? = nil, lastError: String? = nil) {
        segment.status = status
        if let transcriptText = transcriptText {
            segment.transcriptText = transcriptText
        }
        if let lastError = lastError {
            segment.lastError = lastError
        }
        
        // Update in repository on main thread
        Task { @MainActor in
            segmentRepository.updateSegment(segment)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] _ in
                        // Emit updated segments for real-time display
                        self?.emitUpdatedSegments()
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func updateSegmentFailureCount(_ segment: TranscriptSegment, failureCount: Int) {
        segment.failureCount = failureCount
        
        // Update in repository on main thread
        Task { @MainActor in
            segmentRepository.updateSegment(segment)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { [weak self] _ in
                        // Emit updated segments for real-time display
                        self?.emitUpdatedSegments()
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func emitUpdatedSegments() {
        // Fetch and emit current segments for real-time display on main thread
        segmentRepository.fetchSegments(for: currentSessionID ?? UUID())
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] segments in
                    DispatchQueue.main.async {
                        self?.segmentsSubject.send(segments)
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - Convenience Extensions

extension TranscriptionOrchestrator {
    
    /// Returns true if the orchestrator is ready to process segments
    var isReady: Bool {
        return isRunning && reachability.isReachable
    }
    
    /// Gets a summary of the current processing status
    var statusSummary: String {
        return "Queue: \(queueStatus.queuedCount), Processing: \(queueStatus.processingCount), Failed: \(queueStatus.failedCount), Completed: \(queueStatus.completedCount), Offline: \(queueStatus.offlineCount)"
    }
}

// MARK: - Testing Support

extension TranscriptionOrchestrator {
    
    #if DEBUG
    /// Simulates processing a segment for testing
    /// - Parameter segment: Segment to simulate processing
    func simulateSegmentProcessing(_ segment: TranscriptSegment) {
        queueSegment(segment)
    }
    
    /// Resets the orchestrator state for testing
    func resetForTesting() {
        isRunning = false
        queueStatus = QueueStatus()
        cancellables.removeAll()
    }
    #endif
} 
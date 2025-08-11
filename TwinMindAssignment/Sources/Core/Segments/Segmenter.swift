import Foundation
import Combine
import AVFoundation

/// Manages audio segmentation with configurable chunk duration
final class Segmenter: ObservableObject {
    
    // MARK: - Types
    
    enum SegmenterError: LocalizedError {
        case segmentWriterNotAvailable
        case failedToWriteSegment
        case invalidPCMData
        
        var errorDescription: String? {
            switch self {
            case .segmentWriterNotAvailable:
                return "Segment writer not available"
            case .failedToWriteSegment:
                return "Failed to write audio segment"
            case .invalidPCMData:
                return "Invalid PCM audio data"
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var currentSegmentDuration: TimeInterval = 0
    @Published var totalSegmentsCreated: Int = 0
    
    // MARK: - Publishers
    
    /// Publisher that emits when a segment is closed and ready for processing
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> {
        return segmentWriter.segmentClosedPublisher
    }
    
    // MARK: - Properties
    
    private let segmentDuration: TimeInterval
    private let sampleRate: Double
    private let channels: Int
    
    private var currentSegmentStartTime: TimeInterval = 0
    private var currentSegmentPCMData: Data = Data()
    private var currentSession: RecordingSession?
    
    private let segmentWriter: SegmentWriter
    private let segmentRepository: TranscriptSegmentRepositoryProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        segmentDuration: TimeInterval = AppConfig.debugSegmentDuration ?? 30.0,
        sampleRate: Double = 16000,
        channels: Int = 1,
        segmentWriter: SegmentWriter
    ) {
        self.segmentDuration = segmentDuration
        self.sampleRate = sampleRate
        self.channels = channels
        self.segmentWriter = segmentWriter
        self.segmentRepository = segmentWriter // Use SegmentWriter as repository
        
        setupTimers()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    
    /// Starts a new recording session
    func startSession(_ session: RecordingSession) {
        currentSession = session
        currentSegmentStartTime = Date().timeIntervalSince1970
        currentSegmentPCMData = Data()
        currentSegmentDuration = 0
        totalSegmentsCreated = 0
        
        print("Segmenter: Started new session: \(session.id)")
    }
    
    /// Adds PCM data to the current segment
    func addPCMData(_ data: Data) {
        guard currentSession != nil else {
            print("Segmenter: No active session")
            return
        }
        
        print("Segmenter: Received \(data.count) bytes of PCM data")
        currentSegmentPCMData.append(data)
        currentSegmentDuration = Date().timeIntervalSince1970 - currentSegmentStartTime
        
        print("Segmenter: Current segment duration: \(String(format: "%.1f", currentSegmentDuration))s, data size: \(currentSegmentPCMData.count) bytes")
        
        // Check if we need to close the current segment
        if currentSegmentDuration >= segmentDuration {
            print("Segmenter: Closing segment due to duration threshold")
            closeCurrentSegment()
        }
    }
    
    /// Manually closes the current segment
    func closeCurrentSegment() {
        guard let session = currentSession,
              !currentSegmentPCMData.isEmpty else {
            return
        }
        
        Task {
            do {
                let segmentIndex = totalSegmentsCreated
                let segmentURL = try segmentWriter.writeSegment(
                    pcmData: currentSegmentPCMData,
                    sessionID: session.id,
                    segmentIndex: segmentIndex,
                    segmentDuration: currentSegmentDuration,
                    sampleRate: sampleRate,
                    channels: channels
                )
                
                // Create transcript segment
                let transcriptSegment = TranscriptSegment(
                    id: UUID(),
                    sessionID: session.id,
                    index: segmentIndex,
                    startTime: currentSegmentStartTime,
                    duration: currentSegmentDuration,
                    audioFileURL: segmentURL,
                    transcriptText: nil,
                    status: .pending,
                    lastError: nil,
                    failureCount: 0,
                    createdAt: Date(),
                    session: nil
                )
                
                // Persist the segment (in a real app, this would go to a database)
                await persistTranscriptSegment(transcriptSegment)
                
                // Update segment count
                await MainActor.run {
                    self.totalSegmentsCreated += 1
                }
                
                print("Segmenter: Created segment \(segmentIndex) at \(segmentURL)")
                
            } catch {
                print("Segmenter: Failed to create segment: \(error)")
                
                // Emit error segment for error handling
                let _ = TranscriptSegment(
                    id: UUID(),
                    sessionID: session.id,
                    index: totalSegmentsCreated,
                    startTime: currentSegmentStartTime,
                    duration: currentSegmentDuration,
                    audioFileURL: nil,
                    transcriptText: nil,
                    status: .failed,
                    lastError: error.localizedDescription,
                    failureCount: 1,
                    createdAt: Date(),
                    session: nil
                )
                
                // Error segment created for error handling
            }
        }
        
        // Reset for next segment
        startNewSegment()
    }
    
    /// Stops the current session and closes any remaining data
    func stopSession() {
        // Close any remaining data as the final segment
        if !currentSegmentPCMData.isEmpty {
            closeCurrentSegment()
        }
        
        currentSession = nil
        currentSegmentPCMData = Data()
        currentSegmentDuration = 0
        
        print("Segmenter: Stopped session")
    }
    
    /// Pauses the current session
    func pauseSession() {
        // Close current segment if it has data
        if !currentSegmentPCMData.isEmpty {
            closeCurrentSegment()
        }
        
        print("Segmenter: Paused session")
    }
    
    /// Resumes the current session
    func resumeSession() {
        startNewSegment()
        print("Segmenter: Resumed session")
    }
    
    /// Gets the current session info
    var currentSessionInfo: (session: RecordingSession?, duration: TimeInterval, segments: Int)? {
        guard let session = currentSession else { return nil }
        return (session, currentSegmentDuration, totalSegmentsCreated)
    }
    
    // MARK: - Private Methods
    
    private func startNewSegment() {
        currentSegmentStartTime = Date().timeIntervalSince1970
        currentSegmentPCMData = Data()
        currentSegmentDuration = 0
    }
    
    private func setupTimers() {
        // Timer to check segment duration every second
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSegmentDuration()
            }
            .store(in: &cancellables)
    }
    
    private func updateSegmentDuration() {
        guard currentSession != nil else { return }
        currentSegmentDuration = Date().timeIntervalSince1970 - currentSegmentStartTime
    }
    
    private func persistTranscriptSegment(_ segment: TranscriptSegment) async {
        // Use SwiftData repository to persist the segment on main thread
        await MainActor.run {
            segmentRepository.createSegment(segment)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            print("Segmenter: Persisted segment \(segment.index) for session \(segment.sessionID)")
                        case .failure(let error):
                            print("Segmenter: Failed to persist segment: \(error)")
                        }
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
    }
    
    private func cleanup() {
        cancellables.removeAll()
    }
}

// MARK: - Convenience Extensions

extension Segmenter {
    /// Creates a segmenter with default settings (30s segments, 16kHz mono)
    static func createDefault(
        segmentWriter: SegmentWriter
    ) -> Segmenter {
        return Segmenter(
            segmentDuration: AppConfig.debugSegmentDuration ?? 30.0,
            sampleRate: 16000,
            channels: 1,
            segmentWriter: segmentWriter
        )
    }
    
    /// Creates a segmenter with custom settings
    static func createCustom(
        duration: TimeInterval,
        sampleRate: Double,
        channels: Int,
        segmentWriter: SegmentWriter
    ) -> Segmenter {
        return Segmenter(
            segmentDuration: duration,
            sampleRate: sampleRate,
            channels: channels,
            segmentWriter: segmentWriter
        )
    }
} 
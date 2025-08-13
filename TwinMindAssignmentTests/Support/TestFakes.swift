//
//  TestFakes.swift
//  TwinMindAssignmentTests
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh, DobbyFactory. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import Foundation
import Combine
@testable import TwinMindAssignment

/// Test fakes and mocks for unit testing
/// 
/// Provides fake implementations of protocols and dependencies
/// to enable isolated unit testing without external dependencies.
/// All fakes follow the XCTest Hygiene rules:
/// - Deterministic behavior
/// - Clear state management
/// - Easy verification
/// - No side effects

// MARK: - Fake Audio Recorder

/// Fake implementation of AudioRecorderProtocol for testing
final class FakeAudioRecorder: AudioRecorderProtocol {
    
    // MARK: - Published Properties
    
    @Published var isRecording: Bool = false
    @Published var recordingState: RecordingState = .idle
    
    // MARK: - Publishers
    
    var levelPublisher: AnyPublisher<Float, Never> {
        return Just(0.5).eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<RecordingState, Never> {
        return $recordingState.eraseToAnyPublisher()
    }
    
    // MARK: - Test Control
    
    /// Simulates starting recording
    func startRecording(session: RecordingSession, segmentSink: AudioSegmentSink) async throws {
        await MainActor.run {
            isRecording = true
            recordingState = .recording
        }
    }
    
    /// Simulates stopping recording
    func stop() async {
        await MainActor.run {
            isRecording = false
            recordingState = .stopped
        }
    }
    
    /// Simulates pausing recording
    func pause() async {
        await MainActor.run {
            recordingState = .paused
        }
    }
    
    /// Simulates resuming recording
    func resume() async {
        await MainActor.run {
            recordingState = .recording
        }
    }
    
    // MARK: - Test Helpers
    
    /// Resets the fake to initial state
    func reset() {
        isRecording = false
        recordingState = .idle
    }
    
    /// Simulates a recording error
    func simulateError(_ error: RecordingError) {
        // In a real implementation, this would trigger error handling
        print("FakeAudioRecorder: Simulating error: \(error)")
    }
}

// MARK: - Fake Permission Manager

/// Fake implementation of PermissionManager for testing
final class FakePermissionManager: PermissionManager {
    
    // MARK: - Test State
    
    private var simulatedMicrophonePermission: AVAudioSession.RecordPermission = .undetermined
    private var simulatedSpeechPermission: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    
    // MARK: - Test Control
    
    /// Simulates a permission change
    func simulatePermissionChange(microphone: AVAudioSession.RecordPermission, speech: SFSpeechRecognizerAuthorizationStatus) {
        simulatedMicrophonePermission = microphone
        simulatedSpeechPermission = speech
    }
    
    /// Simulates opening app settings
    func openAppSettings() {
        print("FakePermissionManager: Simulating opening app settings")
    }
    
    // MARK: - Overridden Methods
    
    override var microphonePermissionStatus: AVAudioSession.RecordPermission {
        return simulatedMicrophonePermission
    }
    
    override var speechRecognitionPermissionStatus: SFSpeechRecognizerAuthorizationStatus {
        return simulatedSpeechPermission
    }
    
    override func requestMicrophonePermission() -> AnyPublisher<Bool, Never> {
        return Just(simulatedMicrophonePermission == .granted)
            .eraseToAnyPublisher()
    }
    
    override func requestSpeechRecognitionPermission() -> AnyPublisher<SFSpeechRecognizerAuthorizationStatus, Never> {
        return Just(simulatedSpeechPermission)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Test Helpers
    
    /// Resets the fake to initial state
    func reset() {
        simulatedMicrophonePermission = .undetermined
        simulatedSpeechPermission = .notDetermined
    }
}

// MARK: - Fake Transcription Orchestrator

/// Fake implementation of TranscriptionOrchestrator for testing
final class FakeTranscriptionOrchestrator: TranscriptionOrchestratorProtocol {
    
    // MARK: - Test State
    
    private var isRunning: Bool = false
    private var queuedSegments: [TranscriptSegment] = []
    private var processingSegments: [TranscriptSegment] = []
    private var completedSegments: [TranscriptSegment] = []
    private var failedSegments: [TranscriptSegment] = []
    
    // MARK: - Test Control
    
    /// Simulates starting the orchestrator
    func start() async throws {
        isRunning = true
        print("FakeTranscriptionOrchestrator: Started")
    }
    
    /// Simulates stopping the orchestrator
    func stop() async {
        isRunning = false
        print("FakeTranscriptionOrchestrator: Stopped")
    }
    
    /// Simulates enqueueing a segment
    func enqueueSegment(_ segment: TranscriptSegment) async throws {
        queuedSegments.append(segment)
        print("FakeTranscriptionOrchestrator: Enqueued segment \(segment.index)")
    }
    
    /// Simulates processing a segment
    func processSegment(_ segment: TranscriptSegment) async throws {
        guard let index = queuedSegments.firstIndex(where: { $0.id == segment.id }) else {
            throw TranscriptionError.invalidRequest
        }
        
        queuedSegments.remove(at: index)
        processingSegments.append(segment)
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Move to completed
        if let processingIndex = processingSegments.firstIndex(where: { $0.id == segment.id }) {
            processingSegments.remove(at: processingIndex)
            completedSegments.append(segment)
        }
        
        print("FakeTranscriptionOrchestrator: Processed segment \(segment.index)")
    }
    
    // MARK: - Test Helpers
    
    /// Returns the count of queued segments
    var queuedCount: Int {
        return queuedSegments.count
    }
    
    /// Returns the count of processing segments
    var processingCount: Int {
        return processingSegments.count
    }
    
    /// Returns the count of completed segments
    var completedCount: Int {
        return completedSegments.count
    }
    
    /// Returns the count of failed segments
    var failedCount: Int {
        return failedSegments.count
    }
    
    /// Resets the fake to initial state
    func reset() {
        isRunning = false
        queuedSegments.removeAll()
        processingSegments.removeAll()
        completedSegments.removeAll()
        failedSegments.removeAll()
    }
    
    /// Simulates a failure for a specific segment
    func simulateFailure(for segment: TranscriptSegment, error: Error) {
        if let index = processingSegments.firstIndex(where: { $0.id == segment.id }) {
            processingSegments.remove(at: index)
            failedSegments.append(segment)
        }
    }
}

// MARK: - Fake Reachability

/// Fake implementation of Reachability for testing
final class FakeReachability: ReachabilityProtocol {
    
    // MARK: - Test State
    
    private var isReachable: Bool = true
    private var connectionType: ConnectionType = .wifi
    private var isExpensive: Bool = false
    
    // MARK: - Test Control
    
    /// Simulates a network change
    func simulateNetworkChange(isReachable: Bool, connectionType: ConnectionType = .wifi, isExpensive: Bool = false) {
        self.isReachable = isReachable
        self.connectionType = connectionType
        self.isExpensive = isExpensive
        
        // Notify observers
        NotificationCenter.default.post(
            name: .reachabilityChanged,
            object: self,
            userInfo: [
                "isReachable": isReachable,
                "connectionType": connectionType,
                "isExpensive": isExpensive
            ]
        )
    }
    
    // MARK: - Protocol Implementation
    
    var isReachablePublisher: AnyPublisher<Bool, Never> {
        return Just(isReachable).eraseToAnyPublisher()
    }
    
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        return Just(connectionType).eraseToAnyPublisher()
    }
    
    var isExpensivePublisher: AnyPublisher<Bool, Never> {
        return Just(isExpensive).eraseToAnyPublisher()
    }
    
    // MARK: - Test Helpers
    
    /// Resets the fake to initial state
    func reset() {
        isReachable = true
        connectionType = .wifi
        isExpensive = false
    }
}

// MARK: - Fake Background Task Manager

/// Fake implementation of BackgroundTaskManager for testing
final class FakeBackgroundTaskManager: BackgroundTaskManagerProtocol {
    
    // MARK: - Test State
    
    private var isBackgroundTasksSupported: Bool = true
    private var scheduledTasks: [String: Bool] = [:]
    
    // MARK: - Test Control
    
    /// Simulates background task support change
    func simulateBackgroundTaskSupport(_ supported: Bool) {
        isBackgroundTasksSupported = supported
    }
    
    /// Simulates scheduling a background task
    func simulateScheduleTask(_ identifier: String) {
        scheduledTasks[identifier] = true
    }
    
    // MARK: - Protocol Implementation
    
    func scheduleTranscriptionProcessingTask() async throws -> Bool {
        let identifier = "transcription_processing"
        scheduledTasks[identifier] = true
        return isBackgroundTasksSupported
    }
    
    func scheduleOfflineQueueProcessingTask() async throws -> Bool {
        let identifier = "offline_queue_processing"
        scheduledTasks[identifier] = true
        return isBackgroundTasksSupported
    }
    
    func scheduleCleanupTask() async throws -> Bool {
        let identifier = "cleanup"
        scheduledTasks[identifier] = true
        return isBackgroundTasksSupported
    }
    
    // MARK: - Test Helpers
    
    /// Returns whether a task is scheduled
    func isTaskScheduled(_ identifier: String) -> Bool {
        return scheduledTasks[identifier] ?? false
    }
    
    /// Returns all scheduled task identifiers
    var scheduledTaskIdentifiers: [String] {
        return Array(scheduledTasks.keys)
    }
    
    /// Resets the fake to initial state
    func reset() {
        isBackgroundTasksSupported = true
        scheduledTasks.removeAll()
    }
}

// MARK: - Fake Segment Writer

/// Fake implementation of SegmentWriter for testing
final class FakeSegmentWriter: SegmentWriterProtocol {
    
    // MARK: - Test State
    
    private var writtenSegments: [String: Data] = [:]
    private var shouldFail: Bool = false
    private var failureError: Error = SegmentWriterError.insufficientDiskSpace
    
    // MARK: - Test Control
    
    /// Simulates a write failure
    func simulateFailure(_ error: Error) {
        shouldFail = true
        failureError = error
    }
    
    /// Simulates successful writes
    func simulateSuccess() {
        shouldFail = false
    }
    
    // MARK: - Protocol Implementation
    
    func writeSegment(_ data: Data, sessionID: UUID, segmentIndex: Int, segmentDuration: TimeInterval, channels: Int) async throws -> URL {
        if shouldFail {
            throw failureError
        }
        
        let key = "\(sessionID.uuidString)_\(segmentIndex)"
        writtenSegments[key] = data
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fake_segment_\(sessionID.uuidString)_\(segmentIndex).m4a")
        
        return tempURL
    }
    
    func deleteSession(_ sessionID: UUID) throws {
        // Remove all segments for this session
        let keysToRemove = writtenSegments.keys.filter { $0.hasPrefix(sessionID.uuidString) }
        for key in keysToRemove {
            writtenSegments.removeValue(forKey: key)
        }
    }
    
    func sessionExists(_ sessionID: UUID) -> Bool {
        return writtenSegments.keys.contains { $0.hasPrefix(sessionID.uuidString) }
    }
    
    // MARK: - Test Helpers
    
    /// Returns the data for a specific segment
    func getSegmentData(sessionID: UUID, segmentIndex: Int) -> Data? {
        let key = "\(sessionID.uuidString)_\(segmentIndex)"
        return writtenSegments[key]
    }
    
    /// Returns the count of written segments
    var writtenSegmentCount: Int {
        return writtenSegments.count
    }
    
    /// Resets the fake to initial state
    func reset() {
        writtenSegments.removeAll()
        shouldFail = false
        failureError = SegmentWriterError.insufficientDiskSpace
    }
}

// MARK: - Test Utilities

/// Utility functions for testing
enum TestUtilities {
    
    /// Creates a test session with specified parameters
    static func createTestSession(
        title: String = "Test Session",
        startedAt: Date = Date(),
        segments: [TranscriptSegment] = []
    ) -> RecordingSession {
        let session = RecordingSession(title: title, startedAt: startedAt)
        session.segments = segments
        return session
    }
    
    /// Creates a test segment with specified parameters
    static func createTestSegment(
        sessionID: UUID = UUID(),
        index: Int = 0,
        startAt: Date = Date(),
        endAt: Date? = nil,
        status: SegmentStatus = .queued
    ) -> TranscriptSegment {
        let segment = TranscriptSegment(
            sessionID: sessionID,
            index: index,
            startAt: startAt,
            endAt: endAt ?? startAt.addingTimeInterval(30)
        )
        segment.status = status
        return segment
    }
    
    /// Waits for a specified duration (useful for testing async operations)
    static func wait(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    /// Creates test audio data
    static func createTestAudioData(sampleRate: Double = 16000, duration: TimeInterval = 1.0) -> Data {
        let frameCount = Int(sampleRate * duration)
        let sampleCount = frameCount * 4 // 32-bit float samples
        return Data(repeating: 0, count: sampleCount)
    }
} 
import Foundation

/// Represents various events that can occur during transcription orchestration
enum OrchestratorEvent {
    
    // MARK: - Queue Management Events
    
    /// A segment has been added to the work queue
    case segmentQueued(sessionID: UUID, segmentIndex: Int)
    
    /// A segment has been closed and is ready for processing
    case segmentClosed(sessionID: UUID, segmentIndex: Int)
    
    /// A segment has started processing
    case segmentProcessing(sessionID: UUID, segmentIndex: Int)
    
    /// A segment has completed processing successfully
    case segmentCompleted(sessionID: UUID, segmentIndex: Int, result: TranscriptionResult)
    
    /// A segment has failed processing
    case segmentFailed(sessionID: UUID, segmentIndex: Int, error: APIError, failureCount: Int)
    
    /// A segment has been queued for offline processing
    case segmentQueuedOffline(sessionID: UUID, segmentIndex: Int)
    
    /// A segment has been retried after failure
    case segmentRetried(sessionID: UUID, segmentIndex: Int, attempt: Int)
    
    // MARK: - Fallback Events
    
    /// Fallback to Apple SFSpeechRecognizer has been triggered
    case fallbackTriggered(sessionID: UUID, segmentIndex: Int, reason: String)
    
    /// Fallback processing has completed
    case fallbackCompleted(sessionID: UUID, segmentIndex: Int, result: String)
    
    /// Fallback processing has failed
    case fallbackFailed(sessionID: UUID, segmentIndex: Int, error: Error)
    
    // MARK: - Background Processing Events
    
    /// Background task has been scheduled
    case backgroundTaskScheduled(taskID: String, sessionID: UUID)
    
    /// Background task has started
    case backgroundTaskStarted(taskID: String)
    
    /// Background task has completed
    case backgroundTaskCompleted(taskID: String, processedCount: Int)
    
    /// Background task has failed
    case backgroundTaskFailed(taskID: String, error: Error)
    
    // MARK: - System Events
    
    /// Network reachability has changed
    case networkReachabilityChanged(isReachable: Bool, connectionType: Reachability.ConnectionType)
    
    /// Work queue status has changed
    case queueStatusChanged(queuedCount: Int, processingCount: Int, failedCount: Int)
    
    /// Orchestrator has been paused
    case orchestratorPaused(reason: String)
    
    /// Orchestrator has been resumed
    case orchestratorResumed
    
    /// Orchestrator has encountered a critical error
    case orchestratorError(error: Error)
}

// MARK: - Convenience Extensions

extension OrchestratorEvent {
    
    /// Returns a human-readable description of the event
    var description: String {
        switch self {
        case .segmentQueued(let sessionID, let segmentIndex):
            return "Segment \(segmentIndex) queued for session \(sessionID)"
        case .segmentClosed(let sessionID, let segmentIndex):
            return "Segment \(segmentIndex) closed for session \(sessionID)"
        case .segmentProcessing(let sessionID, let segmentIndex):
            return "Segment \(segmentIndex) processing for session \(sessionID)"
        case .segmentCompleted(let sessionID, let segmentIndex, _):
            return "Segment \(segmentIndex) completed for session \(sessionID)"
        case .segmentFailed(let sessionID, let segmentIndex, let error, let failureCount):
            return "Segment \(segmentIndex) failed for session \(sessionID) (attempt \(failureCount)): \(error.localizedDescription)"
        case .segmentQueuedOffline(let sessionID, let segmentIndex):
            return "Segment \(segmentIndex) queued offline for session \(sessionID)"
        case .segmentRetried(let sessionID, let segmentIndex, let attempt):
            return "Segment \(segmentIndex) retry attempt \(attempt) for session \(sessionID)"
        case .fallbackTriggered(let sessionID, let segmentIndex, let reason):
            return "Fallback triggered for segment \(segmentIndex) in session \(sessionID): \(reason)"
        case .fallbackCompleted(let sessionID, let segmentIndex, _):
            return "Fallback completed for segment \(segmentIndex) in session \(sessionID)"
        case .fallbackFailed(let sessionID, let segmentIndex, let error):
            return "Fallback failed for segment \(segmentIndex) in session \(sessionID): \(error.localizedDescription)"
        case .backgroundTaskScheduled(let taskID, let sessionID):
            return "Background task \(taskID) scheduled for session \(sessionID)"
        case .backgroundTaskStarted(let taskID):
            return "Background task \(taskID) started"
        case .backgroundTaskCompleted(let taskID, let processedCount):
            return "Background task \(taskID) completed, processed \(processedCount) segments"
        case .backgroundTaskFailed(let taskID, let error):
            return "Background task \(taskID) failed: \(error.localizedDescription)"
        case .networkReachabilityChanged(let isReachable, let connectionType):
            return "Network reachability changed: \(isReachable ? "Reachable" : "Unreachable") via \(connectionType.rawValue)"
        case .queueStatusChanged(let queuedCount, let processingCount, let failedCount):
            return "Queue status: \(queuedCount) queued, \(processingCount) processing, \(failedCount) failed"
        case .orchestratorPaused(let reason):
            return "Orchestrator paused: \(reason)"
        case .orchestratorResumed:
            return "Orchestrator resumed"
        case .orchestratorError(let error):
            return "Orchestrator error: \(error.localizedDescription)"
        }
    }
    
    /// Returns the session ID associated with this event, if any
    var sessionID: UUID? {
        switch self {
        case .segmentQueued(let sessionID, _),
             .segmentProcessing(let sessionID, _),
             .segmentCompleted(let sessionID, _, _),
             .segmentFailed(let sessionID, _, _, _),
             .segmentQueuedOffline(let sessionID, _),
             .segmentRetried(let sessionID, _, _),
             .fallbackTriggered(let sessionID, _, _),
             .fallbackCompleted(let sessionID, _, _),
             .fallbackFailed(let sessionID, _, _),
             .backgroundTaskScheduled(_, let sessionID):
            return sessionID
        default:
            return nil
        }
    }
    
    /// Returns the segment index associated with this event, if any
    var segmentIndex: Int? {
        switch self {
        case .segmentQueued(_, let segmentIndex),
             .segmentProcessing(_, let segmentIndex),
             .segmentCompleted(_, let segmentIndex, _),
             .segmentFailed(_, let segmentIndex, _, _),
             .segmentQueuedOffline(_, let segmentIndex),
             .segmentRetried(_, let segmentIndex, _),
             .fallbackTriggered(_, let segmentIndex, _),
             .fallbackCompleted(_, let segmentIndex, _),
             .fallbackFailed(_, let segmentIndex, _):
            return segmentIndex
        default:
            return nil
        }
    }
    
    /// Returns true if this event represents a failure
    var isFailure: Bool {
        switch self {
        case .segmentFailed, .segmentQueuedOffline, .fallbackFailed, .backgroundTaskFailed, .orchestratorError:
            return true
        default:
            return false
        }
    }
    
    /// Returns true if this event represents a success
    var isSuccess: Bool {
        switch self {
        case .segmentCompleted, .fallbackCompleted, .backgroundTaskCompleted:
            return true
        default:
            return false
        }
    }
} 
import Foundation

// MARK: - RecordingError
enum RecordingError: Error, LocalizedError {
    case permissionDenied
    case engineFailure(reason: String)
    case diskFull
    case routeLost
    case interrupted
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied. Please enable microphone access in Settings."
        case .engineFailure(let reason):
            return "Audio engine failed: \(reason)"
        case .diskFull:
            return "Insufficient disk space to continue recording."
        case .routeLost:
            return "Audio route was lost. Recording cannot continue."
        case .interrupted:
            return "Recording was interrupted by another audio session or system event."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required for audio recording."
        case .engineFailure(let reason):
            return "Audio engine encountered an error: \(reason)"
        case .diskFull:
            return "Device storage is full."
        case .routeLost:
            return "Audio input/output route became unavailable."
        case .interrupted:
            return "Another audio session took priority."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Privacy & Security > Microphone and enable access for this app."
        case .engineFailure:
            return "Try restarting the app. If the problem persists, restart your device."
        case .diskFull:
            return "Free up some storage space by removing unused apps, photos, or videos."
        case .routeLost:
            return "Check your audio connections and try again."
        case .interrupted:
            return "Wait for the interruption to end, then resume recording."
        }
    }
    
    var errorCode: Int {
        switch self {
        case .permissionDenied:
            return 1001
        case .engineFailure:
            return 1002
        case .diskFull:
            return 1003
        case .routeLost:
            return 1004
        case .interrupted:
            return 1005
        }
    }
} 
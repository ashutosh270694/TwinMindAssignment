import Foundation
import SwiftData

// MARK: - SegmentStatus Enum
enum SegmentStatus: String, Codable, CaseIterable {
    case pending
    case uploading
    case transcribed
    case failed
    case queuedOffline
    
    var displayText: String {
        switch self {
        case .pending:
            return "Pending"
        case .uploading:
            return "Uploading"
        case .transcribed:
            return "Transcribed"
        case .failed:
            return "Failed"
        case .queuedOffline:
            return "Queued (Offline)"
        }
    }
    
    var chipStatus: ChipStatus {
        switch self {
        case .pending:
            return .neutral
        case .uploading:
            return .warning
        case .transcribed:
            return .success
        case .failed:
            return .error
        case .queuedOffline:
            return .warning
        }
    }
}

// MARK: - RecordingSession Model
@Model
final class RecordingSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var title: String
    var deviceRouteAtStart: String?
    var notes: String?
    var isArchived: Bool
    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.session)
    var segments: [TranscriptSegment]
    
    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        title: String,
        deviceRouteAtStart: String? = nil,
        notes: String? = nil,
        isArchived: Bool = false,
        segments: [TranscriptSegment] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.deviceRouteAtStart = deviceRouteAtStart
        self.notes = notes
        self.isArchived = isArchived
        self.segments = segments
    }
}

// MARK: - TranscriptSegment Model
@Model
final class TranscriptSegment: Sendable {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var index: Int
    var startTime: TimeInterval
    var duration: TimeInterval
    var audioFileURL: URL?
    var transcriptText: String?
    var status: SegmentStatus
    var lastError: String?
    var failureCount: Int
    var createdAt: Date
    @Relationship var session: RecordingSession?
    
    init(
        id: UUID = UUID(),
        sessionID: UUID,
        index: Int,
        startTime: TimeInterval,
        duration: TimeInterval,
        audioFileURL: URL? = nil,
        transcriptText: String? = nil,
        status: SegmentStatus = .pending,
        lastError: String? = nil,
        failureCount: Int = 0,
        createdAt: Date = Date(),
        session: RecordingSession? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.index = index
        self.startTime = startTime
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.transcriptText = transcriptText
        self.status = status
        self.lastError = lastError
        self.failureCount = failureCount
        self.createdAt = createdAt
        self.session = session
    }
} 
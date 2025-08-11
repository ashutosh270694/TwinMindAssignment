import XCTest
import SwiftData
import Combine
@testable import TwinMindAssignment

/// Tests for SwiftData model functionality
final class SwiftDataModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Basic Model Tests
    
    func testRecordingSessionCreation() throws {
        // Test that RecordingSession can be created with basic properties
        
        let session = RecordingSession(title: "Test Session")
        
        // Verify basic properties
        XCTAssertNotNil(session.id, "Session should have an ID")
        XCTAssertEqual(session.title, "Test Session", "Session title should match")
        XCTAssertFalse(session.isArchived, "Session should not be archived initially")
        XCTAssertEqual(session.segments.count, 0, "Session should start with no segments")
    }
    
    func testTranscriptSegmentCreation() throws {
        // Test that TranscriptSegment can be created with basic properties
        
        let sessionID = UUID()
        let segment = TranscriptSegment(
            sessionID: sessionID,
            index: 1,
            startTime: 0.0,
            duration: 30.0
        )
        
        // Verify basic properties
        XCTAssertNotNil(segment.id, "Segment should have an ID")
        XCTAssertEqual(segment.sessionID, sessionID, "Segment session ID should match")
        XCTAssertEqual(segment.index, 1, "Segment index should match")
        XCTAssertEqual(segment.startTime, 0.0, "Segment start time should match")
        XCTAssertEqual(segment.duration, 30.0, "Segment duration should match")
        XCTAssertEqual(segment.status, .pending, "Segment should have pending status initially")
        XCTAssertEqual(segment.failureCount, 0, "Segment should have 0 failure count initially")
    }
    
    func testSegmentStatusEnum() throws {
        // Test that SegmentStatus enum has expected cases
        
        let pending = SegmentStatus.pending
        let uploading = SegmentStatus.uploading
        let transcribed = SegmentStatus.transcribed
        let failed = SegmentStatus.failed
        let queuedOffline = SegmentStatus.queuedOffline
        
        // Verify all cases exist
        XCTAssertNotNil(pending)
        XCTAssertNotNil(uploading)
        XCTAssertNotNil(transcribed)
        XCTAssertNotNil(failed)
        XCTAssertNotNil(queuedOffline)
        
        // Test status display text
        XCTAssertFalse(pending.displayText.isEmpty, "Pending status should have display text")
        XCTAssertFalse(uploading.displayText.isEmpty, "Uploading status should have display text")
        XCTAssertFalse(transcribed.displayText.isEmpty, "Transcribed status should have display text")
        XCTAssertFalse(failed.displayText.isEmpty, "Failed status should have display text")
        XCTAssertFalse(queuedOffline.displayText.isEmpty, "Queued offline status should have display text")
    }
} 
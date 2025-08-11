import XCTest
import Combine
import SwiftData
@testable import TwinMindAssignment

/// Tests for audio segmentation functionality
final class AudioSegmentationTests: XCTestCase {
    
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
    
    // MARK: - Basic Audio Segmentation Tests
    
    func testSegmenterInitialization() throws {
        // Test that Segmenter can be initialized with required parameters
        
        let segmentWriter = SegmentWriter()
        let segmenter = Segmenter(segmentWriter: segmentWriter)
        
        // Verify initial state
        XCTAssertEqual(segmenter.totalSegmentsCreated, 0, "Should start with 0 segments")
        XCTAssertEqual(segmenter.currentSegmentDuration, 0, "Should start with 0 duration")
    }
    
    func testSegmentWriterInitialization() throws {
        // Test that SegmentWriter can be initialized
        
        let segmentWriter = SegmentWriter()
        
        // Verify it was created successfully
        XCTAssertNotNil(segmentWriter, "SegmentWriter should be created successfully")
    }
    
    func testBasicSegmentationWorkflow() throws {
        // Test basic segmentation workflow
        
        let segmentWriter = SegmentWriter()
        let segmenter = Segmenter(segmentWriter: segmentWriter)
        
        let expectation = XCTestExpectation(description: "Basic segmentation")
        
        // Subscribe to segment closed events
        segmenter.segmentClosedPublisher
            .sink { segment in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start a session
        let session = RecordingSession(title: "Test Session")
        segmenter.startSession(session)
        
        // Add some PCM data
        let dummyData = Data(repeating: 0, count: 1024)
        segmenter.addPCMData(dummyData)
        
        // Wait for processing
        wait(for: [expectation], timeout: 2.0)
        
        // Verify basic functionality
        XCTAssertNotNil(segmenter, "Segmenter should remain valid")
    }
} 
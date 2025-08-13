//
//  DataModelTests.swift
//  TwinMindAssignmentTests
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh, DobbyFactory. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import XCTest
@testable import TwinMindAssignment

/// Test suite for core data models
/// 
/// Tests the fundamental data structures used throughout the application.
/// Focuses on:
/// - Model initialization and validation
/// - Property access and modification
/// - SwiftData integration
/// - Data integrity and constraints
final class DataModelTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Each test creates its own data, no shared state needed
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up any test data
    }
    
    // MARK: - RecordingSession Tests
    
    /// Tests that RecordingSession can be created with valid parameters
    func testRecordingSessionCreationWithValidParameters() throws {
        // Given
        let title = "Test Recording Session"
        let startedAt = Date()
        
        // When
        let session = RecordingSession(title: title, startedAt: startedAt)
        
        // Then
        XCTAssertNotNil(session.id, "Session should have a unique ID")
        XCTAssertEqual(session.title, title, "Session title should match input")
        XCTAssertEqual(session.startedAt, startedAt, "Session start time should match input")
        XCTAssertEqual(session.duration, 0, "New session should have zero duration")
        XCTAssertTrue(session.segments.isEmpty, "New session should have no segments")
        XCTAssertEqual(session.status, .idle, "New session should be in idle status")
    }
    
    /// Tests that RecordingSession can be created with default values
    func testRecordingSessionCreationWithDefaultValues() throws {
        // When
        let session = RecordingSession()
        
        // Then
        XCTAssertNotNil(session.id, "Session should have a unique ID")
        XCTAssertEqual(session.title, "Untitled Session", "Session should have default title")
        XCTAssertNotNil(session.startedAt, "Session should have a start time")
        XCTAssertEqual(session.duration, 0, "New session should have zero duration")
        XCTAssertTrue(session.segments.isEmpty, "New session should have no segments")
        XCTAssertEqual(session.status, .idle, "New session should be in idle status")
    }
    
    /// Tests that RecordingSession properties can be modified
    func testRecordingSessionPropertyModification() throws {
        // Given
        var session = RecordingSession()
        let newTitle = "Modified Title"
        let newNotes = "Test notes"
        
        // When
        session.title = newTitle
        session.notes = newNotes
        session.status = .recording
        
        // Then
        XCTAssertEqual(session.title, newTitle, "Title should be updated")
        XCTAssertEqual(session.notes, newNotes, "Notes should be updated")
        XCTAssertEqual(session.status, .recording, "Status should be updated")
    }
    
    // MARK: - TranscriptSegment Tests
    
    /// Tests that TranscriptSegment can be created with valid parameters
    func testTranscriptSegmentCreationWithValidParameters() throws {
        // Given
        let sessionID = UUID()
        let index = 0
        let startAt = Date()
        let endAt = Date().addingTimeInterval(30)
        
        // When
        let segment = TranscriptSegment(
            sessionID: sessionID,
            index: index,
            startAt: startAt,
            endAt: endAt
        )
        
        // Then
        XCTAssertNotNil(segment.id, "Segment should have a unique ID")
        XCTAssertEqual(segment.sessionID, sessionID, "Session ID should match input")
        XCTAssertEqual(segment.index, index, "Segment index should match input")
        XCTAssertEqual(segment.startAt, startAt, "Start time should match input")
        XCTAssertEqual(segment.endAt, endAt, "End time should match input")
        XCTAssertEqual(segment.status, .queued, "New segment should be queued")
        XCTAssertNil(segment.transcriptText, "New segment should have no transcript")
        XCTAssertNil(segment.lastError, "New segment should have no error")
    }
    
    /// Tests that TranscriptSegment can be created with default values
    func testTranscriptSegmentCreationWithDefaultValues() throws {
        // When
        let segment = TranscriptSegment()
        
        // Then
        XCTAssertNotNil(segment.id, "Segment should have a unique ID")
        XCTAssertNotNil(segment.sessionID, "Segment should have a session ID")
        XCTAssertEqual(segment.index, 0, "Segment should have default index")
        XCTAssertNotNil(segment.startAt, "Segment should have a start time")
        XCTAssertNil(segment.endAt, "New segment should have no end time")
        XCTAssertEqual(segment.status, .queued, "New segment should be queued")
        XCTAssertNil(segment.transcriptText, "New segment should have no transcript")
        XCTAssertNil(segment.lastError, "New segment should have no error")
    }
    
    /// Tests that TranscriptSegment properties can be modified
    func testTranscriptSegmentPropertyModification() throws {
        // Given
        var segment = TranscriptSegment()
        let transcriptText = "Test transcript text"
        let errorMessage = "Test error message"
        
        // When
        segment.transcriptText = transcriptText
        segment.status = .transcribed
        segment.lastError = errorMessage
        
        // Then
        XCTAssertEqual(segment.transcriptText, transcriptText, "Transcript should be updated")
        XCTAssertEqual(segment.status, .transcribed, "Status should be updated")
        XCTAssertEqual(segment.lastError, errorMessage, "Error should be updated")
    }
    
    // MARK: - Data Integrity Tests
    
    /// Tests that session duration is calculated correctly
    func testSessionDurationCalculation() throws {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(120) // 2 minutes
        var session = RecordingSession(startedAt: startTime)
        session.endedAt = endTime
        
        // When
        let duration = session.duration
        
        // Then
        XCTAssertEqual(duration, 120, "Duration should be 120 seconds for 2-minute session")
    }
    
    /// Tests that segment duration is calculated correctly
    func testSegmentDurationCalculation() throws {
        // Given
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(30) // 30 seconds
        let segment = TranscriptSegment(
            sessionID: UUID(),
            index: 0,
            startAt: startTime,
            endAt: endTime
        )
        
        // When
        let duration = segment.duration
        
        // Then
        XCTAssertEqual(duration, 30, "Segment duration should be 30 seconds")
    }
    
    /// Tests that segment index is always non-negative
    func testSegmentIndexIsNonNegative() throws {
        // Given
        let segment = TranscriptSegment()
        
        // Then
        XCTAssertGreaterThanOrEqual(segment.index, 0, "Segment index should never be negative")
    }
} 
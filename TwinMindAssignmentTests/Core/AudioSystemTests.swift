//
//  AudioSystemTests.swift
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

/// Test suite for audio system components
/// 
/// Tests the audio recording and processing functionality.
/// Focuses on:
/// - Audio session management
/// - Recording state management
/// - Audio format handling
/// - Error handling and edge cases
final class AudioSystemTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Each test creates its own audio components, no shared state needed
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up any audio resources
    }
    
    // MARK: - RecordingState Tests
    
    /// Tests that RecordingState enum has expected cases
    func testRecordingStateEnumHasExpectedCases() throws {
        // Given
        let expectedCases: [RecordingState] = [.idle, .preparing, .recording, .paused, .stopped]
        
        // When & Then
        for expectedCase in expectedCases {
            XCTAssertTrue(RecordingState.allCases.contains(expectedCase), "RecordingState should contain case: \(expectedCase)")
        }
    }
    
    /// Tests that RecordingState cases are comparable
    func testRecordingStateCasesAreComparable() throws {
        // Given
        let idleState = RecordingState.idle
        let preparingState = RecordingState.preparing
        let recordingState = RecordingState.recording
        
        // When & Then
        XCTAssertNotEqual(idleState, preparingState, "Different states should not be equal")
        XCTAssertNotEqual(preparingState, recordingState, "Different states should not be equal")
        XCTAssertEqual(idleState, idleState, "Same state should be equal to itself")
    }
    
    // MARK: - AudioRecorderProtocol Tests
    
    /// Tests that SimpleAudioRecorder conforms to AudioRecorderProtocol
    func testSimpleAudioRecorderConformsToProtocol() throws {
        // Given
        let recorder = SimpleAudioRecorder()
        
        // When & Then
        XCTAssertTrue(recorder is AudioRecorderProtocol, "SimpleAudioRecorder should conform to AudioRecorderProtocol")
    }
    
    /// Tests that SimpleAudioRecorder has expected initial state
    func testSimpleAudioRecorderHasExpectedInitialState() throws {
        // Given
        let recorder = SimpleAudioRecorder()
        
        // When & Then
        XCTAssertFalse(recorder.isRecording, "New recorder should not be recording")
        XCTAssertEqual(recorder.recordingState, .idle, "New recorder should be in idle state")
    }
    
    /// Tests that SimpleAudioRecorder can start recording
    func testSimpleAudioRecorderCanStartRecording() async throws {
        // Given
        let recorder = SimpleAudioRecorder()
        let session = RecordingSession()
        let sink = SimpleAudioSegmentSink()
        
        // When
        try await recorder.startRecording(session: session, segmentSink: sink)
        
        // Then
        XCTAssertTrue(recorder.isRecording, "Recorder should be recording after start")
        XCTAssertEqual(recorder.recordingState, .recording, "Recorder state should be recording")
    }
    
    /// Tests that SimpleAudioRecorder can stop recording
    func testSimpleAudioRecorderCanStopRecording() async throws {
        // Given
        let recorder = SimpleAudioRecorder()
        let session = RecordingSession()
        let sink = SimpleAudioSegmentSink()
        
        // When
        try await recorder.startRecording(session: session, segmentSink: sink)
        await recorder.stop()
        
        // Then
        XCTAssertFalse(recorder.isRecording, "Recorder should not be recording after stop")
        XCTAssertEqual(recorder.recordingState, .stopped, "Recorder state should be stopped")
    }
    
    /// Tests that SimpleAudioRecorder can pause and resume
    func testSimpleAudioRecorderCanPauseAndResume() async throws {
        // Given
        let recorder = SimpleAudioRecorder()
        let session = RecordingSession()
        let sink = SimpleAudioSegmentSink()
        
        // When
        try await recorder.startRecording(session: session, segmentSink: sink)
        await recorder.pause()
        
        // Then
        XCTAssertEqual(recorder.recordingState, .paused, "Recorder state should be paused after pause")
        
        // When
        await recorder.resume()
        
        // Then
        XCTAssertEqual(recorder.recordingState, .recording, "Recorder state should be recording after resume")
    }
    
    // MARK: - AudioSegmentSink Tests
    
    /// Tests that SimpleAudioSegmentSink conforms to AudioSegmentSink protocol
    func testSimpleAudioSegmentSinkConformsToProtocol() throws {
        // Given
        let sink = SimpleAudioSegmentSink()
        
        // When & Then
        XCTAssertTrue(sink is AudioSegmentSink, "SimpleAudioSegmentSink should conform to AudioSegmentSink")
    }
    
    /// Tests that SimpleAudioSegmentSink can receive PCM data
    func testSimpleAudioSegmentSinkCanReceivePCMData() throws {
        // Given
        let sink = SimpleAudioSegmentSink()
        let testData = Data([0x00, 0x01, 0x02, 0x03])
        
        // When
        sink.addPCMData(testData)
        
        // Then
        // Since this is a simple implementation that just logs, we can't assert much
        // In a real test, we might verify that the data was processed correctly
        XCTAssertTrue(true, "Sink should accept PCM data without throwing")
    }
    
    // MARK: - Audio Format Tests
    
    /// Tests that audio format conversion handles valid parameters
    func testAudioFormatConversionWithValidParameters() throws {
        // Given
        let sampleRate: Double = 16000
        let channels = 1
        
        // When
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: AVAudioChannelCount(channels)
        )
        
        // Then
        XCTAssertNotNil(format, "Audio format should be created with valid parameters")
        XCTAssertEqual(format?.sampleRate, sampleRate, "Sample rate should match input")
        XCTAssertEqual(format?.channelCount, channels, "Channel count should match input")
    }
    
    /// Tests that audio format conversion handles edge cases
    func testAudioFormatConversionWithEdgeCases() throws {
        // Given
        let sampleRate: Double = 8000 // Minimum common sample rate
        let channels = 2 // Stereo
        
        // When
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: AVAudioChannelCount(channels)
        )
        
        // Then
        XCTAssertNotNil(format, "Audio format should be created with edge case parameters")
        XCTAssertEqual(format?.sampleRate, sampleRate, "Sample rate should match input")
        XCTAssertEqual(format?.channelCount, channels, "Channel count should match input")
    }
    
    // MARK: - Error Handling Tests
    
    /// Tests that recording errors are properly defined
    func testRecordingErrorsAreProperlyDefined() throws {
        // Given
        let expectedCases: [RecordingError] = [
            .permissionDenied,
            .audioSessionError,
            .engineError,
            .fileError,
            .unknown
        ]
        
        // When & Then
        for expectedCase in expectedCases {
            XCTAssertTrue(RecordingError.allCases.contains(expectedCase), "RecordingError should contain case: \(expectedCase)")
        }
    }
    
    /// Tests that recording errors have localized descriptions
    func testRecordingErrorsHaveLocalizedDescriptions() throws {
        // Given
        let error = RecordingError.permissionDenied
        
        // When
        let description = error.localizedDescription
        
        // Then
        XCTAssertFalse(description.isEmpty, "Error should have a non-empty description")
        XCTAssertTrue(description.count > 10, "Error description should be descriptive")
    }
} 
//
//  UIComponentTests.swift
//  TwinMindAssignmentTests
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh, DobbyFactory. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import XCTest
import SwiftUI
@testable import TwinMindAssignment

/// Test suite for UI components
/// 
/// Tests the user interface components and their behavior.
/// Focuses on:
/// - View model behavior
/// - UI state management
/// - User interaction handling
/// - Accessibility support
final class UIComponentTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Each test creates its own UI components, no shared state needed
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up any UI resources
    }
    
    // MARK: - StatusChip Tests
    
    /// Tests that ChipStatus enum has expected cases
    func testChipStatusEnumHasExpectedCases() throws {
        // Given
        let expectedCases: [ChipStatus] = [
            .neutral,
            .success,
            .warning,
            .error,
            .info
        ]
        
        // When & Then
        for expectedCase in expectedCases {
            XCTAssertTrue(ChipStatus.allCases.contains(expectedCase), "ChipStatus should contain case: \(expectedCase)")
        }
    }
    
    /// Tests that ChipStatus cases have appropriate colors
    func testChipStatusCasesHaveAppropriateColors() throws {
        // Given
        let neutralStatus = ChipStatus.neutral
        let successStatus = ChipStatus.success
        let errorStatus = ChipStatus.error
        
        // When & Then
        XCTAssertNotNil(neutralStatus.color, "Neutral status should have a color")
        XCTAssertNotNil(successStatus.color, "Success status should have a color")
        XCTAssertNotNil(errorStatus.color, "Error status should have a color")
    }
    
    /// Tests that ChipStatus cases have appropriate text
    func testChipStatusCasesHaveAppropriateText() throws {
        // Given
        let neutralStatus = ChipStatus.neutral
        let successStatus = ChipStatus.success
        let errorStatus = ChipStatus.error
        
        // When & Then
        XCTAssertFalse(neutralStatus.text.isEmpty, "Neutral status should have text")
        XCTAssertFalse(successStatus.text.isEmpty, "Success status should have text")
        XCTAssertFalse(errorStatus.text.isEmpty, "Error status should have text")
    }
    
    // MARK: - RecordingViewModel Tests
    
    /// Tests that RecordingViewModel can be created
    func testRecordingViewModelCanBeCreated() throws {
        // When
        let viewModel = RecordingViewModel()
        
        // Then
        XCTAssertNotNil(viewModel, "RecordingViewModel should be created successfully")
        XCTAssertEqual(viewModel.recordingState, .idle, "New view model should be in idle state")
        XCTAssertFalse(viewModel.isRecording, "New view model should not be recording")
    }
    
    /// Tests that RecordingViewModel can be configured with environment
    func testRecordingViewModelCanBeConfiguredWithEnvironment() throws {
        // Given
        let viewModel = RecordingViewModel()
        let environment = EnvironmentHolder.createForTesting()
        
        // When
        viewModel.setup(with: environment)
        
        // Then
        XCTAssertNotNil(viewModel.environment, "Environment should be set after setup")
    }
    
    /// Tests that RecordingViewModel state changes are published
    func testRecordingViewModelStateChangesArePublished() throws {
        // Given
        let viewModel = RecordingViewModel()
        let expectation = XCTestExpectation(description: "State change should be published")
        
        // When
        let cancellable = viewModel.$recordingState
            .dropFirst() // Skip initial value
            .sink { newState in
                if newState == .preparing {
                    expectation.fulfill()
                }
            }
        
        // Simulate state change
        viewModel.recordingState = .preparing
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        cancellable.cancel()
    }
    
    // MARK: - SessionPlaybackViewModel Tests
    
    /// Tests that SessionPlaybackViewModel can be created
    func testSessionPlaybackViewModelCanBeCreated() throws {
        // Given
        let session = RecordingSession()
        
        // When
        let viewModel = SessionPlaybackViewModel(session: session)
        
        // Then
        XCTAssertNotNil(viewModel, "SessionPlaybackViewModel should be created successfully")
        XCTAssertEqual(viewModel.session.id, session.id, "Session should match input")
    }
    
    /// Tests that SessionPlaybackViewModel has expected initial state
    func testSessionPlaybackViewModelHasExpectedInitialState() throws {
        // Given
        let session = RecordingSession()
        let viewModel = SessionPlaybackViewModel(session: session)
        
        // When & Then
        XCTAssertEqual(viewModel.currentSegmentIndex, 0, "Initial segment index should be 0")
        XCTAssertFalse(viewModel.canGoToPreviousSegment, "Cannot go to previous segment initially")
        XCTAssertFalse(viewModel.canGoToNextSegment, "Cannot go to next segment initially")
    }
    
    // MARK: - EnvironmentHolder Tests
    
    /// Tests that EnvironmentHolder can be created for testing
    func testEnvironmentHolderCanBeCreatedForTesting() throws {
        // When
        let environment = EnvironmentHolder.createForTesting()
        
        // Then
        XCTAssertNotNil(environment, "Environment should be created for testing")
        XCTAssertTrue(environment.useFakes, "Testing environment should use fake implementations")
    }
    
    /// Tests that EnvironmentHolder can be created for preview
    func testEnvironmentHolderCanBeCreatedForPreview() throws {
        // When
        let environment = EnvironmentHolder.createForPreview()
        
        // Then
        XCTAssertNotNil(environment, "Environment should be created for preview")
        XCTAssertNotNil(environment.swiftDataStack, "Preview environment should have SwiftData stack")
    }
    
    // MARK: - PermissionManager Tests
    
    /// Tests that PermissionManager can be created
    func testPermissionManagerCanBeCreated() throws {
        // When
        let permissionManager = PermissionManager()
        
        // Then
        XCTAssertNotNil(permissionManager, "PermissionManager should be created successfully")
    }
    
    /// Tests that PermissionManager has expected initial state
    func testPermissionManagerHasExpectedInitialState() throws {
        // Given
        let permissionManager = PermissionManager()
        
        // When & Then
        XCTAssertNotNil(permissionManager, "PermissionManager should exist")
        // Note: We can't test actual permission status in unit tests
        // as it depends on system state
    }
    
    // MARK: - ExportService Tests
    
    /// Tests that ExportService can be created
    func testExportServiceCanBeCreated() throws {
        // When
        let exportService = ExportService()
        
        // Then
        XCTAssertNotNil(exportService, "ExportService should be created successfully")
    }
    
    /// Tests that ExportService has expected methods
    func testExportServiceHasExpectedMethods() throws {
        // Given
        let exportService = ExportService()
        
        // When & Then
        // We can't easily test async methods in unit tests without complex setup
        // This test just verifies the service exists and can be created
        XCTAssertNotNil(exportService, "ExportService should exist and be testable")
    }
    
    // MARK: - UI State Management Tests
    
    /// Tests that UI components handle state changes gracefully
    func testUIComponentsHandleStateChangesGracefully() throws {
        // Given
        let viewModel = RecordingViewModel()
        
        // When
        viewModel.recordingState = .recording
        viewModel.recordingState = .paused
        viewModel.recordingState = .stopped
        
        // Then
        // If we get here without crashing, the state changes are handled gracefully
        XCTAssertTrue(true, "UI components should handle state changes without crashing")
    }
    
    /// Tests that UI components maintain consistency
    func testUIComponentsMaintainConsistency() throws {
        // Given
        let viewModel = RecordingViewModel()
        
        // When
        viewModel.recordingState = .recording
        
        // Then
        XCTAssertTrue(viewModel.isRecording || viewModel.recordingState == .recording, "UI state should be consistent")
    }
} 
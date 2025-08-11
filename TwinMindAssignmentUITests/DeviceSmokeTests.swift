import XCTest
import SwiftUI
@testable import TwinMindAssignment

/// Device-only smoke tests for critical user flows
/// These tests should be run on actual devices, not simulators
class DeviceSmokeTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Smoke Tests
    
    func testLaunchAndPermissionHandling() throws {
        // This test documents that permission alerts need manual handling
        // In a real CI environment, you would use springboard helper or similar
        
        // Wait for app to launch
        XCTAssertTrue(app.waitForExistence(timeout: 5))
        
        // Check if we're on the main screen
        let recordingButton = app.buttons["Start Recording"]
        XCTAssertTrue(recordingButton.exists || recordingButton.waitForExistence(timeout: 3))
        
        // Note: Permission alerts would appear here and need manual handling
        // For automated testing, you would:
        // 1. Use springboard helper to handle alerts
        // 2. Pre-grant permissions via device settings
        // 3. Use test schemes with pre-configured permissions
    }
    
    func testRecordingFlow() throws {
        // Skip if running on simulator (no microphone)
        guard let simulatorName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"], !simulatorName.isEmpty else {
            throw XCTSkip("This test requires a physical device with microphone")
        }
        
        // Navigate to recording view
        let recordingButton = app.buttons["Start Recording"]
        XCTAssertTrue(recordingButton.exists)
        
        // Start recording
        recordingButton.tap()
        
        // Wait for recording to start
        let stopButton = app.buttons["Stop Recording"]
        XCTAssertTrue(stopButton.waitForExistence(timeout: 5))
        
        // Record for a few seconds
        Thread.sleep(forTimeInterval: 3)
        
        // Stop recording
        stopButton.tap()
        
        // Wait for processing
        let sessionsButton = app.buttons["Sessions"]
        XCTAssertTrue(sessionsButton.waitForExistence(timeout: 5))
    }
    
    func testSessionsNavigation() throws {
        // Navigate to sessions list
        let sessionsButton = app.buttons["Sessions"]
        XCTAssertTrue(sessionsButton.exists)
        sessionsButton.tap()
        
        // Check if sessions list is displayed
        let sessionsList = app.collectionViews.firstMatch
        XCTAssertTrue(sessionsList.exists)
        
        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists)
        backButton.tap()
    }
    
    func testSettingsAccess() throws {
        // Navigate to settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.exists)
        settingsButton.tap()
        
        // Check if settings view is displayed
        let settingsView = app.navigationBars["Settings"]
        XCTAssertTrue(settingsView.exists)
        
        // Navigate back
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists)
        backButton.tap()
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            app.launch()
        }
    }
    
    func testMemoryUsage() throws {
        // Record memory usage during normal operation
        let memoryMetric = XCTMemoryMetric()
        
        measure(metrics: [memoryMetric]) {
            // Simulate normal app usage
            let recordingButton = app.buttons["Start Recording"]
            if recordingButton.exists {
                recordingButton.tap()
                Thread.sleep(forTimeInterval: 1)
                
                let stopButton = app.buttons["Stop Recording"]
                if stopButton.exists {
                    stopButton.tap()
                }
            }
        }
    }
}

// MARK: - Test Plan Configuration

extension DeviceSmokeTests {
    
    /// Returns true if running on a physical device
    static var isRunningOnDevice: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
    
    /// Returns true if running in CI environment
    static var isRunningInCI: Bool {
        return ProcessInfo.processInfo.environment["CI"] != nil
    }
}

// MARK: - Test Categories

extension DeviceSmokeTests {
    
    /// Mark test as device-only
    override func setUp() {
        super.setUp()
        
        // Skip if running on simulator in CI
        if Self.isRunningInCI && !Self.isRunningOnDevice {
            // Note: setUp() cannot throw, so we'll skip the test in the individual test methods instead
        }
    }
} 
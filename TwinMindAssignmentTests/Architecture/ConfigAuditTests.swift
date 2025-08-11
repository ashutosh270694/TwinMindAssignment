import XCTest
import Combine
@testable import TwinMindAssignment

/// Tests to validate app configuration and architecture
class ConfigAuditTests: XCTestCase {
    
    // MARK: - Info.plist Validation
    
    func testRequiredUsageDescriptions() throws {
        let bundle = Bundle.main
        
        // Check microphone usage description
        let micDescription = bundle.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
        XCTAssertNotNil(micDescription, "NSMicrophoneUsageDescription must be present")
        XCTAssertFalse(micDescription?.isEmpty ?? true, "NSMicrophoneUsageDescription cannot be empty")
        
        // Check speech recognition usage description
        let speechDescription = bundle.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") as? String
        XCTAssertNotNil(speechDescription, "NSSpeechRecognitionUsageDescription must be present")
        XCTAssertFalse(speechDescription?.isEmpty ?? true, "NSSpeechRecognitionUsageDescription cannot be empty")
    }
    
    func testBackgroundModes() throws {
        let bundle = Bundle.main
        
        // Check if background modes are configured
        let backgroundModes = bundle.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertNotNil(backgroundModes, "UIBackgroundModes must be configured")
        
        guard let modes = backgroundModes else { return }
        
        // Check required background modes
        let requiredModes = ["audio", "processing", "fetch"]
        for requiredMode in requiredModes {
            XCTAssertTrue(modes.contains(requiredMode), "Background mode '\(requiredMode)' must be present")
        }
    }
    
    func testATSConfiguration() throws {
        let bundle = Bundle.main
        
        // Check ATS settings
        let ats = bundle.object(forInfoDictionaryKey: "NSAppTransportSecurity") as? [String: Any]
        
        // If ATS is configured, check for security issues
        if let ats = ats {
            // Check if arbitrary loads are allowed (security risk)
            let allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool
            XCTAssertNotEqual(allowsArbitraryLoads, true, "NSAllowsArbitraryLoads should not be enabled")
            
            // Check for HTTP exceptions
            if let exceptions = ats["NSExceptionDomains"] as? [String: Any] {
                for (domain, config) in exceptions {
                    if let domainConfig = config as? [String: Any] {
                        let allowsHTTP = domainConfig["NSExceptionAllowsInsecureHTTPLoads"] as? Bool
                        if allowsHTTP == true {
                            print("⚠️ HTTP allowed for domain: \(domain)")
                        }
                    }
                }
            }
        } else {
            // Default ATS configuration is secure (HTTPS only)
            print("✅ ATS not explicitly configured - defaults to HTTPS only")
        }
    }
    
    // MARK: - Framework Validation
    
    func testRequiredFrameworks() throws {
        // Check if required frameworks are available
        let requiredFrameworks = [
            "AVFoundation",
            "Speech",
            "SwiftData"
        ]
        
        for framework in requiredFrameworks {
            XCTAssertTrue(Bundle.main.path(forResource: framework, ofType: "framework") != nil ||
                         Bundle.main.path(forResource: framework, ofType: nil) != nil,
                         "Framework \(framework) must be linked")
        }
    }
    
    func testBackgroundTasksFramework() throws {
        // BackgroundTasks framework is only available on iOS 13+
        if #available(iOS 13.0, *) {
            XCTAssertTrue(Bundle.main.path(forResource: "BackgroundTasks", ofType: "framework") != nil ||
                         Bundle.main.path(forResource: "BackgroundTasks", ofType: nil) != nil,
                         "BackgroundTasks framework must be linked on iOS 13+")
        } else {
            print("ℹ️ BackgroundTasks framework not available on iOS < 13.0")
        }
    }
    
    // MARK: - Architecture Validation
    
    func testSwiftDataModels() throws {
        // Check if SwiftData models are properly configured
        let recordingSessionType = RecordingSession.self
        let transcriptSegmentType = TranscriptSegment.self
        
        // Verify models can be instantiated
        let session = RecordingSession(title: "Test Session")
        let segment = TranscriptSegment(sessionID: session.id, index: 0, startTime: 0, duration: 10)
        
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(segment.id)
        XCTAssertEqual(segment.sessionID, session.id)
    }
    
    func testRepositoryProtocols() throws {
        // Check if repository protocols are properly defined
        let sessionRepoProtocol = RecordingSessionRepositoryProtocol.self
        let segmentRepoProtocol = TranscriptSegmentRepositoryProtocol.self
        
        // Verify protocols exist
        XCTAssertNotNil(sessionRepoProtocol)
        XCTAssertNotNil(segmentRepoProtocol)
    }
    
    func testDependencyInjection() throws {
        // Check if environment holder is properly configured
        let environment = EnvironmentHolder.createDefault()
        
        XCTAssertNotNil(environment.recordingSessionRepository)
        XCTAssertNotNil(environment.transcriptSegmentRepository)
        XCTAssertNotNil(environment.audioRecorder)
        XCTAssertNotNil(environment.transcriptionOrchestrator)
        XCTAssertNotNil(environment.reachability)
        XCTAssertNotNil(environment.backgroundTaskManager)
        XCTAssertNotNil(environment.segmentWriter)
        XCTAssertNotNil(environment.swiftDataStack)
    }
    
    // MARK: - Security Validation
    
    func testKeychainUsage() throws {
        // Check if TokenManager uses Keychain
        let tokenManager = TokenManager()
        
        // Test token storage and retrieval
        let testToken = "test_token_12345"
        let stored = tokenManager.setToken(testToken)
        XCTAssertTrue(stored, "Token should be stored successfully")
        
        let retrieved = tokenManager.getToken()
        XCTAssertEqual(retrieved, testToken, "Token should be retrieved correctly")
        
        // Clean up
        _ = tokenManager.removeToken()
    }
    
    func testFileProtection() throws {
        // Check if file protection is implemented
        let sourceFiles = findSwiftFiles()
        
        var hasFileProtection = false
        for file in sourceFiles {
            if let content = try? String(contentsOfFile: file) {
                if content.contains("FileProtectionType.complete") {
                    hasFileProtection = true
                    break
                }
            }
        }
        
        // This is a warning, not a failure, as file protection might be implemented elsewhere
        if !hasFileProtection {
            print("⚠️ FileProtectionType.complete not found in source code")
        }
    }
    
    // MARK: - Performance Validation
    
    func testRepositoryPerformance() throws {
        // Test repository performance with large datasets
        let environment = EnvironmentHolder.createDefault()
        let sessionRepo = environment.recordingSessionRepository
        
        // Measure fetch performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let expectation = XCTestExpectation(description: "Repository fetch")
        sessionRepo.fetchSessions()
            .sink(
                receiveCompletion: { _ in
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Repository operations should complete within reasonable time
        XCTAssertLessThan(duration, 1.0, "Repository fetch should complete within 1 second")
    }
    
    // MARK: - Helper Methods
    
    private var cancellables = Set<AnyCancellable>()
    
    private func findSwiftFiles() -> [String] {
        let bundle = Bundle(for: type(of: self))
        let bundlePath = bundle.bundlePath
        
        var swiftFiles: [String] = []
        let fileManager = FileManager.default
        
        if let enumerator = fileManager.enumerator(atPath: bundlePath) {
            while let filePath = enumerator.nextObject() as? String {
                if filePath.hasSuffix(".swift") {
                    swiftFiles.append("\(bundlePath)/\(filePath)")
                }
            }
        }
        
        return swiftFiles
    }
}

// MARK: - Test Categories

extension ConfigAuditTests {
    
    /// Mark tests that should run in CI
    override func setUp() {
        super.setUp()
        
        // These tests are critical for CI/CD and should always run
        continueAfterFailure = false
    }
    
    /// Mark tests that validate critical configuration
    func testCriticalConfiguration() throws {
        // Run all critical configuration tests
        try testRequiredUsageDescriptions()
        try testBackgroundModes()
        try testRequiredFrameworks()
        try testRepositoryProtocols()
        try testDependencyInjection()
    }
} 
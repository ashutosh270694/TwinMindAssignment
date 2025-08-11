import XCTest
import Foundation
@testable import TwinMindAssignment

final class ConfigAuditTests: XCTestCase {
    
    // MARK: - Configuration Audit Tests
    
    func testProjectConfigurationAudit() throws {
        // This test validates project configuration directly
        // It will fail with actionable messages if any configuration issues are found
        
        // Check that required privacy usage descriptions are present
        let bundle = Bundle.main
        let infoPlist = bundle.infoDictionary
        
        // Check microphone usage description
        let micDescription = infoPlist?["NSMicrophoneUsageDescription"] as? String
        XCTAssertNotNil(micDescription, "NSMicrophoneUsageDescription should be present")
        XCTAssertFalse(micDescription?.isEmpty ?? true, "NSMicrophoneUsageDescription should not be empty")
        XCTAssertGreaterThanOrEqual(micDescription?.count ?? 0, 10, "NSMicrophoneUsageDescription should be at least 10 characters")
        
        // Check speech recognition usage description
        let speechDescription = infoPlist?["NSSpeechRecognitionUsageDescription"] as? String
        XCTAssertNotNil(speechDescription, "NSSpeechRecognitionUsageDescription should be present")
        XCTAssertFalse(speechDescription?.isEmpty ?? true, "NSSpeechRecognitionUsageDescription should not be empty")
        XCTAssertGreaterThanOrEqual(speechDescription?.count ?? 0, 10, "NSSpeechRecognitionUsageDescription should be at least 10 characters")
        
        // Check background modes
        let backgroundModes = infoPlist?["UIBackgroundModes"] as? [String]
        XCTAssertNotNil(backgroundModes, "UIBackgroundModes should be configured")
        XCTAssertTrue(backgroundModes?.contains("audio") ?? false, "UIBackgroundModes should include 'audio'")
        
        // Configuration audit passed
        print("✅ Configuration audit passed - all required privacy keys and background modes are present")
    }
    
    func testInfoPlistConfiguration() throws {
        // Check that Info.plist has required privacy usage descriptions
        
        let bundle = Bundle.main
        let infoPlist = bundle.infoDictionary
        
        // Check microphone usage description
        let micDescription = infoPlist?["NSMicrophoneUsageDescription"] as? String
        XCTAssertNotNil(micDescription, "NSMicrophoneUsageDescription should be present")
        XCTAssertFalse(micDescription?.isEmpty ?? true, "NSMicrophoneUsageDescription should not be empty")
        XCTAssertGreaterThanOrEqual(micDescription?.count ?? 0, 10, "NSMicrophoneUsageDescription should be at least 10 characters")
        
        // Check speech recognition usage description
        let speechDescription = infoPlist?["NSSpeechRecognitionUsageDescription"] as? String
        XCTAssertNotNil(speechDescription, "NSSpeechRecognitionUsageDescription should be present")
        XCTAssertFalse(speechDescription?.isEmpty ?? true, "NSSpeechRecognitionUsageDescription should not be empty")
        XCTAssertGreaterThanOrEqual(speechDescription?.count ?? 0, 10, "NSSpeechRecognitionUsageDescription should be at least 10 characters")
    }
    
    func testRequiredPrivacyKeys() {
        // Check that required privacy keys are present
        let bundle = Bundle.main
        
        // Check microphone usage description
        let micDescription = bundle.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
        XCTAssertNotNil(micDescription, "NSMicrophoneUsageDescription should be present")
        XCTAssertFalse(micDescription?.isEmpty ?? true, "NSMicrophoneUsageDescription should not be empty")
        XCTAssertGreaterThanOrEqual(micDescription?.count ?? 0, 10, "NSMicrophoneUsageDescription should be at least 10 characters")
        
        // Check speech recognition usage description
        let speechDescription = bundle.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") as? String
        XCTAssertNotNil(speechDescription, "NSSpeechRecognitionUsageDescription should be present")
        XCTAssertFalse(speechDescription?.isEmpty ?? true, "NSSpeechRecognitionUsageDescription should not be empty")
        XCTAssertGreaterThanOrEqual(speechDescription?.count ?? 0, 10, "NSSpeechRecognitionUsageDescription should be at least 10 characters")
    }
    
    func testBackgroundModes() {
        // Check that required background modes are configured
        let bundle = Bundle.main
        let backgroundModes = bundle.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        
        XCTAssertNotNil(backgroundModes, "UIBackgroundModes should be configured")
        
        if let modes = backgroundModes {
            XCTAssertTrue(modes.contains("audio"), "Background audio mode should be enabled")
            XCTAssertTrue(modes.contains("background-processing"), "Background processing mode should be enabled")
            XCTAssertTrue(modes.contains("background-fetch"), "Background fetch mode should be enabled")
        }
    }
    
    func testNoHardcodedTokens() {
        // Verify that no hardcoded API tokens exist in the codebase
        let sourceFiles = findSwiftFiles()
        
        for file in sourceFiles {
            let content = try? String(contentsOfFile: file)
            if let fileContent = content {
                // Check for hardcoded OpenAI tokens
                if fileContent.contains("sk-") && !fileContent.contains("YOUR_OPENAI_API_KEY_HERE") {
                    XCTFail("Hardcoded API token found in \(file). Remove the token and use a placeholder.")
                }
                
                // Check for other common token patterns
                if fileContent.contains("Bearer ") && fileContent.contains("sk-") {
                    XCTFail("Hardcoded Bearer token found in \(file). Use environment variables or secure storage.")
                }
            }
        }
    }
    
    func testFileProtectionConfigured() {
        // Check that file protection is configured in audio-related code
        let audioFiles = [
            "TwinMindAssignment/Sources/Core/Audio/AudioRecorderEngine.swift",
            "TwinMindAssignment/Sources/Core/Audio/LiveTranscriber.swift"
        ]
        
        for file in audioFiles {
            let content = try? String(contentsOfFile: file, encoding: .utf8)
            if let fileContent = content {
                // Should contain file protection configuration
                let hasFileProtection = fileContent.contains("FileProtectionType.complete") || 
                                      fileContent.contains(".complete") ||
                                      fileContent.contains("FileProtectionType")
                
                XCTAssertTrue(hasFileProtection, "File \(file) should contain file protection configuration")
            } else {
                // File not found, skip test
                print("Warning: Could not read file \(file) for file protection test")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findSwiftFiles() -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []
        
        // Search in main source directories
        let searchPaths = [
            "TwinMindAssignment/Sources",
            "TwinMindAssignment"
        ]
        
        for path in searchPaths {
            guard let enumerator = fileManager.enumerator(atPath: path) else { continue }
            
            while let filePath = enumerator.nextObject() as? String {
                if filePath.hasSuffix(".swift") {
                    swiftFiles.append("\(path)/\(filePath)")
                }
            }
        }
        
        return swiftFiles
    }
} 
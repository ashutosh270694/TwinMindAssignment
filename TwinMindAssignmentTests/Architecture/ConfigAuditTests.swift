import XCTest
import Foundation
@testable import TwinMindAssignment

final class ConfigAuditTests: XCTestCase {
    
    // MARK: - Configuration Audit Tests
    
    func testProjectConfigurationAudit() throws {
        // This test runs the audit script to validate project configuration
        // It will fail with actionable messages if any configuration issues are found
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        
        // Get the path to the audit script
        let bundle = Bundle(for: type(of: self))
        guard let scriptPath = bundle.path(forResource: "audit_config", ofType: "swift") else {
            XCTFail("audit_config.swift not found in test bundle")
            return
        }
        
        // Set up the process
        process.arguments = [scriptPath, "--run"]
        process.environment = [
            "PROJECT_ROOT": FileManager.default.currentDirectoryPath
        ]
        
        // Capture output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Run the audit
        try process.run()
        process.waitUntilExit()
        
        // Get output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        // Print output for debugging
        print("🔍 Audit Output:")
        print(output)
        if !error.isEmpty {
            print("⚠️ Audit Errors:")
            print(error)
        }
        
        // Test should pass only if audit script exits with code 0
        XCTAssertEqual(process.terminationStatus, 0, 
                      "Configuration audit failed. Check the output above for specific issues.")
        
        // Additional assertions based on audit output
        XCTAssertTrue(output.contains("✅"), "Audit should show some passed checks")
        
        if output.contains("❌") {
            XCTFail("Configuration audit found issues. Review the output above and fix the configuration problems.")
        }
    }
    
    func testInfoPlistExists() {
        // Verify Info.plist exists and is accessible
        let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist")
        XCTAssertNotNil(infoPlistPath, "Info.plist should exist in the main bundle")
        
        if let path = infoPlistPath {
            let plistData = try? Data(contentsOf: URL(fileURLWithPath: path))
            XCTAssertNotNil(plistData, "Info.plist should be readable")
        }
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
            let content = try? String(contentsOfFile: file)
            if let fileContent = content {
                // Should contain file protection configuration
                let hasFileProtection = fileContent.contains("FileProtectionType.complete") || 
                                      fileContent.contains(".complete") ||
                                      fileContent.contains("FileProtectionType")
                
                if !hasFileProtection {
                    XCTFail("File protection not configured in \(file). Audio files should be encrypted at rest.")
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
#!/usr/bin/env swift

import Foundation

/// Configuration audit script for iOS app
/// Validates Info.plist, entitlements, and build settings

// MARK: - Configuration Validator

class ConfigurationValidator {
    
    // MARK: - Properties
    
    private let projectRoot: String
    private let infoPlistPath: String
    private let entitlementsPath: String
    
    private var errors: [String] = []
    private var warnings: [String] = []
    
    // MARK: - Initialization
    
    init(projectRoot: String) {
        self.projectRoot = projectRoot
        self.infoPlistPath = "\(projectRoot)/TwinMindAssignment/Info.plist"
        self.entitlementsPath = "\(projectRoot)/TwinMindAssignment/TwinMindAssignment.entitlements"
    }
    
    // MARK: - Public Methods
    
    func validate() -> Bool {
        print("🔍 Starting configuration audit...")
        
        validateInfoPlist()
        validateEntitlements()
        validateBuildSettings()
        validateATS()
        validateFrameworks()
        validateFileProtection()
        
        // Print results
        printResults()
        
        return errors.isEmpty
    }
    
    // MARK: - Validation Methods
    
    private func validateInfoPlist() {
        print("📱 Validating Info.plist...")
        
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            errors.append("❌ Failed to read Info.plist")
            return
        }
        
        // Check required usage descriptions
        let requiredDescriptions = [
            "NSMicrophoneUsageDescription": "Microphone access for audio recording",
            "NSSpeechRecognitionUsageDescription": "Speech recognition for transcription fallback"
        ]
        
        for (key, description) in requiredDescriptions {
            if plist[key] == nil {
                errors.append("❌ Missing \(key): \(description)")
            } else {
                print("✅ \(key) present")
            }
        }
        
        // Check background modes
        if let backgroundModes = plist["UIBackgroundModes"] as? [String] {
            let requiredModes = ["audio", "processing", "fetch"]
            for mode in requiredModes {
                if backgroundModes.contains(mode) {
                    print("✅ Background mode '\(mode)' present")
                } else {
                    warnings.append("⚠️ Background mode '\(mode)' missing")
                }
            }
        } else {
            errors.append("❌ UIBackgroundModes not configured")
        }
        
        // Check ATS settings
        if let ats = plist["NSAppTransportSecurity"] as? [String: Any] {
            if ats["NSAllowsArbitraryLoads"] as? Bool == true {
                warnings.append("⚠️ NSAllowsArbitraryLoads is enabled (security risk)")
            }
            
            if let exceptions = ats["NSExceptionDomains"] as? [String: Any] {
                for (domain, config) in exceptions {
                    if let domainConfig = config as? [String: Any],
                       domainConfig["NSExceptionAllowsInsecureHTTPLoads"] as? Bool == true {
                        warnings.append("⚠️ HTTP allowed for domain: \(domain)")
                    }
                }
            }
        } else {
            print("✅ ATS configured (defaults to HTTPS only)")
        }
    }
    
    private func validateEntitlements() {
        print("🔐 Validating entitlements...")
        
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: entitlementsPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            errors.append("❌ Failed to read entitlements file")
            return
        }
        
        // Check background modes
        if let backgroundModes = plist["com.apple.developer.background-modes"] as? [String] {
            let requiredModes = ["audio", "processing", "fetch"]
            for mode in requiredModes {
                if backgroundModes.contains(mode) {
                    print("✅ Background mode '\(mode)' in entitlements")
                } else {
                    errors.append("❌ Background mode '\(mode)' missing from entitlements")
                }
            }
        } else {
            errors.append("❌ Background modes not configured in entitlements")
        }
        
        // Check keychain access
        if let keychainGroups = plist["keychain-access-groups"] as? [String] {
            print("✅ Keychain access groups configured")
        } else {
            warnings.append("⚠️ Keychain access groups not configured")
        }
    }
    
    private func validateBuildSettings() {
        print("⚙️ Validating build settings...")
        
        // Check if project file exists
        let projectPath = "\(projectRoot)/TwinMindAssignment.xcodeproj"
        if FileManager.default.fileExists(atPath: projectPath) {
            print("✅ Xcode project found")
        } else {
            errors.append("❌ Xcode project not found")
        }
        
        // Check deployment target
        // This would require parsing the project.pbxproj file
        // For now, we'll assume it's set correctly
        print("ℹ️ Deployment target check requires project.pbxproj parsing")
    }
    
    private func validateATS() {
        print("🌐 Validating App Transport Security...")
        
        // Check if we're using HTTPS for API calls
        let sourceFiles = findSwiftFiles(in: "\(projectRoot)/TwinMindAssignment/Sources")
        
        var hasHTTPUsage = false
        for file in sourceFiles {
            if let content = try? String(contentsOfFile: file) {
                if content.contains("http://") && !content.contains("// TODO:") {
                    hasHTTPUsage = true
                    warnings.append("⚠️ HTTP usage found in \(file)")
                }
            }
        }
        
        if !hasHTTPUsage {
            print("✅ No HTTP usage found in source code")
        }
    }
    
    private func validateFrameworks() {
        print("📚 Validating framework usage...")
        
        let requiredFrameworks = [
            "AVFoundation",
            "Speech",
            "BackgroundTasks",
            "SwiftData"
        ]
        
        for framework in requiredFrameworks {
            if isFrameworkLinked(framework) {
                print("✅ \(framework) framework linked")
            } else {
                warnings.append("⚠️ \(framework) framework not linked")
            }
        }
    }
    
    private func validateFileProtection() {
        print("🔒 Validating file protection...")
        
        let sourceFiles = findSwiftFiles(in: "\(projectRoot)/TwinMindAssignment/Sources")
        
        var hasFileProtection = false
        for file in sourceFiles {
            if let content = try? String(contentsOfFile: file) {
                if content.contains("FileProtectionType.complete") {
                    hasFileProtection = true
                    break
                }
            }
        }
        
        if hasFileProtection {
            print("✅ File protection configured")
        } else {
            warnings.append("⚠️ FileProtectionType.complete not found in source code")
        }
    }
    
    // MARK: - Helper Methods
    
    private func findSwiftFiles(in directory: String) -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []
        
        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return swiftFiles
        }
        
        while let filePath = enumerator.nextObject() as? String {
            if filePath.hasSuffix(".swift") {
                swiftFiles.append("\(directory)/\(filePath)")
            }
        }
        
        return swiftFiles
    }
    
    private func isFrameworkLinked(_ framework: String) -> Bool {
        // This is a simplified check - in a real implementation,
        // you would parse the project.pbxproj file to check linking
        let projectPath = "\(projectRoot)/TwinMindAssignment.xcodeproj/project.pbxproj"
        
        if let content = try? String(contentsOfFile: projectPath) {
            return content.contains(framework)
        }
        
        return false
    }
    
    private func printResults() {
        print("\n📊 Audit Results:")
        print("==================")
        
        if errors.isEmpty && warnings.isEmpty {
            print("🎉 All checks passed!")
        } else {
            if !errors.isEmpty {
                print("\n❌ Errors (\(errors.count)):")
                for error in errors {
                    print("  \(error)")
                }
            }
            
            if !warnings.isEmpty {
                print("\n⚠️ Warnings (\(warnings.count)):")
                for warning in warnings {
                    print("  \(warning)")
                }
            }
        }
        
        print("\nBuild will \(errors.isEmpty ? "succeed" : "fail") due to configuration issues.")
    }
}

// MARK: - Main Execution

func main() {
    let currentDirectory = FileManager.default.currentDirectoryPath
    let validator = ConfigurationValidator(projectRoot: currentDirectory)
    
    let success = validator.validate()
    
    // Exit with appropriate code
    exit(success ? 0 : 1)
}

// Run the script
main() 
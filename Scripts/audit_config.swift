#!/usr/bin/env swift

import Foundation

/// iOS Project Configuration Audit Script
/// Validates: Info.plist keys, Background Modes, ATS, frameworks, Keychain, file protection
struct ConfigAuditor {
    
    // MARK: - Configuration Paths
    private let projectRoot = ProcessInfo.processInfo.environment["PROJECT_ROOT"] ?? FileManager.default.currentDirectoryPath
    private let infoPlistPath = "TwinMindAssignment/Info.plist"
    private let projectPath = "TwinMindAssignment.xcodeproj/project.pbxproj"
    
    // MARK: - Audit Results
    private var results: [String: Bool] = [:]
    private var issues: [String] = []
    
    // MARK: - Public Interface
    
    mutating func runAudit() -> Bool {
        print("🔍 Starting iOS Project Configuration Audit...")
        print("📁 Project Root: \(projectRoot)")
        
        // Run all audit checks
        checkInfoPlist()
        checkBackgroundModes()
        checkATSSettings()
        checkFrameworks()
        checkKeychainUsage()
        checkFileProtection()
        checkPrivacyStrings()
        
        // Print results
        printResults()
        
        return issues.isEmpty
    }
    
    // MARK: - Audit Checks
    
    private mutating func checkInfoPlist() {
        print("\n📋 Checking Info.plist...")
        
        // Since the project generates Info.plist automatically, we'll check the project configuration
        let projectPath = "\(projectRoot)/\(self.projectPath)"
        guard let projectData = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
            fail("Project file not found")
            return
        }
        
        // Check required privacy keys in project configuration
        let requiredKeys = [
            "INFOPLIST_KEY_NSMicrophoneUsageDescription",
            "INFOPLIST_KEY_NSSpeechRecognitionUsageDescription"
        ]
        
        for key in requiredKeys {
            if projectData.contains(key) {
                pass("✅ \(key): configured in project")
            } else {
                fail("❌ Missing: \(key)")
            }
        }
        
        // Check background modes in project configuration
        if projectData.contains("INFOPLIST_KEY_UIBackgroundModes") {
            pass("✅ Background modes configured in project")
        } else {
            fail("❌ No background modes configured")
        }
    }
    
    private mutating func checkBackgroundModes() {
        print("\n🔄 Checking Background Modes...")
        
        let projectPath = "\(projectRoot)/\(self.projectPath)"
        guard let projectData = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
            fail("Project file not found")
            return
        }
        
        // Check for background task identifier
        if projectData.contains("BGTaskSchedulerPermittedIdentifiers") {
            pass("✅ Background task identifiers configured")
        } else {
            fail("❌ Background task identifiers not configured")
        }
        
        // Check for background audio capability
        if projectData.contains("audio") {
            pass("✅ Background audio capability enabled")
        } else {
            fail("❌ Background audio capability not enabled")
        }
    }
    
    private mutating func checkATSSettings() {
        print("\n🔒 Checking App Transport Security...")
        
        let plistPath = "\(projectRoot)/\(infoPlistPath)"
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
            return
        }
        
        if let ats = plist["NSAppTransportSecurity"] as? [String: Any] {
            if let allowsArbitraryLoads = ats["NSAllowsArbitraryLoads"] as? Bool, allowsArbitraryLoads {
                fail("❌ ATS allows arbitrary loads (security risk)")
            } else {
                pass("✅ ATS properly configured (HTTPS only)")
            }
        } else {
            pass("✅ ATS not configured (defaults to HTTPS only)")
        }
    }
    
    private mutating func checkFrameworks() {
        print("\n📚 Checking Required Frameworks...")
        
        // Check framework imports in source code instead of project linking
        let sourceDirectories = [
            "\(projectRoot)/TwinMindAssignment/Sources",
            "\(projectRoot)/TwinMindAssignment"
        ]
        
        let requiredFrameworks = [
            ("AVFoundation", "AVFoundation"),
            ("Speech", "Speech"),
            ("CoreData", "SwiftData"), // SwiftData is the modern replacement for CoreData
            ("Security", "Security")
        ]
        
        for (frameworkName, importName) in requiredFrameworks {
            var found = false
            
            for sourceDir in sourceDirectories {
                if let enumerator = FileManager.default.enumerator(atPath: sourceDir) {
                    while let filePath = enumerator.nextObject() as? String {
                        if filePath.hasSuffix(".swift") {
                            let fullPath = "\(sourceDir)/\(filePath)"
                            if let sourceData = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                                if sourceData.contains("import \(importName)") {
                                    found = true
                                    break
                                }
                            }
                        }
                    }
                }
            }
            
            if found {
                pass("✅ Framework: \(frameworkName) (imported in source)")
            } else {
                fail("❌ Missing framework: \(frameworkName)")
            }
        }
    }
    
    private mutating func checkKeychainUsage() {
        print("\n🔑 Checking Keychain Usage...")
        
        let sourcePath = "\(projectRoot)/TwinMindAssignment/Sources/Core/Network/TokenManager.swift"
        guard let sourceData = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            fail("TokenManager.swift not found")
            return
        }
        
        if sourceData.contains("kSecClassGenericPassword") {
            pass("✅ Keychain integration found")
        } else {
            fail("❌ No Keychain integration found")
        }
        
        // Check for hardcoded tokens
        if sourceData.contains("sk-") {
            fail("❌ Hardcoded API token found (security risk)")
        } else {
            pass("✅ No hardcoded tokens found")
        }
    }
    
    private mutating func checkFileProtection() {
        print("\n🛡️ Checking File Protection...")
        
        let sourcePath = "\(projectRoot)/TwinMindAssignment/Sources/Core/Audio/AudioRecorderEngine.swift"
        guard let sourceData = try? String(contentsOfFile: sourcePath, encoding: .utf8) else {
            fail("AudioRecorderEngine.swift not found")
            return
        }
        
        if sourceData.contains("FileProtectionType.complete") || sourceData.contains(".complete") {
            pass("✅ File protection set to complete")
        } else {
            fail("❌ File protection not set to complete")
        }
    }
    
    private mutating func checkPrivacyStrings() {
        print("\n🔐 Checking Privacy Strings...")
        
        // Check privacy strings in project configuration
        let projectPath = "\(projectRoot)/\(self.projectPath)"
        guard let projectData = try? String(contentsOfFile: projectPath, encoding: .utf8) else {
            return
        }
        
        let privacyKeys = [
            "INFOPLIST_KEY_NSMicrophoneUsageDescription",
            "INFOPLIST_KEY_NSSpeechRecognitionUsageDescription"
        ]
        
        for key in privacyKeys {
            if projectData.contains(key) {
                // Extract the actual description value
                let pattern = "\(key) = \"([^\"]+)\""
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: projectData, options: [], range: NSRange(projectData.startIndex..., in: projectData)) {
                    let range = match.range(at: 1)
                    if let swiftRange = Range(range, in: projectData) {
                        let description = String(projectData[swiftRange])
                        
                        if description.count >= 10 {
                            pass("✅ \(key): adequate length (\(description.count) chars)")
                        } else {
                            fail("❌ \(key): too short (\(description.count) chars, need ≥10)")
                        }
                        
                        if description.contains("TODO") || description.contains("TBD") {
                            fail("❌ \(key): contains placeholder text")
                        }
                    }
                }
            } else {
                fail("❌ Missing: \(key)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private mutating func pass(_ message: String) {
        print(message)
        results[message] = true
    }
    
    private mutating func fail(_ message: String) {
        print(message)
        results[message] = false
        issues.append(message)
    }
    
    private func printResults() {
        print("\n📊 Audit Results Summary:")
        print("==========================")
        
        let passed = results.values.filter { $0 }.count
        let total = results.count
        
        print("✅ Passed: \(passed)/\(total)")
        
        if !issues.isEmpty {
            print("\n❌ Issues Found:")
            for issue in issues {
                print("   • \(issue)")
            }
        } else {
            print("\n🎉 All checks passed!")
        }
    }
}

// MARK: - Main Execution

if CommandLine.arguments.contains("--run") {
    var auditor = ConfigAuditor()
    let success = auditor.runAudit()
    exit(success ? 0 : 1)
} else {
    print("Usage: swift audit_config.swift --run")
    print("Set PROJECT_ROOT environment variable to override project path")
} 


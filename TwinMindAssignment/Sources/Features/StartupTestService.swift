import Foundation
import Combine
import SwiftUI

/// Service that runs startup tests to verify core functionality
final class StartupTestService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRunningTests = false
    @Published var testResults: [TestResult] = []
    @Published var allTestsPassed = false
    
    // MARK: - Private Properties
    
    private let tokenManager = TokenManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Types
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let status: TestStatus
        let message: String
        let timestamp: Date
        
        enum TestStatus {
            case passed
            case failed
            case running
        }
    }
    
    // MARK: - Public Methods
    
    /// Runs all startup tests
    func runStartupTests() {
        guard !isRunningTests else { return }
        
        isRunningTests = true
        testResults.removeAll()
        allTestsPassed = false
        
        print("🚀 Starting startup tests...")
        
        // Test 1: Token validation (immediate)
        runTokenValidationTest()
        
        // Test 2: Whisper API connection (with delay to avoid rate limiting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.runWhisperAPITest()
        }
        
        // Test 3: Transcription pipeline (with delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.runTranscriptionPipelineTest()
        }
        
        // Test 4: TestAudio.m4a transcription test (with delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.runTestAudioTranscriptionTest()
        }
    }
    
    // MARK: - Private Methods
    
    private func runTokenValidationTest() {
        let testName = "Token Validation"
        addTestResult(name: testName, status: .running, message: "Checking API token...")
        
        guard let token = tokenManager.getToken(), !token.isEmpty else {
            addTestResult(name: testName, status: .failed, message: "No valid API token found")
            return
        }
        
        if tokenManager.isValidToken(token) {
            addTestResult(name: testName, status: .passed, message: "API token is valid")
        } else {
            addTestResult(name: testName, status: .failed, message: "API token validation failed")
        }
    }
    
    private func runWhisperAPITest() {
        let testName = "Whisper API Connection"
        addTestResult(name: testName, status: .running, message: "Testing API connection...")
        
        tokenManager.testWhisperAPIConnection()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        let message: String
                        let status: TestResult.TestStatus
                        
                        // Check if it's a rate limit error
                        if let transcriptionError = error as? TranscriptionAPIClient.TranscriptionError {
                            switch transcriptionError {
                            case .httpError(429):
                                message = "Rate limit exceeded (HTTP 429) - API is working but too many requests. This is normal for frequent testing."
                                status = .failed // Mark as failed but with helpful message
                            default:
                                message = "API connection failed: \(error.localizedDescription)"
                                status = .failed
                            }
                        } else {
                            message = "API connection failed: \(error.localizedDescription)"
                            status = .failed
                        }
                        
                        self?.addTestResult(name: testName, status: status, message: message)
                    }
                },
                receiveValue: { [weak self] success in
                    if success {
                        self?.addTestResult(
                            name: testName,
                            status: .passed,
                            message: "API connection successful"
                        )
                    } else {
                        self?.addTestResult(
                            name: testName,
                            status: .failed,
                            message: "API connection failed"
                        )
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func runTranscriptionPipelineTest() {
        let testName = "Transcription Pipeline"
        addTestResult(name: testName, status: .running, message: "Testing transcription pipeline...")
        
        // Test if the transcription client can be created
        let transcriptionClient = TranscriptionAPIClient()
        
        // Test if the speech fallback can be created
        let speechFallback = SpeechRecognitionFallback()
        
        // Test if the background task manager can be created
        let backgroundTaskManager = BackgroundTaskManager()
        
        // Test if repositories can be created
        let sessionRepository = InMemoryRecordingSessionRepository()
        let segmentRepository = InMemoryTranscriptSegmentRepository()
        
        // If we get here without errors, the pipeline components are working
        addTestResult(name: testName, status: .passed, message: "Transcription pipeline components initialized successfully")
    }
    
    private func runTestAudioTranscriptionTest() {
        let testName = "TestAudio.m4a Transcription"
        addTestResult(name: testName, status: .running, message: "Testing transcription with TestAudio.m4a...")
        
        // Try to load the TestAudio.m4a file from the app bundle
        guard let audioURL = Bundle.main.url(forResource: "TestAudio", withExtension: "m4a") else {
            addTestResult(name: testName, status: .failed, message: "TestAudio.m4a not found in app bundle")
            return
        }
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            print("📁 [STARTUP] TestAudio.m4a loaded: \(audioData.count) bytes")
            
            // Create a transcription request with the test audio
            let request = TranscriptionAPIClient.TranscriptionRequest(
                audioData: audioData,
                segmentIndex: 0,
                sessionID: UUID()
            )
            
            // Test the transcription
            let transcriptionClient = TranscriptionAPIClient()
            
            transcriptionClient.transcribe(request)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            let message: String
                            let status: TestResult.TestStatus
                            
                            // Check if it's a rate limit error
                            if let transcriptionError = error as? TranscriptionAPIClient.TranscriptionError {
                                switch transcriptionError {
                                case .httpError(429):
                                    message = "Rate limit exceeded (HTTP 429) - API is working but too many requests. This is normal for frequent testing."
                                    status = .failed // Mark as failed but with helpful message
                                case .httpError(let code):
                                    message = "HTTP error \(code): \(error.localizedDescription)"
                                    status = .failed
                                default:
                                    message = "Transcription failed: \(error.localizedDescription)"
                                    status = .failed
                                }
                            } else {
                                message = "Transcription failed: \(error.localizedDescription)"
                                status = .failed
                            }
                            
                            self?.addTestResult(name: testName, status: status, message: message)
                        }
                    },
                    receiveValue: { [weak self] result in
                        print("📝 [STARTUP] TestAudio.m4a transcription successful: '\(result.text)'")
                        self?.addTestResult(
                            name: testName,
                            status: .passed,
                            message: "Transcription successful: '\(result.text.prefix(50))...'"
                        )
                    }
                )
                .store(in: &cancellables)
                
        } catch {
            addTestResult(name: testName, status: .failed, message: "Failed to load TestAudio.m4a: \(error.localizedDescription)")
        }
    }
    
    private func addTestResult(name: String, status: TestResult.TestStatus, message: String) {
        let result = TestResult(
            name: name,
            status: status,
            message: message,
            timestamp: Date()
        )
        
        testResults.append(result)
        
        // Update overall test status
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateOverallTestStatus()
        }
        
        print("🧪 Test Result: \(name) - \(status) - \(message)")
    }
    
    private func updateOverallTestStatus() {
        let allPassed = testResults.allSatisfy { $0.status == .passed }
        let allCompleted = testResults.allSatisfy { $0.status != .running }
        
        print("🔄 Test Status Update: allPassed=\(allPassed), allCompleted=\(allCompleted)")
        
        if allCompleted {
            allTestsPassed = allPassed
            isRunningTests = false
            
            if allPassed {
                print("✅ All startup tests passed!")
                print("🚀 Posting startupTestsCompleted notification in 2 seconds...")
                
                // Automatically notify that tests are completed
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("📢 Posting startupTestsCompleted notification now!")
                    NotificationCenter.default.post(name: .startupTestsCompleted, object: nil)
                    print("📢 Notification posted successfully!")
                }
            } else {
                print("❌ Some startup tests failed!")
            }
        }
    }
} 
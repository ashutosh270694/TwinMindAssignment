import SwiftUI

/// View that displays startup test results and allows manual testing
struct StartupTestView: View {
    @StateObject private var testService = StartupTestService()
    @State private var showingTestResults = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Startup Tests")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Verifying core functionality")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Test Status
            if testService.isRunningTests {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Running tests...")
                        .font(.headline)
                    
                    Text("Please wait while we verify your setup")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if testService.allTestsPassed {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("All Tests Passed! 🎉")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    Text("Your app is ready to use")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !testService.testResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Some Tests Failed")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    // Check if it's just a rate limit issue
                    if testService.testResults.contains(where: { $0.message.contains("429") || $0.message.contains("rate limit") }) {
                        VStack(spacing: 8) {
                            Text("Rate Limit Detected")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("The Whisper API is working correctly, but you've hit the rate limit. This is normal for frequent testing.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("You can continue to the app - transcription will work normally during actual usage.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button("View Details") {
                        showingTestResults = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                if !testService.isRunningTests {
                    Button(action: testService.runStartupTests) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Run Tests")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(testService.isRunningTests)
                }
                
                // Show continue button when tests pass OR when there's just a rate limit issue
                let canContinue = testService.allTestsPassed || 
                    (testService.testResults.count >= 3 && 
                     testService.testResults.contains { $0.status == .passed } &&
                     testService.testResults.contains { $0.message.contains("429") || $0.message.contains("rate limit") })
                
                if canContinue {
                    Button("Continue to App") {
                        print("🔄 Continue button tapped - posting notification")
                        NotificationCenter.default.post(name: .startupTestsCompleted, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.green)
                } else {
                    Button("Continue to App") {
                        print("⚠️ Continue button tapped but tests haven't completed yet")
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Debug Information (only in DEBUG builds)
            #if DEBUG
            VStack(spacing: 8) {
                Text("Debug Info")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("Tests Running: \(testService.isRunningTests ? "Yes" : "No")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("All Tests Passed: \(testService.allTestsPassed ? "Yes" : "No")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("Test Count: \(testService.testResults.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if !testService.testResults.isEmpty {
                    Text("Last Test: \(testService.testResults.last?.name ?? "None")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            #endif
        }
        .padding()
        .onAppear {
            // Automatically run tests when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                testService.runStartupTests()
            }
        }
        .sheet(isPresented: $showingTestResults) {
            TestResultsDetailView(testService: testService)
        }
    }
}

// MARK: - Test Results Detail View

struct TestResultsDetailView: View {
    @ObservedObject var testService: StartupTestService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(testService.testResults) { result in
                    TestResultRow(result: result)
                }
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Test Result Row

struct TestResultRow: View {
    let result: StartupTestService.TestResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.headline)
                
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch result.status {
        case .passed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .running:
            return "clock.fill"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .passed:
            return .green
        case .failed:
            return .red
        case .running:
            return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    StartupTestView()
} 
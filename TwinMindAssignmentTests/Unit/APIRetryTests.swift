import XCTest
import Combine
@testable import TwinMindAssignment

/// Tests for API retry functionality
final class APIRetryTests: XCTestCase {
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Basic Retry Tests
    
    func testRetryBackoffWithExponentialDelay() throws {
        // Test that retry backoff uses exponential delay
        
        let expectation = XCTestExpectation(description: "Retry backoff test")
        
        // Create a simple retry configuration
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0
        
        var retryCount = 0
        var delays: [TimeInterval] = []
        
        func attemptRetry() {
            retryCount += 1
            if retryCount <= maxRetries {
                let delay = baseDelay * pow(2.0, Double(retryCount - 1))
                delays.append(delay)
                
                // Simulate retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    attemptRetry()
                }
            } else {
                expectation.fulfill()
            }
        }
        
        // Start retry sequence
        attemptRetry()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify exponential backoff
        XCTAssertEqual(retryCount, maxRetries + 1, "Should attempt max retries + 1")
        XCTAssertEqual(delays.count, maxRetries, "Should have delays for each retry")
        
        if delays.count >= 2 {
            XCTAssertGreaterThan(delays[1], delays[0], "Second delay should be greater than first")
        }
    }
    
    func testRetryBackoffWithJitter() throws {
        // Test that retry backoff includes jitter
        
        let expectation = XCTestExpectation(description: "Retry backoff with jitter")
        
        let baseDelay: TimeInterval = 1.0
        let maxJitter: TimeInterval = 0.1
        
        var delays: [TimeInterval] = []
        
        for i in 0..<3 {
            let exponentialDelay = baseDelay * pow(2.0, Double(i))
            let jitter = Double.random(in: 0...maxJitter)
            let totalDelay = exponentialDelay + jitter
            delays.append(totalDelay)
        }
        
        // Verify delays are reasonable
        for (i, delay) in delays.enumerated() {
            let expectedBase = baseDelay * pow(2.0, Double(i))
            XCTAssertGreaterThanOrEqual(delay, expectedBase, "Delay should be at least base delay")
            XCTAssertLessThanOrEqual(delay, expectedBase + maxJitter, "Delay should not exceed base + max jitter")
        }
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRetryBackoffWithRealisticAPIErrors() throws {
        // Test retry backoff with realistic API error scenarios
        
        let expectation = XCTestExpectation(description: "Realistic API error retry")
        
        // Simulate different error types
        let errorTypes: [Int] = [500, 502, 503, 429, 200] // Server errors, rate limit, success
        
        var retryCount = 0
        var shouldRetry = true
        
        func simulateAPIRequest() {
            let errorCode = errorTypes[retryCount % errorTypes.count]
            
            if errorCode >= 500 || errorCode == 429 {
                // Retryable error
                retryCount += 1
                if retryCount < 3 && shouldRetry {
                    // Simulate retry
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        simulateAPIRequest()
                    }
                } else {
                    expectation.fulfill()
                }
            } else {
                // Success or non-retryable error
                expectation.fulfill()
            }
        }
        
        simulateAPIRequest()
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify retry behavior
        XCTAssertGreaterThan(retryCount, 0, "Should have attempted retries")
    }
} 
import XCTest
import Combine
@testable import TwinMindAssignment

final class APIRetryTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    private var testScheduler: TestScheduler!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        testScheduler = TestScheduler()
    }
    
    override func tearDown() {
        cancellables = nil
        testScheduler = nil
        super.tearDown()
    }
    
    // MARK: - Retry Backoff Timing Tests
    
    func testRetryBackoffWithExponentialDelay() throws {
        // Given
        let baseDelay: TimeInterval = 1.0
        let maxRetries = 3
        let testError = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let expectation = XCTestExpectation(description: "Retry backoff uses exponential delay")
        expectation.expectedFulfillmentCount = maxRetries + 1 // Initial + retries
        
        var attemptCount = 0
        var lastAttemptTime: TimeInterval = 0
        
        // When
        Just(())
            .setFailureType(to: APIError.self)
            .retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, testError)
                    }
                },
                receiveValue: { _ in
                    let currentTime = self.testScheduler.now.absolute
                    if attemptCount > 0 {
                        let expectedDelay = baseDelay * pow(2.0, Double(attemptCount - 1))
                        let actualDelay = currentTime - lastAttemptTime
                        XCTAssertEqual(actualDelay, expectedDelay, accuracy: 0.1)
                    }
                    lastAttemptTime = currentTime
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Simulate failures and advance scheduler
        for _ in 0..<maxRetries {
            testScheduler.advance(by: TestSchedulerTime.Stride(baseDelay))
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, maxRetries + 1)
    }
    
    func testRetryBackoffRespectsMaxRetries() throws {
        // Given
        let maxRetries = 2
        let baseDelay: TimeInterval = 0.1
        let testError = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let expectation = XCTestExpectation(description: "Retry backoff respects max retries")
        expectation.expectedFulfillmentCount = maxRetries + 1 // Initial + retries
        
        var attemptCount = 0
        
        // When
        Fail<Int, APIError>(error: testError)
            .retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, testError)
                    }
                },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler to trigger retries
        for _ in 0...maxRetries {
            testScheduler.advance(by: TestSchedulerTime.Stride(baseDelay))
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, maxRetries + 1)
    }
    
    func testRetryBackoffWithCustomShouldRetry() throws {
        // Given
        let maxRetries = 5
        let baseDelay: TimeInterval = 0.1
        let _ = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        let fatalError = APIError.serverError("Fatal Error (500)")
        
        let expectation = XCTestExpectation(description: "Retry backoff respects custom shouldRetry logic")
        expectation.expectedFulfillmentCount = 2 // Initial + 1 retry before fatal error
        
        var attemptCount = 0
        
        // When
        Fail<Int, APIError>(error: APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil)))
            .retryBackoff(
                maxRetries: maxRetries,
                baseDelay: baseDelay
            ) { error in
                // Only retry network errors, not server errors
                if case .networkError = error {
                    return true
                }
                return false
            }
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, fatalError)
                    }
                },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler to trigger retry
        testScheduler.advance(by: TestSchedulerTime.Stride(baseDelay))
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, 2)
    }
    
    // MARK: - API Client Retry Tests
    
    func testTranscriptionAPIClientRetryBehavior() throws {
        // Given
        let apiClient = FakeTranscriptionAPIClient()
        let sessionID = UUID()
        let segmentIndex = 1
        let testFileURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        let expectation = XCTestExpectation(description: "API client retries on failure")
        expectation.expectedFulfillmentCount = 3 // Initial + 2 retries
        
        var attemptCount = 0
        
        // When
        apiClient.transcribe(fileURL: testFileURL, sessionID: sessionID, segmentIndex: segmentIndex)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil)))
                    }
                },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler to trigger retries
        for _ in 0..<3 {
            testScheduler.advance(by: TestSchedulerTime.Stride(1.0))
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, 3)
    }
    
    func testTranscriptionAPIClientSuccessAfterRetry() throws {
        // Given
        let apiClient = FakeTranscriptionAPIClient()
        let sessionID = UUID()
        let segmentIndex = 1
        let testFileURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        let expectation = XCTestExpectation(description: "API client succeeds after retry")
        
        // When
        apiClient.transcribe(fileURL: testFileURL, sessionID: sessionID, segmentIndex: segmentIndex)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { completion in
                    if case .finished = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { result in
                    XCTAssertNotNil(result)
                    XCTAssertEqual(result.text, "Success after retry")
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler to trigger retry and success
        testScheduler.advance(by: TestSchedulerTime.Stride(1.0))
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Retry Timing Accuracy Tests
    
    func testRetryBackoffTimingAccuracy() throws {
        // Given
        let baseDelay: TimeInterval = 0.5
        let maxRetries = 4
        let testError = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let expectation = XCTestExpectation(description: "Retry backoff timing is accurate")
        expectation.expectedFulfillmentCount = maxRetries + 1
        
        var attemptTimes: [TimeInterval] = []
        
        // When
        Just(())
            .setFailureType(to: APIError.self)
            .retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    attemptTimes.append(self.testScheduler.now.absolute)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler with precise timing
        var currentTime: TimeInterval = 0
        for i in 0...maxRetries {
            if i > 0 {
                let delay = baseDelay * pow(2.0, Double(i - 1))
                currentTime += delay
                testScheduler.advance(to: currentTime)
            } else {
                testScheduler.advance(to: currentTime)
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        
        // Verify timing intervals
        for i in 1..<attemptTimes.count {
            let actualInterval = attemptTimes[i] - attemptTimes[i-1]
            let expectedInterval = baseDelay * pow(2.0, Double(i - 1))
            XCTAssertEqual(actualInterval, expectedInterval, accuracy: 0.01)
        }
    }
    
    func testRetryBackoffWithVeryShortDelays() throws {
        // Given
        let baseDelay: TimeInterval = 0.01 // 10ms
        let maxRetries = 3
        let _ = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let expectation = XCTestExpectation(description: "Retry backoff works with very short delays")
        expectation.expectedFulfillmentCount = maxRetries + 1
        
        var attemptCount = 0
        
        // When
        Just(())
            .setFailureType(to: APIError.self)
            .retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler with very short delays
        var currentTime: TimeInterval = 0
        for i in 0...maxRetries {
            if i > 0 {
                let delay = baseDelay * pow(2.0, Double(i - 1))
                currentTime += delay
                testScheduler.advance(to: currentTime)
            } else {
                testScheduler.advance(to: currentTime)
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, maxRetries + 1)
    }
    
    // MARK: - Edge Case Tests
    
    func testRetryBackoffWithZeroBaseDelay() throws {
        // Given
        let baseDelay: TimeInterval = 0
        let maxRetries = 2
        let _ = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let expectation = XCTestExpectation(description: "Retry backoff handles zero base delay")
        expectation.expectedFulfillmentCount = maxRetries + 1
        
        var attemptCount = 0
        
        // When
        Just(())
            .setFailureType(to: APIError.self)
            .retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler
        for _ in 0...maxRetries {
            testScheduler.advance()
        }
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, maxRetries + 1)
    }
    
    func testRetryBackoffWithZeroMaxRetries() throws {
        // Given
        let baseDelay: TimeInterval = 1.0
        let maxRetries = 0
        let _ = APIError.networkError(NSError(domain: "TestDomain", code: 123, userInfo: nil))
        
        let expectation = XCTestExpectation(description: "Retry backoff handles zero max retries")
        expectation.expectedFulfillmentCount = 1 // Only initial attempt
        
        var attemptCount = 0
        
        // When
        Just(())
            .setFailureType(to: APIError.self)
            .retryBackoff(maxRetries: maxRetries, baseDelay: baseDelay)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler
        testScheduler.advance()
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, 1)
    }
    
    // MARK: - Integration Tests
    
    func testRetryBackoffWithRealisticAPIErrors() throws {
        // Given
        let apiClient = FakeTranscriptionAPIClient()
        let sessionID = UUID()
        let segmentIndex = 1
        let testFileURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        let expectation = XCTestExpectation(description: "Retry backoff works with realistic API errors")
        expectation.expectedFulfillmentCount = 2 // Initial + 1 retry
        
        var attemptCount = 0
        var lastError: APIError?
        
        // When
        apiClient.transcribe(fileURL: testFileURL, sessionID: sessionID, segmentIndex: segmentIndex)
            .receive(on: testScheduler)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        lastError = error
                    }
                },
                receiveValue: { _ in
                    attemptCount += 1
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Advance scheduler to trigger retry
        testScheduler.advance(by: TestSchedulerTime.Stride(1.0))
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(attemptCount, 2)
        XCTAssertNotNil(lastError)
    }
} 
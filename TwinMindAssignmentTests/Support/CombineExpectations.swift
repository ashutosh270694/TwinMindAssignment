import Foundation
import Combine
import XCTest

/// Helper for testing Combine publishers with expectations
struct CombineExpectations {
    
    /// Waits for a publisher to emit a value and returns it
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Returns: The emitted value
    /// - Throws: XCTFail if no value is emitted within timeout
    static func expectValue<T>(
        from publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let expectation = XCTestExpectation(description: "Publisher emitted value")
        var result: T?
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink { value in
                result = value
                expectation.fulfill()
            }
        
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        switch waitResult {
        case .completed:
            guard let value = result else {
                XCTFail("Publisher emitted nil value", file: file, line: line)
                throw CombineExpectationError.noValue
            }
            return value
        case .timedOut:
            XCTFail("Publisher did not emit value within timeout", file: file, line: line)
            throw CombineExpectationError.timeout
        case .incorrectOrder:
            XCTFail("Expectation order incorrect", file: file, line: line)
            throw CombineExpectationError.incorrectOrder
        case .interrupted:
            XCTFail("Expectation was interrupted", file: file, line: line)
            throw CombineExpectationError.interrupted
        case .invertedFulfillment:
            XCTFail("Inverted expectation was fulfilled", file: file, line: line)
            throw CombineExpectationError.invertedFulfillment
        @unknown default:
            XCTFail("Unknown expectation result", file: file, line: line)
            throw CombineExpectationError.unknown
        }
    }
    
    /// Waits for a publisher to emit a value and returns it, allowing errors
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Returns: The emitted value
    /// - Throws: XCTFail if no value is emitted within timeout or if an error occurs
    static func expectValue<T>(
        from publisher: AnyPublisher<T, Error>,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let expectation = XCTestExpectation(description: "Publisher emitted value")
        var result: T?
        var error: Error?
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    expectation.fulfill()
                },
                receiveValue: { value in
                    result = value
                }
            )
        
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        if let error = error {
            XCTFail("Publisher failed with error: \(error)", file: file, line: line)
            throw CombineExpectationError.publisherError(error)
        }
        
        switch waitResult {
        case .completed:
            guard let value = result else {
                XCTFail("Publisher emitted nil value", file: file, line: line)
                throw CombineExpectationError.noValue
            }
            return value
        case .timedOut:
            XCTFail("Publisher did not emit value within timeout", file: file, line: line)
            throw CombineExpectationError.timeout
        case .incorrectOrder:
            XCTFail("Expectation order incorrect", file: file, line: line)
            throw CombineExpectationError.incorrectOrder
        case .interrupted:
            XCTFail("Expectation was interrupted", file: file, line: line)
            throw CombineExpectationError.interrupted
        case .invertedFulfillment:
            XCTFail("Inverted expectation was fulfilled", file: file, line: line)
            throw CombineExpectationError.invertedFulfillment
        @unknown default:
            XCTFail("Unknown expectation result", file: file, line: line)
            throw CombineExpectationError.unknown
        }
    }
    
    /// Waits for a publisher to complete successfully
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Throws: XCTFail if completion doesn't occur within timeout or if an error occurs
    static func expectCompletion<T>(
        from publisher: AnyPublisher<T, Error>,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "Publisher completed successfully")
        var error: Error?
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        error = err
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
        
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        if let error = error {
            XCTFail("Publisher failed with error: \(error)", file: file, line: line)
            throw CombineExpectationError.publisherError(error)
        }
        
        switch waitResult {
        case .completed:
            return
        case .timedOut:
            XCTFail("Publisher did not complete within timeout", file: file, line: line)
            throw CombineExpectationError.timeout
        case .incorrectOrder:
            XCTFail("Expectation order incorrect", file: file, line: line)
            throw CombineExpectationError.incorrectOrder
        case .interrupted:
            XCTFail("Expectation was interrupted", file: file, line: line)
            throw CombineExpectationError.interrupted
        case .invertedFulfillment:
            XCTFail("Inverted expectation was fulfilled", file: file, line: line)
            throw CombineExpectationError.invertedFulfillment
        @unknown default:
            XCTFail("Unknown expectation result", file: file, line: line)
            throw CombineExpectationError.unknown
        }
    }
    
    /// Waits for a publisher to fail with a specific error
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - expectedError: The expected error
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Throws: XCTFail if failure doesn't occur within timeout or if wrong error occurs
    static func expectFailure<T>(
        from publisher: AnyPublisher<T, Error>,
        with expectedError: Error,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "Publisher failed with expected error")
        var receivedError: Error?
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in }
            )
        
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        switch waitResult {
        case .completed:
            guard let error = receivedError else {
                XCTFail("Publisher completed successfully instead of failing", file: file, line: line)
                throw CombineExpectationError.unexpectedSuccess
            }
            
            if !isEqual(error, expectedError) {
                XCTFail("Publisher failed with unexpected error: \(error), expected: \(expectedError)", file: file, line: line)
                throw CombineExpectationError.unexpectedError(error)
            }
            
        case .timedOut:
            XCTFail("Publisher did not fail within timeout", file: file, line: line)
            throw CombineExpectationError.timeout
        case .incorrectOrder:
            XCTFail("Expectation order incorrect", file: file, line: line)
            throw CombineExpectationError.incorrectOrder
        case .interrupted:
            XCTFail("Expectation was interrupted", file: file, line: line)
            throw CombineExpectationError.interrupted
        case .invertedFulfillment:
            XCTFail("Inverted expectation was fulfilled", file: file, line: line)
            throw CombineExpectationError.invertedFulfillment
        @unknown default:
            XCTFail("Unknown expectation result", file: file, line: line)
            throw CombineExpectationError.unknown
        }
    }
    
    /// Waits for a publisher to emit multiple values
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - count: The expected number of values
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Returns: Array of emitted values
    /// - Throws: XCTFail if expected count isn't reached within timeout
    static func expectValues<T>(
        from publisher: AnyPublisher<T, Never>,
        count: Int,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> [T] {
        let expectation = XCTestExpectation(description: "Publisher emitted \(count) values")
        var values: [T] = []
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink { value in
                values.append(value)
                if values.count == count {
                    expectation.fulfill()
                }
            }
        
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        switch waitResult {
        case .completed:
            if values.count != count {
                XCTFail("Publisher emitted \(values.count) values, expected \(count)", file: file, line: line)
                throw CombineExpectationError.unexpectedCount(values.count, count)
            }
            return values
        case .timedOut:
            XCTFail("Publisher did not emit \(count) values within timeout. Got \(values.count)", file: file, line: line)
            throw CombineExpectationError.timeout
        case .incorrectOrder:
            XCTFail("Expectation order incorrect", file: file, line: line)
            throw CombineExpectationError.incorrectOrder
        case .interrupted:
            XCTFail("Expectation was interrupted", file: file, line: line)
            throw CombineExpectationError.interrupted
        case .invertedFulfillment:
            XCTFail("Inverted expectation was fulfilled", file: file, line: line)
            throw CombineExpectationError.invertedFulfillment
        @unknown default:
            XCTFail("Unknown expectation result", file: file, line: line)
            throw CombineExpectationError.unknown
        }
    }
    
    /// Waits for a publisher to emit no values within a timeout
    /// - Parameters:
    ///   - publisher: The publisher to test
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Throws: XCTFail if any value is emitted
    static func expectNoValue<T>(
        from publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 0.1,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let expectation = XCTestExpectation(description: "Publisher emitted no values")
        expectation.isInverted = true
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink { _ in
                expectation.fulfill()
            }
        
        let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        switch waitResult {
        case .completed:
            XCTFail("Publisher emitted a value when none was expected", file: file, line: line)
            throw CombineExpectationError.unexpectedValue
        case .timedOut:
            // This is expected - no value was emitted
            return
        case .incorrectOrder:
            XCTFail("Expectation order incorrect", file: file, line: line)
            throw CombineExpectationError.incorrectOrder
        case .interrupted:
            XCTFail("Expectation was interrupted", file: file, line: line)
            throw CombineExpectationError.interrupted
        case .invertedFulfillment:
            XCTFail("Inverted expectation was fulfilled", file: file, line: line)
            throw CombineExpectationError.invertedFulfillment
        @unknown default:
            XCTFail("Unknown expectation result", file: file, line: line)
            throw CombineExpectationError.unknown
        }
    }
    
    // MARK: - Private Methods
    
    private static func isEqual(_ lhs: Error, _ rhs: Error) -> Bool {
        if let lhs = lhs as? NSError, let rhs = rhs as? NSError {
            return lhs.domain == rhs.domain && lhs.code == rhs.code
        }
        return lhs.localizedDescription == rhs.localizedDescription
    }
}

// MARK: - Combine Expectation Errors

enum CombineExpectationError: Error, LocalizedError {
    case timeout
    case noValue
    case unexpectedValue
    case unexpectedCount(Int, Int)
    case unexpectedError(Error)
    case unexpectedSuccess
    case incorrectOrder
    case interrupted
    case invertedFulfillment
    case unknown
    case publisherError(Error)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Expectation timed out"
        case .noValue:
            return "No value was emitted"
        case .unexpectedValue:
            return "Unexpected value was emitted"
        case .unexpectedCount(let actual, let expected):
            return "Unexpected count: got \(actual), expected \(expected)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error)"
        case .unexpectedSuccess:
            return "Unexpected success"
        case .incorrectOrder:
            return "Expectation order incorrect"
        case .interrupted:
            return "Expectation was interrupted"
        case .invertedFulfillment:
            return "Inverted expectation was fulfilled"
        case .unknown:
            return "Unknown expectation result"
        case .publisherError(let error):
            return "Publisher error: \(error)"
        }
    }
}

// MARK: - Publisher Testing Extensions

extension Publisher {
    
    /// Tests that the publisher emits a value within timeout
    /// - Parameters:
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Returns: The emitted value
    /// - Throws: XCTFail if no value is emitted within timeout
    func expectValue(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Output {
        if Self.Failure.self == Never.self {
            return try CombineExpectations.expectValue(
                from: self.eraseToAnyPublisher(),
                timeout: timeout,
                file: file,
                line: line
            )
        } else {
            // For publishers that can fail, we need to handle the error case
            let expectation = XCTestExpectation(description: "Publisher emitted value")
            var result: Output?
            var error: Error?
            
            let cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            error = err
                        }
                        expectation.fulfill()
                    },
                    receiveValue: { value in
                        result = value
                    }
                )
            
            let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
            
            if let error = error {
                XCTFail("Publisher failed with error: \(error)", file: file, line: line)
                throw CombineExpectationError.publisherError(error)
            }
            
            switch waitResult {
            case .completed:
                guard let value = result else {
                    XCTFail("Publisher emitted nil value", file: file, line: line)
                    throw CombineExpectationError.noValue
                }
                return value
            case .timedOut:
                XCTFail("Publisher did not emit value within timeout", file: file, line: line)
                throw CombineExpectationError.timeout
            case .incorrectOrder:
                XCTFail("Expectation order incorrect", file: file, line: line)
                throw CombineExpectationError.incorrectOrder
            case .interrupted:
                XCTFail("Expectation was interrupted", file: file, line: line)
                throw CombineExpectationError.interrupted
            case .invertedFulfillment:
                XCTFail("Inverted expectation was fulfilled", file: file, line: line)
                throw CombineExpectationError.invertedFulfillment
            @unknown default:
                XCTFail("Unknown expectation result", file: file, line: line)
                throw CombineExpectationError.unknown
            }
        }
    }
    
    /// Tests that the publisher emits multiple values within timeout
    /// - Parameters:
    ///   - count: The expected number of values
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Returns: Array of emitted values
    /// - Throws: XCTFail if expected count isn't reached within timeout
    func expectValues(
        count: Int,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> [Output] {
        if Self.Failure.self == Never.self {
            return try CombineExpectations.expectValues(
                from: self.eraseToAnyPublisher(),
                count: count,
                timeout: timeout,
                file: file,
                line: line
            )
        } else {
            // For publishers that can fail, we need to handle the error case
            let expectation = XCTestExpectation(description: "Publisher emitted \(count) values")
            var results: [Output] = []
            var error: Error?
            
            let cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            error = err
                        }
                        expectation.fulfill()
                    },
                    receiveValue: { value in
                        results.append(value)
                        if results.count >= count {
                            expectation.fulfill()
                        }
                    }
                )
            
            let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
            
            if let error = error {
                XCTFail("Publisher failed with error: \(error)", file: file, line: line)
                throw CombineExpectationError.publisherError(error)
            }
            
            switch waitResult {
            case .completed:
                if results.count >= count {
                    return Array(results.prefix(count))
                } else {
                    XCTFail("Publisher only emitted \(results.count) values, expected \(count)", file: file, line: line)
                    throw CombineExpectationError.timeout
                }
            case .timedOut:
                XCTFail("Publisher did not emit \(count) values within timeout", file: file, line: line)
                throw CombineExpectationError.timeout
            case .incorrectOrder:
                XCTFail("Expectation order incorrect", file: file, line: line)
                throw CombineExpectationError.incorrectOrder
            case .interrupted:
                XCTFail("Expectation was interrupted", file: file, line: line)
                throw CombineExpectationError.interrupted
            case .invertedFulfillment:
                XCTFail("Inverted expectation was fulfilled", file: file, line: line)
                throw CombineExpectationError.invertedFulfillment
            @unknown default:
                XCTFail("Unknown expectation result", file: file, line: line)
                throw CombineExpectationError.unknown
            }
        }
    }
    
    /// Tests that the publisher completes successfully within timeout
    /// - Parameters:
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Throws: XCTFail if completion doesn't occur within timeout or if an error occurs
    func expectCompletion(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if Self.Failure.self == Never.self {
            try CombineExpectations.expectCompletion(
                from: self.eraseToAnyPublisher(),
                timeout: timeout,
                file: file,
                line: line
            )
        } else {
            // For publishers that can fail, we need to handle the error case
            let expectation = XCTestExpectation(description: "Publisher completed")
            var error: Error?
            
            let cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            error = err
                        }
                        expectation.fulfill()
                    },
                    receiveValue: { _ in }
                )
            
            let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
            
            if let error = error {
                XCTFail("Publisher failed with error: \(error)", file: file, line: line)
                throw CombineExpectationError.publisherError(error)
            }
            
            switch waitResult {
            case .completed:
                break // Success
            case .timedOut:
                XCTFail("Publisher did not complete within timeout", file: file, line: line)
                throw CombineExpectationError.timeout
            case .incorrectOrder:
                XCTFail("Expectation order incorrect", file: file, line: line)
                throw CombineExpectationError.incorrectOrder
            case .interrupted:
                XCTFail("Expectation was interrupted", file: file, line: line)
                throw CombineExpectationError.interrupted
            case .invertedFulfillment:
                XCTFail("Inverted expectation was fulfilled", file: file, line: line)
                throw CombineExpectationError.invertedFulfillment
            @unknown default:
                XCTFail("Unknown expectation result", file: file, line: line)
                throw CombineExpectationError.unknown
            }
        }
    }
    
    /// Tests that the publisher fails with a specific error within timeout
    /// - Parameters:
    ///   - expectedError: The expected error
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Throws: XCTFail if failure doesn't occur within timeout or if wrong error occurs
    func expectFailure(
        with expectedError: Error,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if Self.Failure.self == Never.self {
            XCTFail("Publisher with Failure type Never cannot fail", file: file, line: line)
            throw CombineExpectationError.publisherError(NSError(domain: "TestError", code: -1, userInfo: nil))
        } else {
            // For publishers that can fail, we need to handle the error case
            let expectation = XCTestExpectation(description: "Publisher failed with expected error")
            var actualError: Error?
            
            let cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            actualError = err
                        }
                        expectation.fulfill()
                    },
                    receiveValue: { _ in }
                )
            
            let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
            
            switch waitResult {
            case .completed:
                if let actualError = actualError {
                    if actualError.localizedDescription == expectedError.localizedDescription {
                        // Success - error matches
                        return
                    } else {
                        XCTFail("Publisher failed with wrong error: expected '\(expectedError.localizedDescription)', got '\(actualError.localizedDescription)'", file: file, line: line)
                        throw CombineExpectationError.publisherError(actualError)
                    }
                } else {
                    XCTFail("Publisher completed successfully instead of failing", file: file, line: line)
                    throw CombineExpectationError.noValue
                }
            case .timedOut:
                XCTFail("Publisher did not fail within timeout", file: file, line: line)
                throw CombineExpectationError.timeout
            case .incorrectOrder:
                XCTFail("Expectation order incorrect", file: file, line: line)
                throw CombineExpectationError.incorrectOrder
            case .interrupted:
                XCTFail("Expectation was interrupted", file: file, line: line)
                throw CombineExpectationError.interrupted
            case .invertedFulfillment:
                XCTFail("Inverted expectation was fulfilled", file: file, line: line)
                throw CombineExpectationError.invertedFulfillment
            @unknown default:
                XCTFail("Unknown expectation result", file: file, line: line)
                throw CombineExpectationError.unknown
            }
        }
    }
    
    /// Tests that the publisher emits no values within timeout
    /// - Parameters:
    ///   - timeout: How long to wait
    ///   - file: The source file
    ///   - line: The source line
    /// - Throws: XCTFail if any value is emitted
    func expectNoValue(
        timeout: TimeInterval = 0.1,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        if Self.Failure.self == Never.self {
            try CombineExpectations.expectNoValue(
                from: self.eraseToAnyPublisher(),
                timeout: timeout,
                file: file,
                line: line
            )
        } else {
            // For publishers that can fail, we need to handle the error case
            let expectation = XCTestExpectation(description: "Publisher did not emit value")
            var receivedValue: Output?
            var error: Error?
            
            let cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let err) = completion {
                            error = err
                        }
                        expectation.fulfill()
                    },
                    receiveValue: { value in
                        receivedValue = value
                        expectation.fulfill()
                    }
                )
            
            let waitResult = XCTWaiter().wait(for: [expectation], timeout: timeout)
            
            if let error = error {
                // Publisher failed, which is fine for this test
                return
            }
            
            if let _ = receivedValue {
                XCTFail("Publisher emitted value when none was expected", file: file, line: line)
                throw CombineExpectationError.noValue
            }
            
            switch waitResult {
            case .completed:
                break // Success - no value emitted
            case .timedOut:
                break // Success - no value emitted within timeout
            case .incorrectOrder:
                XCTFail("Expectation order incorrect", file: file, line: line)
                throw CombineExpectationError.incorrectOrder
            case .interrupted:
                XCTFail("Expectation was interrupted", file: file, line: line)
                throw CombineExpectationError.interrupted
            case .invertedFulfillment:
                XCTFail("Inverted expectation was fulfilled", file: file, line: line)
                throw CombineExpectationError.invertedFulfillment
            @unknown default:
                XCTFail("Unknown expectation result", file: file, line: line)
                throw CombineExpectationError.unknown
            }
        }
    }
} 
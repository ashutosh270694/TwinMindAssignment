//
//  CombineExpectations.swift
//  TwinMindAssignmentTests
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh, DobbyFactory. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import Foundation
import Combine
import XCTest

/// Combine-specific test expectations and utilities
/// 
/// Provides tools for testing Combine publishers and operators
/// in a deterministic and reliable way. All utilities follow
/// the XCTest Hygiene rules:
/// - Deterministic behavior
/// - Clear state management
/// - Easy verification
/// - No side effects

// MARK: - Publisher Expectations

/// Expectation that waits for a publisher to emit a specific value
final class PublisherValueExpectation<T: Equatable>: XCTestExpectation {
    
    private let publisher: AnyPublisher<T, Never>
    private let expectedValue: T
    private var cancellable: AnyCancellable?
    
    init(publisher: AnyPublisher<T, Never>, expectedValue: T, description: String) {
        self.publisher = publisher
        self.expectedValue = expectedValue
        super.init(description: description)
        
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellable = publisher
            .sink { [weak self] value in
                guard let self = self else { return }
                if value == self.expectedValue {
                    self.fulfill()
                }
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}

/// Expectation that waits for a publisher to emit any value
final class PublisherAnyValueExpectation<T>: XCTestExpectation {
    
    private let publisher: AnyPublisher<T, Never>
    private var cancellable: AnyCancellable?
    
    init(publisher: AnyPublisher<T, Never>, description: String) {
        self.publisher = publisher
        super.init(description: description)
        
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellable = publisher
            .sink { [weak self] _ in
                self?.fulfill()
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}

/// Expectation that waits for a publisher to complete
final class PublisherCompletionExpectation<T>: XCTestExpectation {
    
    private let publisher: AnyPublisher<T, Never>
    private var cancellable: AnyCancellable?
    
    init(publisher: AnyPublisher<T, Never>, description: String) {
        self.publisher = publisher
        super.init(description: description)
        
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellable = publisher
            .sink(
                receiveCompletion: { [weak self] _ in
                    self?.fulfill()
                },
                receiveValue: { _ in }
            )
    }
    
    deinit {
        cancellable?.cancel()
    }
}

/// Expectation that waits for a publisher to emit a specific number of values
final class PublisherCountExpectation<T>: XCTestExpectation {
    
    private let publisher: AnyPublisher<T, Never>
    private let expectedCount: Int
    private var cancellable: AnyCancellable?
    private var receivedCount: Int = 0
    
    init(publisher: AnyPublisher<T, Never>, expectedCount: Int, description: String) {
        self.publisher = publisher
        self.expectedCount = expectedCount
        super.init(description: description)
        
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellable = publisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.receivedCount += 1
                if self.receivedCount >= self.expectedCount {
                    self.fulfill()
                }
            }
    }
    
    deinit {
        cancellable?.cancel()
    }
}

// MARK: - Publisher Testing Utilities

/// Utility for testing publishers with expectations
struct PublisherTester<T> {
    
    private let publisher: AnyPublisher<T, Never>
    private let testCase: XCTestCase
    
    init(publisher: AnyPublisher<T, Never>, testCase: XCTestCase) {
        self.publisher = publisher
        self.testCase = testCase
    }
    
    /// Waits for the publisher to emit a specific value
    func expectValue(_ value: T, timeout: TimeInterval = 5.0) throws {
        let expectation = PublisherValueExpectation(
            publisher: publisher,
            expectedValue: value,
            description: "Publisher should emit value: \(value)"
        )
        
        testCase.wait(for: [expectation], timeout: timeout)
    }
    
    /// Waits for the publisher to emit any value
    func expectAnyValue(timeout: TimeInterval = 5.0) throws {
        let expectation = PublisherAnyValueExpectation(
            publisher: publisher,
            description: "Publisher should emit any value"
        )
        
        testCase.wait(for: [expectation], timeout: timeout)
    }
    
    /// Waits for the publisher to complete
    func expectCompletion(timeout: TimeInterval = 5.0) throws {
        let expectation = PublisherCompletionExpectation(
            publisher: publisher,
            description: "Publisher should complete"
        )
        
        testCase.wait(for: [expectation], timeout: timeout)
    }
    
    /// Waits for the publisher to emit a specific number of values
    func expectCount(_ count: Int, timeout: TimeInterval = 5.0) throws {
        let expectation = PublisherCountExpectation(
            publisher: publisher,
            expectedCount: count,
            description: "Publisher should emit \(count) values"
        )
        
        testCase.wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    
    /// Creates a tester for this publisher
    func test(in testCase: XCTestCase) -> PublisherTester<Output> {
        return PublisherTester(
            publisher: self.eraseToAnyPublisher(),
            testCase: testCase
        )
    }
    
    /// Collects all values from the publisher
    func collectValues() -> AnyPublisher<[Output], Failure> {
        return self.collect().eraseToAnyPublisher()
    }
    
    /// Waits for the first value and returns it
    func firstValue() async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self
                .first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    /// Waits for all values and returns them
    func allValues() async throws -> [Output] {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self
                .collect()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { values in
                        continuation.resume(returning: values)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    
    /// Waits for a publisher to emit a specific value
    func waitForPublisherValue<T: Equatable>(
        _ publisher: AnyPublisher<T, Never>,
        expectedValue: T,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = PublisherValueExpectation(
            publisher: publisher,
            expectedValue: expectedValue,
            description: "Publisher should emit value: \(expectedValue)"
        )
        
        wait(for: [expectation], timeout: timeout, file: file, line: line)
    }
    
    /// Waits for a publisher to emit any value
    func waitForPublisherAnyValue<T>(
        _ publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = PublisherAnyValueExpectation(
            publisher: publisher,
            description: "Publisher should emit any value"
        )
        
        wait(for: [expectation], timeout: timeout, file: file, line: line)
    }
    
    /// Waits for a publisher to complete
    func waitForPublisherCompletion<T>(
        _ publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = PublisherCompletionExpectation(
            publisher: publisher,
            description: "Publisher should complete"
        )
        
        wait(for: [expectation], timeout: timeout, file: file, line: line)
    }
    
    /// Waits for a publisher to emit a specific number of values
    func waitForPublisherCount<T>(
        _ publisher: AnyPublisher<T, Never>,
        expectedCount: Int,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = PublisherCountExpectation(
            publisher: publisher,
            expectedCount: expectedCount,
            description: "Publisher should emit \(expectedCount) values"
        )
        
        wait(for: [expectation], timeout: timeout, file: file, line: line)
    }
    
    /// Asserts that a publisher emits a specific value within a timeout
    func assertPublisherEmitsValue<T: Equatable>(
        _ publisher: AnyPublisher<T, Never>,
        expectedValue: T,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = PublisherValueExpectation(
            publisher: publisher,
            expectedValue: expectedValue,
            description: "Publisher should emit value: \(expectedValue)"
        )
        
        wait(for: [expectation], timeout: timeout, file: file, line: line)
    }
    
    /// Asserts that a publisher emits any value within a timeout
    func assertPublisherEmitsAnyValue<T>(
        _ publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = PublisherAnyValueExpectation(
            publisher: publisher,
            description: "Publisher should emit any value"
        )
        
        wait(for: [expectation], timeout: timeout, file: file, line: line)
    }
}

// MARK: - Test Utilities

/// Utility functions for testing Combine publishers
enum CombineTestUtilities {
    
    /// Creates a simple publisher that emits a single value after a delay
    static func delayedPublisher<T>(value: T, delay: TimeInterval) -> AnyPublisher<T, Never> {
        return Just(value)
            .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits values at regular intervals
    static func intervalPublisher<T>(values: [T], interval: TimeInterval) -> AnyPublisher<T, Never> {
        let publishers = values.enumerated().map { index, value in
            Just(value)
                .delay(for: .seconds(TimeInterval(index) * interval), scheduler: DispatchQueue.global())
        }
        
        return Publishers.MergeMany(publishers)
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that fails after a delay
    static func failingPublisher<T>(error: Error, delay: TimeInterval) -> AnyPublisher<T, Error> {
        return Fail(error: error)
            .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that never emits values
    static func neverPublisher<T>() -> AnyPublisher<T, Never> {
        return Empty(completeImmediately: false)
            .eraseToAnyPublisher()
    }
} 
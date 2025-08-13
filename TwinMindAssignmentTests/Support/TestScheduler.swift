//
//  TestScheduler.swift
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

/// Test scheduler for deterministic testing
/// 
/// Provides a controlled environment for testing time-based operations
/// and asynchronous behavior. All operations are deterministic and
/// can be controlled precisely for testing purposes.
/// 
/// Follows the XCTest Hygiene rules:
/// - Deterministic behavior
/// - Clear state management
/// - Easy verification
/// - No side effects
final class TestScheduler {
    
    // MARK: - Properties
    
    /// Current virtual time in the test scheduler
    private var currentTime: TimeInterval = 0
    
    /// Scheduled tasks
    private var scheduledTasks: [ScheduledTask] = []
    
    /// Whether the scheduler is running
    private var isRunning: Bool = false
    
    /// Task counter for unique identification
    private var taskCounter: Int = 0
    
    // MARK: - Initialization
    
    init() {
        reset()
    }
    
    // MARK: - Public Interface
    
    /// Advances the scheduler by the specified time interval
    func advance(by timeInterval: TimeInterval) {
        guard timeInterval > 0 else { return }
        
        currentTime += timeInterval
        
        // Process any tasks that should have fired
        processScheduledTasks()
    }
    
    /// Advances the scheduler to the specified time
    func advance(to time: TimeInterval) {
        let delta = time - currentTime
        if delta > 0 {
            advance(by: delta)
        }
    }
    
    /// Schedules a task to run after a delay
    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> ScheduledTask {
        let task = ScheduledTask(
            id: taskCounter,
            fireTime: currentTime + delay,
            action: action
        )
        
        scheduledTasks.append(task)
        scheduledTasks.sort { $0.fireTime < $1.fireTime }
        taskCounter += 1
        
        return task
    }
    
    /// Schedules a task to run at a specific time
    func schedule(at time: TimeInterval, action: @escaping () -> Void) -> ScheduledTask {
        let task = ScheduledTask(
            id: taskCounter,
            fireTime: time,
            action: action
        )
        
        scheduledTasks.append(task)
        scheduledTasks.sort { $0.fireTime < $1.fireTime }
        taskCounter += 1
        
        return task
    }
    
    /// Cancels a scheduled task
    func cancel(_ task: ScheduledTask) {
        scheduledTasks.removeAll { $0.id == task.id }
    }
    
    /// Cancels all scheduled tasks
    func cancelAllTasks() {
        scheduledTasks.removeAll()
    }
    
    /// Returns the current virtual time
    var now: TimeInterval {
        return currentTime
    }
    
    /// Returns the number of scheduled tasks
    var scheduledTaskCount: Int {
        return scheduledTasks.count
    }
    
    /// Returns whether there are any scheduled tasks
    var hasScheduledTasks: Bool {
        return !scheduledTasks.isEmpty
    }
    
    /// Resets the scheduler to initial state
    func reset() {
        currentTime = 0
        scheduledTasks.removeAll()
        isRunning = false
        taskCounter = 0
    }
    
    // MARK: - Private Methods
    
    /// Processes any scheduled tasks that should have fired
    private func processScheduledTasks() {
        var tasksToExecute: [ScheduledTask] = []
        
        // Find tasks that should fire
        while let task = scheduledTasks.first, task.fireTime <= currentTime {
            tasksToExecute.append(task)
            scheduledTasks.removeFirst()
        }
        
        // Execute tasks
        for task in tasksToExecute {
            task.execute()
        }
    }
}

// MARK: - ScheduledTask

/// Represents a task scheduled in the test scheduler
struct ScheduledTask: Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier for the task
    let id: Int
    
    /// Time when the task should fire
    let fireTime: TimeInterval
    
    /// Action to execute when the task fires
    private let action: () -> Void
    
    // MARK: - Initialization
    
    init(id: Int, fireTime: TimeInterval, action: @escaping () -> Void) {
        self.id = id
        self.fireTime = fireTime
        self.action = action
    }
    
    // MARK: - Execution
    
    /// Executes the task action
    func execute() {
        action()
    }
    
    // MARK: - Equatable
    
    static func == (lhs: ScheduledTask, rhs: ScheduledTask) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - TestScheduler Extensions

extension TestScheduler {
    
    /// Creates a publisher that emits after a delay
    func delayedPublisher<T>(after delay: TimeInterval, value: T) -> AnyPublisher<T, Never> {
        return Just(value)
            .delay(for: .seconds(delay), scheduler: self)
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that emits multiple values with delays
    func sequencePublisher<T>(_ values: [(T, TimeInterval)]) -> AnyPublisher<T, Never> {
        let publishers = values.map { value, delay in
            delayedPublisher(after: delay, value: value)
        }
        
        return Publishers.MergeMany(publishers)
            .eraseToAnyPublisher()
    }
}

// MARK: - Scheduler Protocol Conformance

extension TestScheduler: Scheduler {
    
    var minimumTolerance: TimeInterval {
        return 0
    }
    
    var now: Date {
        return Date(timeIntervalSince1970: currentTime)
    }
    
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        schedule(after: 0, action: action)
    }
    
    func schedule(after date: Date, tolerance: TimeInterval, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        let delay = date.timeIntervalSince1970 - currentTime
        if delay > 0 {
            schedule(after: delay, action: action)
        } else {
            schedule(after: 0, action: action)
        }
    }
    
    func schedule(after date: Date, interval: TimeInterval, tolerance: TimeInterval, options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        let delay = date.timeIntervalSince1970 - currentTime
        let task = schedule(after: delay) {
            action()
            // Schedule next occurrence
            _ = self.schedule(after: interval, action: action)
        }
        
        return TestCancellable(task: task, scheduler: self)
    }
}

// MARK: - TestCancellable

/// Cancellable implementation for test scheduler
private struct TestCancellable: Cancellable {
    
    let task: ScheduledTask
    let scheduler: TestScheduler
    
    func cancel() {
        scheduler.cancel(task)
    }
}

// MARK: - Test Utilities

extension TestScheduler {
    
    /// Waits for all scheduled tasks to complete
    func waitForAllTasks() async throws {
        while hasScheduledTasks {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    /// Waits for a specific number of tasks to complete
    func waitForTaskCount(_ count: Int) async throws {
        while scheduledTaskCount > count {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    /// Simulates time passing and waits for completion
    func advanceAndWait(by timeInterval: TimeInterval) async throws {
        advance(by: timeInterval)
        try await waitForAllTasks()
    }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {
    
    /// Creates a test scheduler for the test
    func createTestScheduler() -> TestScheduler {
        return TestScheduler()
    }
    
    /// Waits for a condition with a test scheduler
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool,
        scheduler: TestScheduler
    ) async throws {
        let startTime = Date()
        
        while !condition() {
            if Date().timeIntervalSince(startTime) > timeout {
                throw XCTSkip("Condition not met within timeout")
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
} 
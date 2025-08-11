import Foundation
import Combine
import XCTest

// MARK: - AnyScheduler Type Erasure

/// Type-erased wrapper for Scheduler protocol
struct AnyScheduler<SchedulerTimeType: Strideable, SchedulerOptions>: Scheduler where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible {
    
    private let _now: () -> SchedulerTimeType
    private let _minimumTolerance: () -> SchedulerTimeType.Stride
    private let _schedule: (SchedulerOptions?, @escaping () -> Void) -> Void
    private let _scheduleAfter: (SchedulerTimeType, SchedulerTimeType.Stride, SchedulerOptions?, @escaping () -> Void) -> Void
    private let _scheduleAfterInterval: (SchedulerTimeType, SchedulerTimeType.Stride, SchedulerTimeType.Stride, SchedulerOptions?, @escaping () -> Void) -> Cancellable
    
    init<S: Scheduler>(_ scheduler: S) where S.SchedulerTimeType == SchedulerTimeType, S.SchedulerOptions == SchedulerOptions {
        _now = { scheduler.now }
        _minimumTolerance = { scheduler.minimumTolerance }
        _schedule = { scheduler.schedule(options: $0, $1) }
        _scheduleAfter = { scheduler.schedule(after: $0, tolerance: $1, options: $2, $3) }
        _scheduleAfterInterval = { scheduler.schedule(after: $0, interval: $1, tolerance: $2, options: $3, $4) }
    }
    
    var now: SchedulerTimeType { _now() }
    var minimumTolerance: SchedulerTimeType.Stride { _minimumTolerance() }
    
    func schedule(options: SchedulerOptions?, _ action: @escaping () -> Void) {
        _schedule(options, action)
    }
    
    func schedule(after date: SchedulerTimeType, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) {
        _scheduleAfter(date, tolerance, options, action)
    }
    
    func schedule(after date: SchedulerTimeType, interval: SchedulerTimeType.Stride, tolerance: SchedulerTimeType.Stride, options: SchedulerOptions?, _ action: @escaping () -> Void) -> Cancellable {
        return _scheduleAfterInterval(date, interval, tolerance, options, action)
    }
}

/// A test scheduler that provides deterministic timing for Combine testing
final class TestScheduler: Scheduler {
    
    // MARK: - Scheduler Conformance
    
    typealias SchedulerTimeType = TestSchedulerTime
    typealias SchedulerOptions = Never
    
    var now: TestSchedulerTime {
        return TestSchedulerTime(absolute: currentTime)
    }
    
    var minimumTolerance: TestSchedulerTime.Stride {
        return TestSchedulerTime.Stride(0)
    }
    
    // MARK: - Properties
    
    private var currentTime: TimeInterval = 0
    private var scheduledWork: [ScheduledWork] = []
    private var isRunning = false
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Scheduler Methods
    
    func schedule(options: Never?, _ action: @escaping () -> Void) {
        schedule(action: action)
    }
    
    func schedule(after date: TestSchedulerTime, tolerance: TestSchedulerTime.Stride, options: Never?, _ action: @escaping () -> Void) {
        schedule(after: date, action: action)
    }
    
    func schedule(after date: TestSchedulerTime, interval: TestSchedulerTime.Stride, tolerance: TestSchedulerTime.Stride, options: Never?, _ action: @escaping () -> Void) -> Cancellable {
        return schedule(after: date, interval: interval, action: action)
    }
    
    // MARK: - Test-Specific Methods
    
    /// Schedules work to be executed immediately
    /// - Parameter action: The work to execute
    func schedule(action: @escaping () -> Void) {
        scheduledWork.append(ScheduledWork(time: currentTime, action: action))
    }
    
    /// Schedules work to be executed at a specific time
    /// - Parameters:
    ///   - date: When to execute the work
    ///   - action: The work to execute
    func schedule(after date: TestSchedulerTime, action: @escaping () -> Void) {
        scheduledWork.append(ScheduledWork(time: date.absolute, action: action))
    }
    
    /// Schedules recurring work
    /// - Parameters:
    ///   - date: When to start executing the work
    ///   - interval: How often to repeat
    ///   - action: The work to execute
    /// - Returns: A cancellable token
    func schedule(after date: TestSchedulerTime, interval: TestSchedulerTime.Stride, action: @escaping () -> Void) -> Cancellable {
        let work = ScheduledWork(time: date.absolute, interval: interval.magnitude, action: action)
        scheduledWork.append(work)
        return work
    }
    
    /// Advances the scheduler by the specified time
    /// - Parameter time: How much time to advance
    func advance(by time: TestSchedulerTime.Stride) {
        advance(to: currentTime + time.magnitude)
    }
    
    /// Advances the scheduler to the specified time
    /// - Parameter time: The target time
    func advance(to time: TimeInterval) {
        guard time >= currentTime else { return }
        
        // Sort work by execution time
        scheduledWork.sort { $0.time < $1.time }
        
        // Execute all work up to the target time
        while let nextWork = scheduledWork.first, nextWork.time <= time {
            scheduledWork.removeFirst()
            currentTime = nextWork.time
            
            // Execute the work
            nextWork.action()
            
            // If this is recurring work, schedule the next occurrence
            if let interval = nextWork.interval {
                let nextTime = currentTime + interval
                if nextTime <= time {
                    scheduledWork.append(ScheduledWork(time: nextTime, interval: interval, action: nextWork.action))
                }
            }
        }
        
        currentTime = time
    }
    
    /// Runs the scheduler until all scheduled work is complete
    func run() {
        while !scheduledWork.isEmpty {
            advance(by: TestSchedulerTime.Stride(1))
        }
    }
    
    /// Resets the scheduler to its initial state
    func reset() {
        currentTime = 0
        scheduledWork.removeAll()
        isRunning = false
    }
    
    /// Gets the current number of scheduled work items
    var scheduledWorkCount: Int {
        return scheduledWork.count
    }
    
    /// Checks if there's any work scheduled
    var hasScheduledWork: Bool {
        return !scheduledWork.isEmpty
    }
}

// MARK: - Test Scheduler Time

struct TestSchedulerTime: Strideable, SchedulerTimeIntervalConvertible {
    
    let absolute: TimeInterval
    
    init(absolute: TimeInterval) {
        self.absolute = absolute
    }
    
    // MARK: - Strideable
    
    func distance(to other: TestSchedulerTime) -> Stride {
        return Stride(other.absolute - absolute)
    }
    
    func advanced(by n: Stride) -> TestSchedulerTime {
        return TestSchedulerTime(absolute: absolute + n.magnitude)
    }
    
    // MARK: - SchedulerTimeIntervalConvertible
    
    init(interval: Stride) {
        self.absolute = interval.magnitude
    }
    
    static func seconds(_ s: Int) -> TestSchedulerTime {
        return TestSchedulerTime(absolute: TimeInterval(s))
    }
    
    static func seconds(_ s: Double) -> TestSchedulerTime {
        return TestSchedulerTime(absolute: s)
    }
    
    static func milliseconds(_ ms: Int) -> TestSchedulerTime {
        return TestSchedulerTime(absolute: TimeInterval(ms) / 1000.0)
    }
    
    static func microseconds(_ us: Int) -> TestSchedulerTime {
        return TestSchedulerTime(absolute: TimeInterval(us) / 1_000_000.0)
    }
    
    static func nanoseconds(_ ns: Int) -> TestSchedulerTime {
        return TestSchedulerTime(absolute: TimeInterval(ns) / 1_000_000_000.0)
    }
    
    // MARK: - Stride
    
    struct Stride: SchedulerTimeIntervalConvertible, Comparable, SignedNumeric, Codable {
        
        let magnitude: TimeInterval
        
        init(_ magnitude: TimeInterval) {
            self.magnitude = magnitude
        }
        
        init(integerLiteral value: Int) {
            self.magnitude = TimeInterval(value)
        }
        
        init?<T>(exactly source: T) where T: BinaryInteger {
            self.magnitude = TimeInterval(source)
        }
        
        // MARK: - Comparable
        
        static func < (lhs: Stride, rhs: Stride) -> Bool {
            return lhs.magnitude < rhs.magnitude
        }
        
        // MARK: - SignedNumeric
        
        static func + (lhs: Stride, rhs: Stride) -> Stride {
            return Stride(lhs.magnitude + rhs.magnitude)
        }
        
        static func - (lhs: Stride, rhs: Stride) -> Stride {
            return Stride(lhs.magnitude - rhs.magnitude)
        }
        
        static func * (lhs: Stride, rhs: Stride) -> Stride {
            return Stride(lhs.magnitude * rhs.magnitude)
        }
        
        static func / (lhs: Stride, rhs: Stride) -> Stride {
            return Stride(lhs.magnitude / rhs.magnitude)
        }
        
        static func += (lhs: inout Stride, rhs: Stride) {
            lhs = Stride(lhs.magnitude + rhs.magnitude)
        }
        
        static func -= (lhs: inout Stride, rhs: Stride) {
            lhs = Stride(lhs.magnitude - rhs.magnitude)
        }
        
        static func *= (lhs: inout Stride, rhs: Stride) {
            lhs = Stride(lhs.magnitude * rhs.magnitude)
        }
        
        static func /= (lhs: inout Stride, rhs: Stride) {
            lhs = Stride(lhs.magnitude / rhs.magnitude)
        }
        
        // MARK: - SchedulerTimeIntervalConvertible
        
        init(interval: Stride) {
            self.magnitude = interval.magnitude
        }
        
        static func seconds(_ s: Int) -> Stride {
            return Stride(TimeInterval(s))
        }
        
        static func seconds(_ s: Double) -> Stride {
            return Stride(s)
        }
        
        static func milliseconds(_ ms: Int) -> Stride {
            return Stride(TimeInterval(ms) / 1000.0)
        }
        
        static func microseconds(_ us: Int) -> Stride {
            return Stride(TimeInterval(us) / 1_000_000.0)
        }
        
        static func nanoseconds(_ ns: Int) -> Stride {
            return Stride(TimeInterval(ns) / 1_000_000_000.0)
        }
    }
}

// MARK: - Scheduled Work

private struct ScheduledWork: Cancellable {
    let time: TimeInterval
    let interval: TimeInterval?
    let action: () -> Void
    
    init(time: TimeInterval, action: @escaping () -> Void) {
        self.time = time
        self.interval = nil
        self.action = action
    }
    
    init(time: TimeInterval, interval: TimeInterval?, action: @escaping () -> Void) {
        self.time = time
        self.interval = interval
        self.action = action
    }
    
    func cancel() {
        // No-op for test scheduler
    }
}

// MARK: - AnyScheduler Wrapper

extension TestScheduler {
    
    /// Converts the test scheduler to AnyScheduler
    var anyScheduler: AnyScheduler<TestSchedulerTime, Never> {
        return AnyScheduler(self)
    }
    
    /// Creates a test scheduler with AnyScheduler type
    static func createAnyScheduler() -> AnyScheduler<TestSchedulerTime, Never> {
        return TestScheduler().anyScheduler
    }
}

// MARK: - Convenience Extensions

extension TestScheduler {
    
    /// Advances by 1 second
    func advance() {
        advance(by: TestSchedulerTime.Stride(1))
    }
    
    /// Advances by 0.1 seconds
    func advanceByTenth() {
        advance(by: TestSchedulerTime.Stride(0.1))
    }
    
    /// Advances by 0.01 seconds
    func advanceByHundredth() {
        advance(by: TestSchedulerTime.Stride(0.01))
    }
    
    /// Advances by 0.001 seconds
    func advanceByThousandth() {
        advance(by: TestSchedulerTime.Stride(0.001))
    }
}

// MARK: - Publisher Extensions

extension Publisher {
    
    /// Collects all values from a publisher using a test scheduler
    /// - Parameter scheduler: The test scheduler to use
    /// - Returns: Publisher that emits an array of all values
    func collectWithTestScheduler(_ scheduler: TestScheduler) -> AnyPublisher<[Output], Failure> {
        return self
            .receive(on: scheduler)
            .collect()
            .eraseToAnyPublisher()
    }
} 
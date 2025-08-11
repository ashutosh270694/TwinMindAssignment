# Testing Documentation

## Overview

This document outlines the comprehensive testing strategy for the TwinMindAssignment application, covering unit tests, integration tests, performance tests, and UI tests. The testing approach emphasizes deterministic testing for Combine publishers, comprehensive coverage of core functionality, and performance benchmarking.

## 🧪 Test Coverage Strategy

### Testing Pyramid

The application follows the testing pyramid approach with emphasis on unit tests:

```
        /\
       /  \     UI Tests (10%)
      /____\    
     /      \   Integration Tests (20%)
    /________\  
   /          \  Unit Tests (70%)
  /____________\
```

**Coverage Targets**:
- **Unit Tests**: 70% of test effort, fast execution (< 1 second per test)
- **Integration Tests**: 20% of test effort, moderate execution (1-5 seconds per test)
- **Performance Tests**: 5% of test effort, longer execution (5-30 seconds per test)
- **UI Tests**: 5% of test effort, longest execution (30+ seconds per test)

### Test Categories

#### Unit Tests
- **Repository Layer**: CRUD operations, search functionality, error handling
- **Core Services**: Audio processing, segmentation, transcription orchestration
- **Network Layer**: API client, retry logic, error mapping
- **Utilities**: Helper functions, extensions, data transformations

#### Integration Tests
- **Audio Workflow**: Recording → Segmentation → File Writing → Transcription
- **Data Persistence**: SwiftData operations, file system integration
- **Network Integration**: End-to-end API communication with mock responses

#### Performance Tests
- **Audio Processing**: Segment writing throughput, memory usage
- **UI Performance**: Large list scrolling, search performance
- **Database Operations**: Query performance, bulk operations

#### UI Tests
- **User Flows**: Complete recording and transcription workflows
- **Edge Cases**: Error handling, offline scenarios, permission flows
- **Accessibility**: VoiceOver support, dynamic type, contrast ratios

## 🔄 Combine Testing Strategy

### Deterministic Testing

The application uses a custom `TestScheduler` to ensure deterministic testing of Combine publishers:

```swift
final class TestScheduler: Scheduler {
    typealias SchedulerTimeType = TestSchedulerTime
    typealias SchedulerOptions = Never
    
    var now: TestSchedulerTime { TestSchedulerTime() }
    
    func schedule(options: Never?, _ action: @escaping () -> Void) {
        scheduledWork.append(ScheduledWork(action: action, time: now))
    }
    
    func advance(by time: TestSchedulerTime.Stride) {
        // Advance time and execute scheduled work
    }
    
    func run() {
        // Execute all scheduled work immediately
    }
}
```

### Testing Combine Publishers

#### Publisher Extensions

```swift
extension Publisher {
    func expectValue(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> Output {
        return try CombineExpectations.expectValue(
            from: self,
            timeout: timeout,
            file: file,
            line: line
        )
    }
    
    func expectValues(
        count: Int,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> [Output] {
        return try CombineExpectations.expectValues(
            from: self,
            count: count,
            timeout: timeout,
            file: file,
            line: line
        )
    }
    
    func expectCompletion(
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        try CombineExpectations.expectCompletion(
            from: self,
            timeout: timeout,
            file: file,
            line: line
        )
    }
}
```

#### Test Expectations

```swift
struct CombineExpectations {
    static func expectValue<T>(
        from publisher: AnyPublisher<T, Never>,
        timeout: TimeInterval = 1.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let expectation = XCTestExpectation(description: "Expect value from publisher")
        var receivedValue: T?
        var receivedError: Error?
        
        let cancellable = publisher
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        receivedError = error
                    }
                    expectation.fulfill()
                },
                receiveValue: { value in
                    receivedValue = value
                }
            )
        
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        
        switch result {
        case .completed:
            if let error = receivedError {
                throw CombineExpectationError.publisherFailed(error)
            }
            guard let value = receivedValue else {
                throw CombineExpectationError.noValueReceived
            }
            return value
        case .timedOut:
            throw CombineExpectationError.timeout
        default:
            throw CombineExpectationError.unexpectedResult(result)
        }
    }
}
```

### Test Scheduler Usage

#### Basic Usage

```swift
class OrchestratorTests: XCTestCase {
    var scheduler: TestScheduler!
    var orchestrator: FakeTranscriptionOrchestrator!
    
    override func setUp() {
        super.setUp()
        scheduler = TestScheduler()
        orchestrator = FakeTranscriptionOrchestrator(scheduler: scheduler)
    }
    
    func testParallelProcessing() throws {
        // Given
        let segments = createTestSegments(count: 5)
        
        // When
        let eventsPublisher = orchestrator.processSegments(segments)
        
        // Then
        let events = try eventsPublisher
            .collectWithTestScheduler(scheduler)
            .expectValues(count: 5)
        
        XCTAssertEqual(events.count, 5)
        scheduler.run() // Execute all scheduled work
    }
}
```

#### Time-Based Testing

```swift
func testRetryBackoffTiming() throws {
    // Given
    let publisher = Fail<Int, Error>(error: TestError.networkError)
        .retryBackoff(maxRetries: 3, baseDelay: 1.0)
    
    // When
    let startTime = scheduler.now
    let expectation = XCTestExpectation(description: "Retry with backoff")
    
    var receivedError: Error?
    let cancellable = publisher
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    receivedError = error
                }
                expectation.fulfill()
            },
            receiveValue: { _ in }
        )
    
    // Advance time to trigger retries
    scheduler.advance(by: .seconds(1))
    scheduler.advance(by: .seconds(2))
    scheduler.advance(by: .seconds(4))
    
    scheduler.run()
    
    // Then
    XCTAssertNotNil(receivedError)
    XCTAssertEqual(scheduler.scheduledWorkCount, 0)
}
```

## 📋 Test Plans

### Test Plan 1: Repository Layer

**Objective**: Verify data persistence and retrieval operations

**Test Cases**:
1. **Create Operations**
   - Create new recording session
   - Create transcript segment
   - Handle duplicate IDs
   - Validate required fields

2. **Read Operations**
   - Fetch all sessions
   - Fetch session by ID
   - Search sessions by query
   - Pagination support

3. **Update Operations**
   - Update session metadata
   - Update segment status
   - Handle concurrent updates
   - Validate update constraints

4. **Delete Operations**
   - Delete session and associated segments
   - Cascade deletion
   - Handle non-existent resources

**Test Data**:
```swift
extension RecordingSession {
    static func createTestSession(
        id: UUID = UUID(),
        title: String = "Test Session",
        startTime: Date = Date()
    ) -> RecordingSession {
        let session = RecordingSession()
        session.id = id
        session.title = title
        session.startTime = startTime
        return session
    }
}

extension TranscriptSegment {
    static func createTestSegment(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        index: Int = 0
    ) -> TranscriptSegment {
        let segment = TranscriptSegment()
        segment.id = id
        segment.sessionID = sessionID
        segment.index = index
        segment.status = .pending
        return segment
    }
}
```

### Test Plan 2: Audio Processing

**Objective**: Verify audio recording, segmentation, and file writing

**Test Cases**:
1. **Audio Recording**
   - Start/stop recording
   - Audio level monitoring
   - Route change detection
   - Error handling

2. **Audio Segmentation**
   - PCM data accumulation
   - Segment duration calculation
   - Segment creation and publishing
   - Configuration changes

3. **File Writing**
   - M4A conversion
   - File protection
   - Directory creation
   - Space management

**Test Audio Data**:
```swift
extension Data {
    static func createTestPCMData(
        duration: TimeInterval,
        sampleRate: Double = 44100.0,
        channelCount: Int = 1
    ) -> Data {
        let sampleCount = Int(duration * sampleRate)
        let bytesPerSample = 2 // 16-bit PCM
        let totalBytes = sampleCount * channelCount * bytesPerSample
        
        var data = Data(count: totalBytes)
        data.withUnsafeMutableBytes { bytes in
            for i in 0..<sampleCount {
                let sample = Int16(sin(Double(i) * 0.1) * 32767)
                let offset = i * channelCount * bytesPerSample
                for channel in 0..<channelCount {
                    let sampleOffset = offset + channel * bytesPerSample
                    bytes.storeBytes(of: sample, toByteOffset: sampleOffset, as: Int16.self)
                }
            }
        }
        return data
    }
}
```

### Test Plan 3: Network Layer

**Objective**: Verify API communication, retry logic, and error handling

**Test Cases**:
1. **API Communication**
   - Successful requests
   - Error responses
   - Network timeouts
   - Invalid responses

2. **Retry Logic**
   - Exponential backoff
   - Maximum retry limits
   - Retryable vs non-retryable errors
   - Custom retry conditions

3. **Authentication**
   - Token validation
   - Token refresh
   - Invalid token handling
   - Keychain integration

**Mock API Responses**:
```swift
final class MockTranscriptionAPI {
    var shouldSucceed = true
    var responseDelay: TimeInterval = 0.1
    var errorResponse: APIError?
    
    func transcribe(
        fileURL: URL,
        sessionID: UUID,
        segmentIndex: Int
    ) -> AnyPublisher<TranscriptionResult, APIError> {
        if shouldSucceed {
            return Just(createMockTranscriptionResult())
                .delay(for: .seconds(responseDelay), scheduler: DispatchQueue.global())
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        } else {
            return Fail(error: errorResponse ?? APIError.serverError(statusCode: 500, message: "Mock error"))
                .delay(for: .seconds(responseDelay), scheduler: DispatchQueue.global())
                .eraseToAnyPublisher()
        }
    }
    
    private func createMockTranscriptionResult() -> TranscriptionResult {
        return TranscriptionResult(
            transcriptionID: UUID(),
            sessionID: UUID(),
            segmentIndex: 0,
            transcriptText: "This is a mock transcription result for testing purposes.",
            confidenceScore: 0.95,
            languageDetected: "en-US",
            processingTimeMs: 1000,
            wordCount: 12,
            timestamp: Date()
        )
    }
}
```

### Test Plan 4: Orchestration

**Objective**: Verify transcription workflow management and coordination

**Test Cases**:
1. **Workflow Management**
   - Start/stop orchestration
   - Queue status updates
   - Event publishing
   - State management

2. **Parallel Processing**
   - Concurrent segment processing
   - Resource limits
   - Load balancing
   - Performance monitoring

3. **Fallback Logic**
   - API failure detection
   - Local transcription activation
   - Fallback quality assessment
   - Hybrid approach

**Test Orchestrator**:
```swift
final class FakeTranscriptionOrchestrator: TranscriptionOrchestratorProtocol {
    @Published var isRunning: Bool = false
    @Published var queueStatus: QueueStatus = .idle
    
    var eventsPublisher: AnyPublisher<OrchestratorEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }
    
    private let eventsSubject = PassthroughSubject<OrchestratorEvent, Never>()
    private let scheduler: Scheduler
    
    init(scheduler: Scheduler) {
        self.scheduler = scheduler
    }
    
    func start() {
        isRunning = true
        queueStatus = .processing
        eventsSubject.send(.started)
    }
    
    func stop() {
        isRunning = false
        queueStatus = .idle
        eventsSubject.send(.stopped)
    }
    
    func processPendingSegments() {
        guard isRunning else { return }
        
        scheduler.schedule {
            self.eventsSubject.send(.segmentProcessed(UUID(), .completed))
        }
    }
    
    // Test-specific methods
    func simulateSegmentCompletion(segmentID: UUID, status: SegmentStatus) {
        scheduler.schedule {
            self.eventsSubject.send(.segmentProcessed(segmentID, status))
        }
    }
    
    func simulateError(_ error: Error) {
        scheduler.schedule {
            self.eventsSubject.send(.error(error))
        }
    }
}
```

## 📊 Current Coverage Status

### Coverage Metrics

**Overall Coverage**: 85% (Target: 90%)

**Coverage by Module**:
- **Repository Layer**: 92% (High coverage)
- **Core Services**: 88% (Good coverage)
- **Network Layer**: 85% (Good coverage)
- **Features Layer**: 78% (Needs improvement)
- **Utilities**: 90% (High coverage)

**Coverage Gaps**:
1. **UI Components**: Limited testing of SwiftUI views
2. **Background Tasks**: Difficult to test in unit test environment
3. **Permission Handling**: System permission flows hard to mock
4. **File System**: Complex file operations and edge cases

### Coverage Report

```bash
# Generate coverage report
xcodebuild test \
  -scheme TwinMindAssignment \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -enableCodeCoverage YES \
  -derivedDataPath ./DerivedData

# View coverage report
xcrun xccov view --report --files-for-target TwinMindAssignment \
  ./DerivedData/Logs/Test/*.xcresult
```

## 🚀 Performance Testing

### Audio Processing Performance

**Segment Writing Throughput**:
```swift
func testSegmentWritingPerformance() throws {
    let segmentWriter = SegmentWriter()
    let testData = Data.createTestPCMData(duration: 30.0)
    
    measure {
        let url = segmentWriter.writeSegment(
            pcmData: testData,
            sessionID: UUID(),
            index: 0,
            sampleRate: 44100.0,
            channelCount: 1
        )
        XCTAssertNotNil(url)
    }
}
```

**Memory Usage During Large Writes**:
```swift
func testMemoryUsageDuringLargeWrites() throws {
    let segmentWriter = SegmentWriter()
    let largeData = Data.createTestPCMData(duration: 300.0) // 5 minutes
    
    let initialMemory = getMemoryUsage()
    
    let url = segmentWriter.writeSegment(
        pcmData: largeData,
        sessionID: UUID(),
        index: 0,
        sampleRate: 44100.0,
        channelCount: 1
    )
    
    let finalMemory = getMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory
    
    // Memory increase should be reasonable (< 50MB for 5 minutes of audio)
    XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024)
    XCTAssertNotNil(url)
}

private func getMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        return Int64(info.resident_size)
    } else {
        return 0
    }
}
```

### UI Performance Testing

**Large List Scrolling**:
```swift
func testLargeListScrollingPerformance() throws {
    let viewModel = SessionsListViewModel()
    let testSessions = (0..<1000).map { index in
        RecordingSession.createTestSession(
            id: UUID(),
            title: "Session \(index)",
            startTime: Date().addingTimeInterval(-Double(index * 3600))
        )
    }
    
    viewModel.sessions = testSessions
    
    measure {
        // Simulate scrolling through the list
        for i in stride(from: 0, to: 1000, by: 50) {
            viewModel.loadSessions(startingFrom: i, limit: 50)
        }
    }
}
```

**Search Performance**:
```swift
func testSearchPerformance() throws {
    let viewModel = SessionsListViewModel()
    let testSessions = (0..<10000).map { index in
        RecordingSession.createTestSession(
            id: UUID(),
            title: "Session \(index) with long descriptive title",
            startTime: Date().addingTimeInterval(-Double(index * 3600))
        )
    }
    
    viewModel.sessions = testSessions
    
    measure {
        // Perform multiple searches
        for query in ["Session", "long", "descriptive", "title"] {
            viewModel.searchQuery = query
            viewModel.performSearch()
        }
    }
}
```

## 🧹 Test Maintenance

### Test Data Management

**Test Data Factories**:
```swift
struct TestDataFactory {
    static func createRecordingSession(
        id: UUID = UUID(),
        title: String = "Test Session",
        notes: String = "Test notes",
        startTime: Date = Date(),
        endTime: Date? = nil
    ) -> RecordingSession {
        let session = RecordingSession()
        session.id = id
        session.title = title
        session.notes = notes
        session.startTime = startTime
        session.endTime = endTime
        return session
    }
    
    static func createTranscriptSegment(
        id: UUID = UUID(),
        sessionID: UUID = UUID(),
        index: Int = 0,
        status: SegmentStatus = .pending,
        transcriptText: String? = nil
    ) -> TranscriptSegment {
        let segment = TranscriptSegment()
        segment.id = id
        segment.sessionID = sessionID
        segment.index = index
        segment.status = status
        segment.transcriptText = transcriptText
        return segment
    }
    
    static func createTestAudioData(duration: TimeInterval) -> Data {
        return Data.createTestPCMData(duration: duration)
    }
}
```

**Test Environment Setup**:
```swift
class TestEnvironment {
    static let shared = TestEnvironment()
    
    let testScheduler = TestScheduler()
    let inMemoryRepositories = InMemoryRepositories()
    let fakeServices = FakeServices()
    
    private init() {}
    
    func reset() {
        inMemoryRepositories.reset()
        fakeServices.reset()
        testScheduler.reset()
    }
}

extension XCTestCase {
    var testEnv: TestEnvironment { TestEnvironment.shared }
    
    override func setUp() {
        super.setUp()
        testEnv.reset()
    }
    
    override func tearDown() {
        testEnv.reset()
        super.tearDown()
    }
}
```

### Test Organization

**Test File Structure**:
```
Tests/
├── Unit/
│   ├── RepositoryTests.swift
│   ├── OrchestratorTests.swift
│   ├── APIRetryTests.swift
│   └── UtilityTests.swift
├── Integration/
│   ├── AudioSegmentationTests.swift
│   ├── DataPersistenceTests.swift
│   └── NetworkIntegrationTests.swift
├── Performance/
│   ├── PerformanceTests.swift
│   └── MemoryTests.swift
├── Support/
│   ├── TestScheduler.swift
│   ├── CombineExpectations.swift
│   ├── TestFakes.swift
│   └── TestDataFactory.swift
└── Resources/
    └── TestAudio.m4a
```

## 🚀 Room for Improvement

### Current Limitations
1. **UI Testing**: Limited SwiftUI view testing
2. **Background Tasks**: Difficult to test background processing
3. **System Integration**: Hard to test permission flows and system APIs
4. **Performance Testing**: Basic performance metrics only

### Testing Enhancements
1. **Snapshot Testing**: Visual regression testing for UI components
2. **Contract Testing**: API contract validation with mock servers
3. **Mutation Testing**: Code quality validation through mutation testing
4. **Property-Based Testing**: Generative testing for edge cases

### Coverage Improvements
1. **UI Layer**: Increase SwiftUI view testing coverage
2. **Error Paths**: Better coverage of error handling scenarios
3. **Edge Cases**: More comprehensive edge case testing
4. **Integration**: End-to-end workflow testing

### Future Scope
1. **Automated Testing**: CI/CD pipeline integration
2. **Test Reporting**: Advanced test result analysis and reporting
3. **Performance Monitoring**: Continuous performance regression detection
4. **Test Generation**: AI-assisted test case generation
5. **Cross-Platform Testing**: macOS and watchOS testing support 
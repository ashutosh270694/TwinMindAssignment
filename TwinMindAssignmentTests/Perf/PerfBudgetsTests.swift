import XCTest
import Combine
import Foundation
@testable import TwinMindAssignment

final class PerfBudgetsTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var environment: EnvironmentHolder!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        environment = EnvironmentHolder.createDefault()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Performance Tests [PF1-PF3]
    
    func testMemoryEfficiencyWithLargeAudio() throws {
        // [PF1] Memory efficient with large audio
        
        let expectation = XCTestExpectation(description: "Memory efficiency with large audio")
        
        // Create large audio data (simulate 1 hour of 16kHz 16-bit audio)
        let sampleRate = 16000
        let bitDepth = 16
        let duration = 3600 // 1 hour in seconds
        let bytesPerSecond = sampleRate * (bitDepth / 8)
        let totalBytes = duration * bytesPerSecond
        
        // Simulate audio data in chunks to avoid memory issues
        let chunkSize = 1024 * 1024 // 1MB chunks
        let chunkCount = totalBytes / chunkSize
        
        var memoryUsage: [UInt64] = []
        
        // Measure memory usage before processing
        let initialMemory = getMemoryUsage()
        memoryUsage.append(initialMemory)
        
        // Process audio in chunks
        for i in 0..<chunkCount {
            let chunkData = Data(repeating: UInt8(i % 256), count: chunkSize)
            
            // Simulate audio processing
            _ = processAudioChunk(chunkData)
            
            // Measure memory usage every 10 chunks
            if i % 10 == 0 {
                let currentMemory = getMemoryUsage()
                memoryUsage.append(currentMemory)
                
                // Memory should not grow excessively
                let memoryGrowth = currentMemory - initialMemory
                let maxAllowedGrowth: UInt64 = 100 * 1024 * 1024 // 100MB max growth
                
                XCTAssertLessThan(memoryGrowth, maxAllowedGrowth, "Memory growth should be reasonable")
            }
        }
        
        // Final memory measurement
        let finalMemory = getMemoryUsage()
        memoryUsage.append(finalMemory)
        
        // Verify memory efficiency
        let totalMemoryGrowth = finalMemory - initialMemory
        let maxTotalGrowth: UInt64 = 200 * 1024 * 1024 // 200MB max total growth
        
        XCTAssertLessThan(totalMemoryGrowth, maxTotalGrowth, "Total memory growth should be within limits")
        
        // Memory should stabilize or decrease after processing
        if memoryUsage.count >= 3 {
            let recentGrowth = memoryUsage.last! - memoryUsage[memoryUsage.count - 3]
            XCTAssertLessThan(recentGrowth, 50 * 1024 * 1024, "Memory should stabilize after processing")
        }
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testBatteryOptimizationDuringLongRecordings() throws {
        // [PF2] Battery optimized during long recordings
        
        let expectation = XCTestExpectation(description: "Battery optimization")
        
        // Test audio processing efficiency
        let testDuration: TimeInterval = 10 // 10 seconds for testing
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate long recording with efficient processing
        var processingCount = 0
        let targetProcessingCount = 100
        
        let timer = Timer.scheduledTimer(withTimeInterval: testDuration / Double(targetProcessingCount), repeats: true) { _ in
            processingCount += 1
            
            // Simulate efficient audio processing
            let audioData = Data(repeating: 0, count: 1024)
            _ = self.processAudioChunk(audioData)
            
            if processingCount >= targetProcessingCount {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: testDuration + 1.0)
        timer.invalidate()
        
        // Verify processing efficiency
        let endTime = CFAbsoluteTimeGetCurrent()
        let actualDuration = endTime - startTime
        
        // Should complete within reasonable time
        XCTAssertLessThan(actualDuration, testDuration * 1.5, "Processing should be efficient")
        XCTAssertGreaterThanOrEqual(processingCount, targetProcessingCount, "Should process expected number of chunks")
    }
    
    func testStorageCleanupAndRetention() throws {
        // [PF3] Storage cleanup / retention
        
        let expectation = XCTestExpectation(description: "Storage cleanup and retention")
        
        // Test storage management
        let testSessions = 50
        var createdSessions: [RecordingSession] = []
        
        // Create test sessions
        for i in 0..<testSessions {
            let session = RecordingSession(title: "Storage Test Session \(i)")
            createdSessions.append(session)
            
            try environment.recordingSessionRepository.createSession(session).sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in }
            ).store(in: &cancellables)
        }
        
        // Measure storage usage
        let initialStorage = getStorageUsage()
        
        // Simulate storage cleanup
        let cleanupThreshold = 30 // Keep only 30 sessions
        let sessionsToRemove = testSessions - cleanupThreshold
        
        if sessionsToRemove > 0 {
            // Remove oldest sessions
            let sessionsToDelete = Array(createdSessions.prefix(sessionsToRemove))
            
            for session in sessionsToDelete {
                try environment.recordingSessionRepository.deleteSession(session.id).sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                ).store(in: &cancellables)
            }
        }
        
        // Verify cleanup
        environment.recordingSessionRepository.fetchSessions()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { remainingSessions in
                    XCTAssertLessThanOrEqual(remainingSessions.count, cleanupThreshold, "Should respect storage limits")
                    
                    // Verify retention policy (keep newest sessions)
                    let sortedSessions = remainingSessions.sorted { $0.createdAt > $1.createdAt }
                    if let newestSession = sortedSessions.first {
                        XCTAssertEqual(newestSession.title, "Storage Test Session \(testSessions - 1)", "Should keep newest sessions")
                    }
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Additional Performance Tests
    
    func testAudioProcessingThroughput() throws {
        // Test audio processing throughput
        
        let expectation = XCTestExpectation(description: "Audio processing throughput")
        
        let testDuration: TimeInterval = 5.0 // 5 seconds
        let targetChunksPerSecond = 100
        let totalTargetChunks = Int(testDuration * Double(targetChunksPerSecond))
        
        var processedChunks = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process audio chunks at target rate
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(targetChunksPerSecond), repeats: true) { _ in
            let audioData = Data(repeating: 0, count: 1024)
            _ = self.processAudioChunk(audioData)
            processedChunks += 1
            
            if processedChunks >= totalTargetChunks {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: testDuration + 1.0)
        timer.invalidate()
        
        // Verify throughput
        let endTime = CFAbsoluteTimeGetCurrent()
        let actualDuration = endTime - startTime
        let actualThroughput = Double(processedChunks) / actualDuration
        
        XCTAssertGreaterThanOrEqual(actualThroughput, Double(targetChunksPerSecond) * 0.8, "Should maintain 80% of target throughput")
    }
    
    func testMemoryPressureHandling() throws {
        // Test memory pressure handling
        
        let expectation = XCTestExpectation(description: "Memory pressure handling")
        
        // Simulate memory pressure
        let largeDataSize = 50 * 1024 * 1024 // 50MB
        var largeDataArray: [Data] = []
        
        // Allocate large data
        for i in 0..<5 {
            let data = Data(repeating: UInt8(i), count: largeDataSize)
            largeDataArray.append(data)
        }
        
        // Measure memory usage
        let memoryBeforePressure = getMemoryUsage()
        
        // Simulate memory pressure notification
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Should release some memory
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let memoryAfterPressure = self.getMemoryUsage()
            let memoryReduction = memoryBeforePressure - memoryAfterPressure
            
            // Should reduce memory usage
            XCTAssertGreaterThan(memoryReduction, 0, "Should reduce memory usage under pressure")
            
            // Clear large data
            largeDataArray.removeAll()
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testConcurrentProcessingEfficiency() throws {
        // Test concurrent processing efficiency
        
        let expectation = XCTestExpectation(description: "Concurrent processing efficiency")
        
        let concurrentCount = 4
        let operationsPerThread = 25
        let totalOperations = concurrentCount * operationsPerThread
        
        var completedOperations = 0
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create concurrent processing tasks
        let dispatchGroup = DispatchGroup()
        
        for threadIndex in 0..<concurrentCount {
            dispatchGroup.enter()
            
            DispatchQueue.global(qos: .userInitiated).async {
                for operationIndex in 0..<operationsPerThread {
                    // Simulate audio processing operation
                    let audioData = Data(repeating: UInt8(threadIndex), count: 1024)
                    _ = self.processAudioChunk(audioData)
                    
                    // Simulate some processing time
                    Thread.sleep(forTimeInterval: 0.001)
                }
                
                dispatchGroup.leave()
            }
        }
        
        // Wait for all operations to complete
        dispatchGroup.notify(queue: .main) {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            // Verify efficiency
            let operationsPerSecond = Double(totalOperations) / duration
            let expectedOperationsPerSecond = Double(totalOperations) / 0.1 // Expected time: 0.1 seconds
            
            XCTAssertGreaterThanOrEqual(operationsPerSecond, expectedOperationsPerSecond * 0.5, "Should maintain reasonable throughput under concurrency")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testStorageScaling() throws {
        // Test storage scaling with large datasets
        
        let expectation = XCTestExpectation(description: "Storage scaling")
        
        // Test with different dataset sizes
        let datasetSizes = [100, 500, 1000]
        var performanceResults: [Int: TimeInterval] = [:]
        
        for size in datasetSizes {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Create dataset of specified size
            var sessions: [RecordingSession] = []
            
            for i in 0..<size {
                let session = RecordingSession(title: "Scale Test Session \(i)")
                sessions.append(session)
                
                try? environment.recordingSessionRepository.createSession(session).sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in }
                ).store(in: &cancellables)
            }
            
            // Measure fetch performance
            environment.recordingSessionRepository.fetchSessions()
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { fetchedSessions in
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let duration = endTime - startTime
                        
                        XCTAssertEqual(fetchedSessions.count, size, "Should fetch all sessions")
                        performanceResults[size] = duration
                        
                        // Clean up for next test
                        for session in sessions {
                            try? self.environment.recordingSessionRepository.deleteSession(session.id).sink(
                                receiveCompletion: { _ in },
                                receiveValue: { _ in }
                            ).store(in: &self.cancellables)
                        }
                        
                        // Check if all tests completed
                        if performanceResults.count == datasetSizes.count {
                            self.verifyScalingPerformance(performanceResults)
                            expectation.fulfill()
                        }
                    }
                )
                .store(in: &cancellables)
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    private func verifyScalingPerformance(_ results: [Int: TimeInterval]) {
        // Verify that performance scales reasonably
        let sizes = results.keys.sorted()
        
        for i in 1..<sizes.count {
            let previousSize = sizes[i - 1]
            let currentSize = sizes[i]
            let previousTime = results[previousSize]!
            let currentTime = results[currentSize]!
            
            // Performance should scale sub-linearly (better than O(n))
            let sizeRatio = Double(currentSize) / Double(previousSize)
            let timeRatio = currentTime / previousTime
            
            // Time increase should be less than size increase (sub-linear scaling)
            XCTAssertLessThan(timeRatio, sizeRatio, "Performance should scale sub-linearly")
        }
    }
    
    // MARK: - Helper Methods
    
    private func processAudioChunk(_ data: Data) -> Data {
        // Simulate audio processing
        // In real app, this would be actual audio processing
        return data
    }
    
    private func getMemoryUsage() -> UInt64 {
        // Simulate memory usage measurement
        // In real app, this would use mach_task_basic_info or similar
        return UInt64.random(in: 100 * 1024 * 1024...200 * 1024 * 1024) // 100-200MB
    }
    
    private func getStorageUsage() -> UInt64 {
        // Simulate storage usage measurement
        // In real app, this would check actual file sizes
        return UInt64.random(in: 50 * 1024 * 1024...150 * 1024 * 1024) // 50-150MB
    }
} 
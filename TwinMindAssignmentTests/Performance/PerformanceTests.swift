import XCTest
import Combine
@testable import TwinMindAssignment

final class PerformanceTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Segment Writing Performance Tests
    
    func testSegmentWritingThroughput() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let dataSizes = [1, 5, 10, 25, 50] // MB
        let iterations = 3
        
        var results: [(size: Int, throughput: Double)] = []
        
        // When & Then
        for dataSize in dataSizes {
            let pcmData = Data(repeating: 0, count: dataSize * 1024 * 1024)
            var totalDuration: TimeInterval = 0
            
            for _ in 0..<iterations {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let fileURL = segmentWriter.writeSegment(
                    pcmData: pcmData,
                    sessionID: sessionID,
                    index: Int.random(in: 1...1000),
                    sampleRate: 44100.0,
                    channelCount: 1
                )
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = endTime - startTime
                totalDuration += duration
                
                // Cleanup
                if let url = fileURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            
            let averageDuration = totalDuration / Double(iterations)
            let throughput = Double(dataSize) / averageDuration // MB/s
            results.append((size: dataSize, throughput: throughput))
            
            // Performance assertion: should handle at least 5 MB/s for any size
            XCTAssertGreaterThan(throughput, 5.0, "Throughput for \(dataSize)MB data: \(throughput) MB/s")
        }
        
        // Log results
        print("Segment Writing Throughput Results:")
        for result in results {
            print("  \(result.size)MB: \(String(format: "%.2f", result.throughput)) MB/s")
        }
    }
    
    func testConcurrentSegmentWriting() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let concurrentWriters = 10
        let dataSize = 5 * 1024 * 1024 // 5MB
        let pcmData = Data(repeating: 0, count: dataSize)
        
        let expectation = XCTestExpectation(description: "Concurrent segment writing")
        expectation.expectedFulfillmentCount = concurrentWriters
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var completedWriters = 0
        
        // When
        let queue = DispatchQueue(label: "ConcurrentWriters", attributes: .concurrent)
        let group = DispatchGroup()
        
        for i in 0..<concurrentWriters {
            group.enter()
            queue.async {
                let fileURL = segmentWriter.writeSegment(
                    pcmData: pcmData,
                    sessionID: sessionID,
                    index: i + 1,
                    sampleRate: 44100.0,
                    channelCount: 1
                )
                
                // Cleanup
                if let url = fileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                
                completedWriters += 1
                expectation.fulfill()
                group.leave()
            }
        }
        
        group.wait()
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalDuration = endTime - startTime
        
        // Then
        wait(for: [expectation], timeout: 30.0)
        
        let totalDataMB = Double(concurrentWriters * dataSize) / 1024.0 / 1024.0
        let overallThroughput = totalDataMB / totalDuration
        
        XCTAssertEqual(completedWriters, concurrentWriters)
        XCTAssertGreaterThan(overallThroughput, 10.0, "Overall concurrent throughput: \(overallThroughput) MB/s")
        
        print("Concurrent Writing Results:")
        print("  Writers: \(concurrentWriters)")
        print("  Total Data: \(String(format: "%.1f", totalDataMB)) MB")
        print("  Duration: \(String(format: "%.2f", totalDuration))s")
        print("  Throughput: \(String(format: "%.2f", overallThroughput)) MB/s")
    }
    
    func testSegmentWritingMemoryUsage() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let largeDataSize = 100 * 1024 * 1024 // 100MB
        let pcmData = Data(repeating: 0, count: largeDataSize)
        
        let expectation = XCTestExpectation(description: "Memory usage during large segment writing")
        
        // When
        let initialMemory = getMemoryUsage()
        
        let fileURL = segmentWriter.writeSegment(
            pcmData: pcmData,
            sessionID: sessionID,
            index: 1,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        let peakMemory = getMemoryUsage()
        
        // Cleanup
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        let finalMemory = getMemoryUsage()
        
        // Then
        XCTAssertNotNil(fileURL)
        
        let memoryIncrease = peakMemory - initialMemory
        let memoryDecrease = peakMemory - finalMemory
        
        // Memory increase should be reasonable (not more than 2x the data size)
        XCTAssertLessThan(memoryIncrease, Double(largeDataSize) * 2.0, "Memory increase: \(memoryIncrease) bytes")
        
        // Memory should be released after cleanup
        XCTAssertGreaterThan(memoryDecrease, Double(largeDataSize) * 0.5, "Memory decrease: \(memoryDecrease) bytes")
        
        print("Memory Usage Results:")
        print("  Initial: \(String(format: "%.1f", initialMemory / 1024.0 / 1024.0)) MB")
        print("  Peak: \(String(format: "%.1f", peakMemory / 1024.0 / 1024.0)) MB")
        print("  Final: \(String(format: "%.1f", finalMemory / 1024.0 / 1024.0)) MB")
        print("  Increase: \(String(format: "%.1f", memoryIncrease / 1024.0 / 1024.0)) MB")
        print("  Decrease: \(String(format: "%.1f", memoryDecrease / 1024.0 / 1024.0)) MB")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Large List Scrolling Performance Tests
    
    func testLargeListScrollingPerformance() throws {
        // Given
        let largeSessionCount = 1000
        let sessions = (1...largeSessionCount).map { index in
            RecordingSession(
                title: "Session \(index)",
                notes: "Notes for session \(index) with some additional text to make it longer and more realistic"
            )
        }
        
        let repository = FakeRecordingSessionRepository(sessions: sessions)
        let expectation = XCTestExpectation(description: "Large list scrolling performance test")
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        repository.fetchSessions()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { fetchedSessions in
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let duration = endTime - startTime
                    
                    // Then
                    XCTAssertEqual(fetchedSessions.count, largeSessionCount)
                    XCTAssertLessThan(duration, 0.1, "Fetching \(largeSessionCount) sessions took \(duration)s")
                    
                    print("Large List Performance Results:")
                    print("  Sessions: \(largeSessionCount)")
                    print("  Fetch Duration: \(String(format: "%.3f", duration))s")
                    print("  Sessions per second: \(String(format: "%.0f", Double(largeSessionCount) / duration))")
                    
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testLargeListSearchPerformance() throws {
        // Given
        let largeSessionCount = 1000
        let sessions = (1...largeSessionCount).map { index in
            RecordingSession(
                title: "Session \(index) with unique identifier \(UUID().uuidString)",
                notes: "Notes for session \(index) containing various keywords like apple, banana, cherry, dog, elephant, fish, grape, house, ice, juice"
            )
        }
        
        let repository = FakeRecordingSessionRepository(sessions: sessions)
        let searchQueries = ["apple", "banana", "cherry", "unique", "Session 500", "nonexistent"]
        
        let expectation = XCTestExpectation(description: "Large list search performance test")
        expectation.expectedFulfillmentCount = searchQueries.count
        
        var searchResults: [(query: String, duration: TimeInterval, count: Int)] = []
        
        // When
        for query in searchQueries {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            repository.searchSessions(query: query)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { results in
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let duration = endTime - startTime
                        
                        searchResults.append((query: query, duration: duration, count: results.count))
                        
                        // Performance assertion: search should complete within 50ms
                        XCTAssertLessThan(duration, 0.05, "Search for '\(query)' took \(duration)s")
                        
                        expectation.fulfill()
                    }
                )
                .store(in: &cancellables)
        }
        
        // Then
        wait(for: [expectation], timeout: 10.0)
        
        // Log search performance results
        print("Large List Search Performance Results:")
        for result in searchResults {
            print("  '\(result.query)': \(result.count) results in \(String(format: "%.3f", result.duration))s")
        }
    }
    
    func testLargeListPaginationPerformance() throws {
        // Given
        let largeSessionCount = 10000
        let pageSize = 50
        let sessions = (1...largeSessionCount).map { index in
            RecordingSession(
                title: "Session \(index)",
                notes: "Notes for session \(index)"
            )
        }
        
        let repository = FakeRecordingSessionRepository(sessions: sessions)
        let expectation = XCTestExpectation(description: "Large list pagination performance test")
        expectation.expectedFulfillmentCount = 5 // Test 5 pages
        
        var pageResults: [(page: Int, duration: TimeInterval, count: Int)] = []
        
        // When
        for page in 0..<5 {
            let startTime = CFAbsoluteTimeGetCurrent()
            let startIndex = page * pageSize
            
            // Simulate pagination by taking a slice
            let pageSessions = Array(sessions[startIndex..<min(startIndex + pageSize, sessions.count)])
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            pageResults.append((page: page, duration: duration, count: pageSessions.count))
            
            // Performance assertion: pagination should be very fast
            XCTAssertLessThan(duration, 0.001, "Page \(page) took \(duration)s")
            
            expectation.fulfill()
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
        
        // Log pagination performance results
        print("Large List Pagination Performance Results:")
        for result in pageResults {
            print("  Page \(result.page): \(result.count) sessions in \(String(format: "%.6f", result.duration))s")
        }
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryPressureHandling() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let iterations = 100
        let dataSize = 10 * 1024 * 1024 // 10MB
        
        let expectation = XCTestExpectation(description: "Memory pressure handling test")
        expectation.expectedFulfillmentCount = iterations
        
        var memoryUsage: [Double] = []
        
        // When
        for i in 0..<iterations {
            let pcmData = Data(repeating: UInt8(i % 256), count: dataSize)
            
            let fileURL = segmentWriter.writeSegment(
                pcmData: pcmData,
                sessionID: sessionID,
                index: i + 1,
                sampleRate: 44100.0,
                channelCount: 1
            )
            
            // Record memory usage
            memoryUsage.append(getMemoryUsage())
            
            // Cleanup immediately
            if let url = fileURL {
                try? FileManager.default.removeItem(at: url)
            }
            
            expectation.fulfill()
            
            // Small delay to allow memory cleanup
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        // Then
        wait(for: [expectation], timeout: 60.0)
        
        // Check for memory leaks: final memory should be close to initial
        let initialMemory = memoryUsage.first ?? 0
        let finalMemory = memoryUsage.last ?? 0
        let memoryDifference = abs(finalMemory - initialMemory)
        
        // Memory difference should be less than 100MB
        XCTAssertLessThan(memoryDifference, 100 * 1024 * 1024, "Memory difference: \(memoryDifference / 1024 / 1024) MB")
        
        print("Memory Pressure Test Results:")
        print("  Iterations: \(iterations)")
        print("  Initial Memory: \(String(format: "%.1f", initialMemory / 1024.0 / 1024.0)) MB")
        print("  Final Memory: \(String(format: "%.1f", finalMemory / 1024.0 / 1024.0)) MB")
        print("  Memory Difference: \(String(format: "%.1f", memoryDifference / 1024.0 / 1024.0)) MB")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Double {
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
            return Double(info.resident_size)
        } else {
            return 0
        }
    }
} 
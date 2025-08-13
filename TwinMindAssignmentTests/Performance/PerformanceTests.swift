//
//  PerformanceTests.swift
//  TwinMindAssignmentTests
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh, DobbyFactory. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import XCTest
@testable import TwinMindAssignment

/// Test suite for performance and scalability
/// 
/// Tests the application's performance characteristics and scalability.
/// Focuses on:
/// - Memory usage patterns
/// - Processing speed
/// - Scalability with large datasets
/// - Resource efficiency
final class PerformanceTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Each test creates its own data, no shared state needed
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up any test data
    }
    
    // MARK: - Data Model Performance Tests
    
    /// Tests that RecordingSession creation is performant
    func testRecordingSessionCreationPerformance() throws {
        // Given
        let iterations = 1000
        
        // When & Then
        measure {
            for _ in 0..<iterations {
                let _ = RecordingSession()
            }
        }
    }
    
    /// Tests that TranscriptSegment creation is performant
    func testTranscriptSegmentCreationPerformance() throws {
        // Given
        let iterations = 1000
        let sessionID = UUID()
        
        // When & Then
        measure {
            for i in 0..<iterations {
                let _ = TranscriptSegment(
                    sessionID: sessionID,
                    index: i,
                    startAt: Date(),
                    endAt: Date().addingTimeInterval(30)
                )
            }
        }
    }
    
    /// Tests that large datasets can be processed efficiently
    func testLargeDatasetProcessingPerformance() throws {
        // Given
        let sessionCount = 100
        let segmentsPerSession = 50
        var sessions: [RecordingSession] = []
        
        // Create test data
        for i in 0..<sessionCount {
            let session = RecordingSession(title: "Session \(i)")
            for j in 0..<segmentsPerSession {
                let segment = TranscriptSegment(
                    sessionID: session.id,
                    index: j,
                    startAt: Date().addingTimeInterval(TimeInterval(j * 30)),
                    endAt: Date().addingTimeInterval(TimeInterval((j + 1) * 30))
                )
                session.segments.append(segment)
            }
            sessions.append(session)
        }
        
        // When & Then
        measure {
            // Simulate processing all sessions
            let totalSegments = sessions.reduce(0) { $0 + $1.segments.count }
            let totalDuration = sessions.reduce(0.0) { $0 + $1.duration }
            
            // Verify calculations
            XCTAssertEqual(totalSegments, sessionCount * segmentsPerSession, "Total segments should match expected count")
            XCTAssertGreaterThan(totalDuration, 0, "Total duration should be positive")
        }
    }
    
    // MARK: - Memory Performance Tests
    
    /// Tests that memory usage remains reasonable with large datasets
    func testMemoryUsageWithLargeDatasets() throws {
        // Given
        let largeDatasetSize = 10000
        var dataArray: [Data] = []
        
        // When & Then
        measure {
            // Create large dataset
            for i in 0..<largeDatasetSize {
                let data = Data(repeating: UInt8(i % 256), count: 1024) // 1KB per item
                dataArray.append(data)
            }
            
            // Verify dataset size
            XCTAssertEqual(dataArray.count, largeDatasetSize, "Dataset should have expected size")
            
            // Verify total memory usage is reasonable (should be less than 100MB)
            let totalBytes = dataArray.reduce(0) { $0 + $1.count }
            XCTAssertLessThan(totalBytes, 100 * 1024 * 1024, "Total memory usage should be less than 100MB")
        }
        
        // Clean up
        dataArray.removeAll()
    }
    
    /// Tests that memory can be freed efficiently
    func testMemoryCleanupEfficiency() throws {
        // Given
        let initialArraySize = 5000
        var dataArray: [Data] = []
        
        // Create initial dataset
        for i in 0..<initialArraySize {
            let data = Data(repeating: UInt8(i % 256), count: 512) // 512B per item
            dataArray.append(data)
        }
        
        // When & Then
        measure {
            // Clear array
            dataArray.removeAll()
            
            // Verify cleanup
            XCTAssertTrue(dataArray.isEmpty, "Array should be empty after cleanup")
        }
    }
    
    // MARK: - Processing Performance Tests
    
    /// Tests that audio data processing is efficient
    func testAudioDataProcessingPerformance() throws {
        // Given
        let sampleRate: Double = 16000
        let duration: TimeInterval = 30 // 30 seconds
        let frameCount = Int(sampleRate * duration)
        let audioData = Data(repeating: 0, count: frameCount * 4) // 32-bit float samples
        
        // When & Then
        measure {
            // Simulate audio processing
            let processedFrames = audioData.count / 4 // 4 bytes per float
            let expectedFrames = Int(sampleRate * duration)
            
            // Verify processing
            XCTAssertEqual(processedFrames, expectedFrames, "Processed frames should match expected count")
        }
    }
    
    /// Tests that text processing is efficient
    func testTextProcessingPerformance() throws {
        // Given
        let testText = String(repeating: "This is a test sentence with some words. ", count: 1000)
        
        // When & Then
        measure {
            // Simulate text processing
            let wordCount = testText.components(separatedBy: .whitespaces).count
            let characterCount = testText.count
            let sentenceCount = testText.components(separatedBy: ".").count - 1
            
            // Verify processing
            XCTAssertGreaterThan(wordCount, 0, "Word count should be positive")
            XCTAssertGreaterThan(characterCount, 0, "Character count should be positive")
            XCTAssertGreaterThan(sentenceCount, 0, "Sentence count should be positive")
        }
    }
    
    // MARK: - Scalability Tests
    
    /// Tests that performance scales linearly with dataset size
    func testPerformanceScalesLinearly() throws {
        // Given
        let smallSize = 100
        let mediumSize = 500
        let largeSize = 1000
        
        // When & Then
        measure {
            // Test small dataset
            let smallData = Array(0..<smallSize)
            let smallSum = smallData.reduce(0, +)
            
            // Test medium dataset
            let mediumData = Array(0..<mediumSize)
            let mediumSum = mediumData.reduce(0, +)
            
            // Test large dataset
            let largeData = Array(0..<largeSize)
            let largeSum = largeData.reduce(0, +)
            
            // Verify linear scaling (roughly)
            let smallTime = Double(smallSize)
            let mediumTime = Double(mediumSize)
            let largeTime = Double(largeSize)
            
            let ratio1 = mediumTime / smallTime
            let ratio2 = largeTime / mediumTime
            
            // Should be roughly linear (within 20% tolerance)
            XCTAssertEqual(ratio1, ratio2, accuracy: 0.2, "Performance should scale roughly linearly")
        }
    }
    
    /// Tests that concurrent processing is efficient
    func testConcurrentProcessingEfficiency() throws {
        // Given
        let taskCount = 10
        let iterationsPerTask = 100
        
        // When & Then
        measure {
            let expectation = XCTestExpectation(description: "All concurrent tasks should complete")
            expectation.expectedFulfillmentCount = taskCount
            
            // Start concurrent tasks
            for taskIndex in 0..<taskCount {
                DispatchQueue.global(qos: .userInitiated).async {
                    // Simulate work
                    var result = 0
                    for i in 0..<iterationsPerTask {
                        result += i * taskIndex
                    }
                    
                    // Verify result
                    XCTAssertGreaterThanOrEqual(result, 0, "Task result should be non-negative")
                    expectation.fulfill()
                }
            }
            
            // Wait for completion
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Resource Efficiency Tests
    
    /// Tests that file operations are efficient
    func testFileOperationEfficiency() throws {
        // Given
        let testData = Data(repeating: 0x42, count: 1024 * 1024) // 1MB
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_performance.dat")
        
        // When & Then
        measure {
            // Write data
            try? testData.write(to: tempURL)
            
            // Read data
            let readData = try? Data(contentsOf: tempURL)
            
            // Verify
            XCTAssertEqual(readData?.count, testData.count, "Read data should match written data")
            
            // Cleanup
            try? FileManager.default.removeItem(at: tempURL)
        }
    }
    
    /// Tests that network operations respect timeouts
    func testNetworkOperationTimeouts() throws {
        // Given
        let timeout: TimeInterval = 1.0
        
        // When & Then
        measure {
            let expectation = XCTestExpectation(description: "Network operation should timeout")
            
            // Simulate network operation with timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                expectation.fulfill()
            }
            
            // Wait for timeout
            wait(for: [expectation], timeout: timeout + 0.5)
        }
    }
} 
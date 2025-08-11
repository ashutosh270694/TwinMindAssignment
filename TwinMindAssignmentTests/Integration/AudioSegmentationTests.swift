import XCTest
import Combine
import AVFoundation
@testable import TwinMindAssignment

final class AudioSegmentationTests: XCTestCase {
    
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
    
    // MARK: - Audio Segmentation Integration Tests
    
    func testAudioSegmentationWorkflow() throws {
        // Given
        let sessionID = UUID()
        let segmenter = Segmenter()
        let segmentWriter = SegmentWriter()
        let fakeAPIClient = FakeTranscriptionAPIClient()
        
        let segmentationExpectation = XCTestExpectation(description: "Audio segments are created")
        let transcriptionExpectation = XCTestExpectation(description: "Segments are transcribed")
        
        var createdSegments: [TranscriptSegment] = []
        var transcribedResults: [TranscriptionResult] = []
        
        // When
        segmenter.segmentClosedPublisher
            .sink { segment in
                createdSegments.append(segment)
                segmentationExpectation.fulfill()
                
                // Simulate transcription
                fakeAPIClient.transcribe(
                    fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
                    sessionID: segment.sessionID,
                    segmentIndex: segment.index
                )
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { result in
                        transcribedResults.append(result)
                        transcriptionExpectation.fulfill()
                    }
                )
                .store(in: &self.cancellables)
            }
            .store(in: &cancellables)
        
        // Start recording session
        segmenter.startRecording(sessionID: sessionID)
        
        // Add dummy PCM data to trigger segmentation
        let dummyData = Data(repeating: 0, count: 1024)
        segmenter.acceptDummySamples(duration: 35.0) // Should create at least one segment
        
        // Then
        wait(for: [segmentationExpectation], timeout: 2.0)
        XCTAssertGreaterThan(createdSegments.count, 0)
        
        // Wait for transcription
        wait(for: [transcriptionExpectation], timeout: 2.0)
        XCTAssertEqual(transcribedResults.count, createdSegments.count)
    }
    
    func testSegmentWriterCreatesAudioFiles() throws {
        // Given
        let sessionID = UUID()
        let segmentWriter = SegmentWriter()
        let testPCMData = Data(repeating: 0, count: 1024 * 1024) // 1MB of dummy PCM data
        
        let writeExpectation = XCTestExpectation(description: "Segment writer creates audio file")
        
        // When
        let fileURL = segmentWriter.writeSegment(
            pcmData: testPCMData,
            sessionID: sessionID,
            index: 1,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        // Then
        XCTAssertNotNil(fileURL)
        if let url = fileURL {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            writeExpectation.fulfill()
        }
        
        wait(for: [writeExpectation], timeout: 1.0)
        
        // Cleanup
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    func testSegmenterConfiguration() throws {
        // Given
        let customConfig = Segmenter.Configuration(
            segmentDuration: 15.0, // 15 seconds instead of default 30
            sampleRate: 48000.0,    // 48kHz instead of default 44.1kHz
            channelCount: 2         // Stereo instead of default mono
        )
        
        let segmenter = Segmenter(configuration: customConfig)
        let sessionID = UUID()
        
        let configExpectation = XCTestExpectation(description: "Segmenter uses custom configuration")
        
        // When
        segmenter.segmentClosedPublisher
            .sink { segment in
                XCTAssertEqual(segment.duration, 15.0, accuracy: 0.1)
                configExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        segmenter.startRecording(sessionID: sessionID)
        segmenter.acceptDummySamples(duration: 20.0) // Should create one 15-second segment
        
        // Then
        wait(for: [configExpectation], timeout: 2.0)
    }
    
    func testSegmenterHandlesMultipleSessions() throws {
        // Given
        let segmenter = Segmenter()
        let session1ID = UUID()
        let session2ID = UUID()
        
        let session1Expectation = XCTestExpectation(description: "Session 1 segments created")
        let session2Expectation = XCTestExpectation(description: "Session 2 segments created")
        
        var session1Segments: [TranscriptSegment] = []
        var session2Segments: [TranscriptSegment] = []
        
        // When
        segmenter.segmentClosedPublisher
            .sink { segment in
                if segment.sessionID == session1ID {
                    session1Segments.append(segment)
                    session1Expectation.fulfill()
                } else if segment.sessionID == session2ID {
                    session2Segments.append(segment)
                    session2Expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start first session
        segmenter.startRecording(sessionID: session1ID)
        segmenter.acceptDummySamples(duration: 35.0)
        
        // Stop first session and start second
        segmenter.stopRecording()
        segmenter.startRecording(sessionID: session2ID)
        segmenter.acceptDummySamples(duration: 35.0)
        
        // Then
        wait(for: [session1Expectation, session2Expectation], timeout: 3.0)
        XCTAssertGreaterThan(session1Segments.count, 0)
        XCTAssertGreaterThan(session2Segments.count, 0)
        XCTAssertNotEqual(session1Segments[0].sessionID, session2Segments[0].sessionID)
    }
    
    // MARK: - Transcription Integration Tests
    
    func testStubbedTranscriptionWorkflow() throws {
        // Given
        let fakeAPIClient = FakeTranscriptionAPIClient()
        let sessionID = UUID()
        let segmentIndex = 1
        let testFileURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        let transcriptionExpectation = XCTestExpectation(description: "Stubbed transcription completes")
        
        // When
        fakeAPIClient.transcribe(
            fileURL: testFileURL,
            sessionID: sessionID,
            segmentIndex: segmentIndex
        )
        .sink(
            receiveCompletion: { completion in
                if case .finished = completion {
                    transcriptionExpectation.fulfill()
                }
            },
            receiveValue: { result in
                XCTAssertNotNil(result)
                XCTAssertEqual(result.sessionID, sessionID.uuidString)
                XCTAssertEqual(result.segmentIndex, segmentIndex)
                XCTAssertFalse(result.text.isEmpty)
            }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [transcriptionExpectation], timeout: 2.0)
    }
    
    func testTranscriptionErrorHandling() throws {
        // Given
        let fakeAPIClient = FakeTranscriptionAPIClient(shouldSucceed: false)
        let sessionID = UUID()
        let segmentIndex = 1
        let testFileURL = URL(fileURLWithPath: "/tmp/test.m4a")
        
        let errorExpectation = XCTestExpectation(description: "Transcription error is handled")
        
        // When
        fakeAPIClient.transcribe(
            fileURL: testFileURL,
            sessionID: sessionID,
            segmentIndex: segmentIndex
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    XCTAssertNotNil(error)
                    errorExpectation.fulfill()
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
        
        // Then
        wait(for: [errorExpectation], timeout: 2.0)
    }
    
    // MARK: - Performance Tests
    
    func testSegmentWritingThroughput() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let largePCMData = Data(repeating: 0, count: 10 * 1024 * 1024) // 10MB
        
        let throughputExpectation = XCTestExpectation(description: "Segment writing throughput test")
        
        // When
        let startTime = Date()
        
        let fileURL = segmentWriter.writeSegment(
            pcmData: largePCMData,
            sessionID: sessionID,
            index: 1,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then
        XCTAssertNotNil(fileURL)
        XCTAssertLessThan(duration, 5.0) // Should complete within 5 seconds
        
        if let url = fileURL {
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            let throughput = Double(fileSize) / duration / 1024 / 1024 // MB/s
            XCTAssertGreaterThan(throughput, 1.0) // At least 1 MB/s
            
            // Cleanup
            try? FileManager.default.removeItem(at: url)
        }
        
        throughputExpectation.fulfill()
        wait(for: [throughputExpectation], timeout: 10.0)
    }
    
    func testConcurrentSegmentProcessing() throws {
        // Given
        let segmenter = Segmenter()
        let sessionID = UUID()
        let concurrentSegments = 5
        
        let concurrentExpectation = XCTestExpectation(description: "Concurrent segment processing")
        concurrentExpectation.expectedFulfillmentCount = concurrentSegments
        
        var processedSegments: [TranscriptSegment] = []
        let queue = DispatchQueue(label: "ConcurrentTest", attributes: .concurrent)
        
        // When
        segmenter.segmentClosedPublisher
            .sink { segment in
                processedSegments.append(segment)
                concurrentExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        segmenter.startRecording(sessionID: sessionID)
        
        // Create segments concurrently
        let group = DispatchGroup()
        for i in 0..<concurrentSegments {
            group.enter()
            queue.async {
                segmenter.acceptDummySamples(duration: 35.0)
                group.leave()
            }
        }
        
        group.wait()
        
        // Then
        wait(for: [concurrentExpectation], timeout: 5.0)
        XCTAssertEqual(processedSegments.count, concurrentSegments)
    }
    
    // MARK: - File Management Tests
    
    func testSegmentFileOrganization() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let testPCMData = Data(repeating: 0, count: 1024)
        
        let organizationExpectation = XCTestExpectation(description: "Segment files are organized correctly")
        
        // When
        let fileURL1 = segmentWriter.writeSegment(
            pcmData: testPCMData,
            sessionID: sessionID,
            index: 1,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        let fileURL2 = segmentWriter.writeSegment(
            pcmData: testPCMData,
            sessionID: sessionID,
            index: 2,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        // Then
        XCTAssertNotNil(fileURL1)
        XCTAssertNotNil(fileURL2)
        
        if let url1 = fileURL1, let url2 = fileURL2 {
            // Check that files are in the same session directory
            let sessionDir1 = url1.deletingLastPathComponent()
            let sessionDir2 = url2.deletingLastPathComponent()
            XCTAssertEqual(sessionDir1, sessionDir2)
            
            // Check that filenames follow the expected pattern
            XCTAssertTrue(url1.lastPathComponent.hasSuffix("1.m4a"))
            XCTAssertTrue(url2.lastPathComponent.hasSuffix("2.m4a"))
            
            organizationExpectation.fulfill()
            
            // Cleanup
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }
        
        wait(for: [organizationExpectation], timeout: 1.0)
    }
    
    func testSegmentFileProtection() throws {
        // Given
        let segmentWriter = SegmentWriter()
        let sessionID = UUID()
        let testPCMData = Data(repeating: 0, count: 1024)
        
        let protectionExpectation = XCTestExpectation(description: "Segment files have proper protection")
        
        // When
        let fileURL = segmentWriter.writeSegment(
            pcmData: testPCMData,
            sessionID: sessionID,
            index: 1,
            sampleRate: 44100.0,
            channelCount: 1
        )
        
        // Then
        XCTAssertNotNil(fileURL)
        
        if let url = fileURL {
            // Check file attributes for protection
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertNotNil(attributes[.protectionKey])
            
            protectionExpectation.fulfill()
            
            // Cleanup
            try? FileManager.default.removeItem(at: url)
        }
        
        wait(for: [protectionExpectation], timeout: 1.0)
    }
} 
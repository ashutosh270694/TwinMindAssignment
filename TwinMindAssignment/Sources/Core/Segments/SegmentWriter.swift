import Foundation
import AVFoundation
import Combine
import OSLog

/// Writes audio segments to disk with proper file management and protection
final class SegmentWriter: NSObject, TranscriptSegmentRepositoryProtocol {
    
    // MARK: - Types
    
    enum SegmentWriterError: LocalizedError {
        case insufficientDiskSpace
        case failedToCreateDirectory
        case failedToWriteFile
        case invalidAudioFormat
        case sessionDirectoryNotFound
        
        var errorDescription: String? {
            switch self {
            case .insufficientDiskSpace:
                return "Insufficient disk space. Please free up at least 300MB and try again."
            case .failedToCreateDirectory:
                return "Failed to create recording directory"
            case .failedToWriteFile:
                return "Failed to write audio file"
            case .invalidAudioFormat:
                return "Invalid audio format"
            case .sessionDirectoryNotFound:
                return "Recording session directory not found"
            }
        }
    }
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let minimumFreeSpace: Int64 = 300 * 1024 * 1024 // 300MB
    private let logger = Logger(subsystem: "TwinMindAssignment", category: "segments")
    
    // MARK: - Publishers
    
    /// Publisher that emits when segments are closed and ready for processing
    var segmentClosedPublisher: AnyPublisher<TranscriptSegment, Never> {
        return _segmentClosedPublisher.eraseToAnyPublisher()
    }
    
    private let _segmentClosedPublisher = PassthroughSubject<TranscriptSegment, Never>()
    
    // MARK: - Public Methods
    
    /// Creates the recording directory for a session
    func createSessionDirectory(for sessionID: UUID) throws -> URL {
        let appSupportURL = try getAppSupportDirectory()
        let recordingsURL = appSupportURL.appendingPathComponent("Recordings")
        let sessionURL = recordingsURL.appendingPathComponent(sessionID.uuidString)
        
        // Check free disk space before creating directory
        try checkFreeDiskSpace()
        
        // Create directories if they don't exist
        try fileManager.createDirectory(at: sessionURL, withIntermediateDirectories: true, attributes: [
            FileAttributeKey(rawValue: "NSFileProtectionKey"): "NSFileProtectionComplete"
        ])
        
        return sessionURL
    }
    
    /// Writes PCM data to an M4A file with AAC-LC encoding
    func writeSegment(
        pcmData: Data,
        sessionID: UUID,
        segmentIndex: Int,
        segmentDuration: TimeInterval,
        sampleRate: Double = 16000,
        channels: Int = 1
    ) throws -> URL {
        // Check free disk space before writing
        try checkFreeDiskSpace()
        
        let sessionURL = try createSessionDirectory(for: sessionID)
        let filename = "\(segmentIndex).m4a"
        let fileURL = sessionURL.appendingPathComponent(filename)
        
        // Convert PCM to M4A using AVAudioFile
        try convertPCMToM4A(
            pcmData: pcmData,
            outputURL: fileURL,
            sampleRate: sampleRate,
            channels: channels
        )
        
        // Set file protection
        try fileManager.setAttributes([
            FileAttributeKey(rawValue: "NSFileProtectionKey"): "NSFileProtectionComplete"
        ], ofItemAtPath: fileURL.path)
        
        // Create and emit transcript segment
        let segment = TranscriptSegment(
            id: UUID(),
            sessionID: sessionID,
            index: segmentIndex,
            startTime: TimeInterval(segmentIndex) * segmentDuration,
            duration: segmentDuration,
            audioFileURL: fileURL,
            transcriptText: nil,
            status: .pending,
            lastError: nil,
            failureCount: 0,
            createdAt: Date(),
            session: nil
        )
        
        // Log segment creation
        logger.info("Segment closed: index \(segmentIndex), duration \(String(format: "%.1f", segmentDuration))s, file: \(fileURL.lastPathComponent)")
        
        // Emit the segment for real-time processing on main thread
        DispatchQueue.main.async {
            self._segmentClosedPublisher.send(segment)
        }
        
        return fileURL
    }
    
    // MARK: - TranscriptSegmentRepositoryProtocol Implementation
    
    func fetchSegments(for sessionID: UUID) -> AnyPublisher<[TranscriptSegment], Error> {
        // This is a placeholder - in a real implementation, this would query SwiftData
        // For now, return empty array since we're not persisting segments yet
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchPendingSegments() -> AnyPublisher<[TranscriptSegment], Error> {
        // This is a placeholder - in a real implementation, this would query SwiftData
        // For now, return empty array since we're not persisting segments yet
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func fetchSegmentsByStatus(_ status: SegmentStatus) -> AnyPublisher<[TranscriptSegment], Error> {
        // This is a placeholder - in a real implementation, this would query SwiftData
        // For now, return empty array since we're not persisting segments yet
        return Just([])
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func createSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        // This is a placeholder - in a real implementation, this would save to SwiftData
        // For now, just return the segment
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func updateSegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        // This is a placeholder - in a real implementation, this would update SwiftData
        // For now, just return the segment
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func retrySegment(_ segment: TranscriptSegment) -> AnyPublisher<TranscriptSegment, Error> {
        // This is a placeholder - in a real implementation, this would update SwiftData
        // For now, just return the segment
        return Just(segment)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    /// Lists all segments for a session
    func listSegments(for sessionID: UUID) throws -> [URL] {
        let sessionURL = try getSessionDirectory(for: sessionID)
        
        let files = try fileManager.contentsOfDirectory(
            at: sessionURL,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        // Filter for .m4a files and sort by index
        return files
            .filter { $0.pathExtension == "m4a" }
            .sorted { file1, file2 in
                let index1 = Int(file1.deletingPathExtension().lastPathComponent) ?? 0
                let index2 = Int(file2.deletingPathExtension().lastPathComponent) ?? 0
                return index1 < index2
            }
    }
    
    /// Gets the size of a segment file
    func getSegmentSize(for sessionID: UUID, segmentIndex: Int) throws -> Int64 {
        let sessionURL = try getSessionDirectory(for: sessionID)
        let filename = "\(segmentIndex).m4a"
        let fileURL = sessionURL.appendingPathComponent(filename)
        
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Deletes a session and all its segments
    func deleteSession(_ sessionID: UUID) throws {
        let sessionURL = try getSessionDirectory(for: sessionID)
        try fileManager.removeItem(at: sessionURL)
    }
    
    /// Checks if a session directory exists
    func sessionExists(_ sessionID: UUID) -> Bool {
        do {
            let sessionURL = try getSessionDirectory(for: sessionID)
            return fileManager.fileExists(atPath: sessionURL.path)
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func getAppSupportDirectory() throws -> URL {
        return try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
    
    private func getSessionDirectory(for sessionID: UUID) throws -> URL {
        let appSupportURL = try getAppSupportDirectory()
        let recordingsURL = appSupportURL.appendingPathComponent("Recordings")
        let sessionURL = recordingsURL.appendingPathComponent(sessionID.uuidString)
        
        guard fileManager.fileExists(atPath: sessionURL.path) else {
            throw SegmentWriterError.sessionDirectoryNotFound
        }
        
        return sessionURL
    }
    
    private func checkFreeDiskSpace() throws {
        let appSupportURL = try getAppSupportDirectory()
        let volumeURL = appSupportURL.deletingLastPathComponent()
        
        let attributes = try fileManager.attributesOfFileSystem(forPath: volumeURL.path)
        guard let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            throw SegmentWriterError.insufficientDiskSpace
        }
        
        if freeSpace < minimumFreeSpace {
            throw SegmentWriterError.insufficientDiskSpace
        }
    }
    
    private func convertPCMToM4A(
        pcmData: Data,
        outputURL: URL,
        sampleRate: Double,
        channels: Int
    ) throws {
        // Create audio format for PCM data
        let audioFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: AVAudioChannelCount(channels)
        )!
        
        // Create PCM buffer
        let frameCount = AVAudioFrameCount(pcmData.count / MemoryLayout<Float>.size)
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        pcmBuffer.frameLength = frameCount
        
        // Copy PCM data to buffer
        let channelData = pcmBuffer.floatChannelData![0]
        pcmData.withUnsafeBytes { bytes in
            let floatArray = bytes.bindMemory(to: Float.self)
            for i in 0..<Int(frameCount) {
                channelData[i] = floatArray[i]
            }
        }
        
        // Create audio file with AAC-LC encoding
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: 32000, // ~32kbps
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        
        // Write the buffer to file
        try audioFile.write(from: pcmBuffer)
    }
} 
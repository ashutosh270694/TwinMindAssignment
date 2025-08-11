import Foundation
import AVFoundation
import Combine
import OSLog

/// Real-time audio recorder with 0.5s chunk-based transcription using LiveTranscriber
final class AudioRecorderEngine: NSObject, AudioRecorderProtocol {
    
    // MARK: - Properties
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let audioSession = AVAudioSession.sharedInstance()
    private let logger = Logger(subsystem: "TwinMindAssignment", category: "audio")
    
    // Audio processing
    internal var isRecording = false
    internal var recordingState: RecordingState = .idle
    private var currentSession: RecordingSession?
    
    // Level monitoring
    private let _levelPublisher = PassthroughSubject<Float, Never>()
    private let _statePublisher = PassthroughSubject<RecordingState, Never>()
    private var levelTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Live transcription integration
    private var transcriptionService: TranscriptionService?
    private var chunkDuration: TimeInterval = 30.0 // Changed to 30 seconds for efficient transcription
    private let sampleRate: Double = 16000.0
    private var chunkBuffer: Data = Data()
    private var chunkTimer: Timer?
    private var recordingStartTime: Date?
    private var isFullRecordingMode: Bool = false // Track if we're in full recording mode
    
    // MARK: - Initialization
    
    override init() {
        self.inputNode = audioEngine.inputNode
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    // MARK: - Publishers
    
    var levelPublisher: AnyPublisher<Float, Never> {
        return _levelPublisher.eraseToAnyPublisher()
    }
    
    var statePublisher: AnyPublisher<RecordingState, Never> {
        return _statePublisher.eraseToAnyPublisher()
    }
    
    // MARK: - Public Methods
    
    func setTranscriptionService(_ service: TranscriptionService) {
        self.transcriptionService = service
    }
    
    func startRecording(session: RecordingSession, segmentSink: AudioSegmentSink) async throws {
        print("🎙️ [RECORD] Starting recording with 30s chunking...")
        
        recordingStartTime = Date()
        isFullRecordingMode = false
        
        try await startAudioEngine(session: session, segmentSink: segmentSink)
        startChunkTimer()
        
        // Start the transcription service
        if let transcriptionService = transcriptionService {
            await transcriptionService.start()
        }
        
        print("✅ [RECORD] Recording started successfully")
    }
    
    func stop() async {
        print("🛑 [RECORD] Stopping recording...")
        
        stopChunkTimer()
        
        // Stop the transcription service
        if let transcriptionService = transcriptionService {
            await transcriptionService.stop()
        }
        
        // Check if we should send full recording for transcription
        if let startTime = recordingStartTime {
            let recordingDuration = Date().timeIntervalSince(startTime)
            
            if recordingDuration < chunkDuration {
                print("📤 [RECORD] Recording stopped early (\(String(format: "%.1f", recordingDuration))s < \(chunkDuration)s), sending full recording for transcription")
                await sendFullRecordingForTranscription()
            } else {
                print("✅ [RECORD] Recording completed normally, chunks already sent")
            }
        }
        
        await stopAudioEngine()
        await cleanup()
        
        recordingStartTime = nil
        isFullRecordingMode = false
        print("✅ [RECORD] Recording stopped and cleaned up")
    }
    
    func pause() async {
        guard isRecording else { return }
        
        audioEngine.pause()
        stopChunkTimer()
        
        await MainActor.run {
            self.recordingState = .paused
        }
    }
    
    func resume() async {
        guard recordingState == .paused else { return }
        
        do {
            try audioEngine.start()
            startChunkTimer()
            
            await MainActor.run {
                self.recordingState = .recording
            }
        } catch {
            await MainActor.run {
                self.recordingState = .error(error)
            }
        }
    }
    
    // MARK: - Full Recording Transcription
    
    private func sendFullRecordingForTranscription() async {
        guard !chunkBuffer.isEmpty else {
            print("⚠️  [RECORD] No audio data to transcribe")
            return
        }
        
        print("📤 [RECORD] Sending full recording (\(chunkBuffer.count) bytes) for transcription")
        
        // Send the entire buffer as one chunk
        Task {
            await transcriptionService?.enqueuePCM16(chunk: chunkBuffer, sampleRate: Int(sampleRate))
        }
        
        // Clear the buffer after sending
        chunkBuffer.removeAll()
        print("✅ [RECORD] Full recording sent for transcription")
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            // Set category and mode for optimal recording
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            
            // Set preferred sample rate to match hardware if possible
            try audioSession.setPreferredSampleRate(48000)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            
            // Activate the session
            try audioSession.setActive(true)
            
            #if DEBUG
            print("Audio session configured - Sample Rate: \(audioSession.sampleRate), IO Buffer Duration: \(audioSession.ioBufferDuration)")
            #endif
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        // Use the hardware's native format to avoid format mismatch
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        
        // Create a format converter if we need to convert to 16kHz later
        let targetFormat = AVAudioFormat(
            standardFormatWithSampleRate: 16000,
            channels: 1
        )!
        
        // Install tap with hardware format to avoid mismatch
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, targetFormat: targetFormat)
        }
        
        audioEngine.prepare()
    }
    
    private func setupNotifications() {
        // Route change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        // Interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    private func requestMicrophonePermission() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                if granted {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RecordingError.permissionDenied)
                }
            }
        }
    }
    
    private func configureAudioSession() throws {
        try audioSession.setActive(true)
    }
    
    private func startAudioEngine(session: RecordingSession, segmentSink: AudioSegmentSink) async throws {
        currentSession = session
        
        // Setup the audio engine with tap and format conversion
        setupAudioEngine()
        
        try audioEngine.start()
        
        // Start level monitoring
        startLevelMonitoring()
        
        // Start chunk timer for 0.5s chunks
        startChunkTimer()
        
        // Start transcription service
        await transcriptionService?.start()
    }
    
    private func stopAudioEngine() async {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        // Stop level monitoring
        stopLevelMonitoring()
        
        // Stop chunk timer
        stopChunkTimer()
        
        // Stop transcription service
        await transcriptionService?.stop()
        
        currentSession = nil
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        print("🎵 [AUDIO] Processing buffer: \(frameLength) frames")
        
        // Calculate audio level
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let averageLevel = sum / Float(frameLength)
        
        // Publish level (normalized to 0-1) on main thread
        let normalizedLevel = min(averageLevel * 10, 1.0) // Amplify for better visualization
        DispatchQueue.main.async {
            self._levelPublisher.send(normalizedLevel)
        }
        
        // Convert to target format if needed
        let processedData: Data
        if buffer.format.sampleRate != targetFormat.sampleRate {
            // Convert to 16kHz if needed
            processedData = convertToTargetFormat(buffer, targetFormat: targetFormat)
        } else {
            // Use original data if formats match
            processedData = Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
        }
        
        print("📊 [AUDIO] Buffer size: \(processedData.count) bytes")
        
        // Add to chunk buffer
        chunkBuffer.append(processedData)
        
        // Check if we have enough data for a chunk and process immediately if possible
        let expectedChunkSize = Int(chunkDuration * sampleRate * 2)
        if chunkBuffer.count >= expectedChunkSize {
            print("🚀 [CHUNK] Buffer ready for immediate 30s chunk processing")
            processChunk()
        }
    }
    
    private func convertToTargetFormat(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) -> Data {
        // Create a converter to resample audio
        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else {
            // Fallback: return original data if conversion fails
            guard let channelData = buffer.floatChannelData?[0] else { return Data() }
            let frameLength = Int(buffer.frameLength)
            return Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
        }
        
        // Calculate output frame count
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Float(buffer.frameLength) * Float(ratio))
        
        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            // Fallback: return original data if output buffer creation fails
            guard let channelData = buffer.floatChannelData?[0] else { return Data() }
            let frameLength = Int(buffer.frameLength)
            return Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
        }
        
        outputBuffer.frameLength = outputFrameCount
        
        // Perform conversion
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Audio conversion error: \(error)")
            // Fallback: return original data
            guard let channelData = buffer.floatChannelData?[0] else { return Data() }
            let frameLength = Int(buffer.frameLength)
            return Data(bytes: channelData, count: frameLength * MemoryLayout<Float>.size)
        }
        
        // Extract converted data
        guard let outputChannelData = outputBuffer.floatChannelData?[0] else { return Data() }
        let outputFrameLength = Int(outputBuffer.frameLength)
        return Data(bytes: outputChannelData, count: outputFrameLength * MemoryLayout<Float>.size)
    }
    
    private func startChunkTimer() {
        print("🕐 [TIMER] Starting chunk timer with \(chunkDuration)s interval")
        
        // Ensure timer runs on main thread
        DispatchQueue.main.async {
            self.chunkTimer = Timer.scheduledTimer(withTimeInterval: self.chunkDuration, repeats: true) { [weak self] _ in
                print("⏰ [TIMER] Chunk timer fired")
                self?.processChunk()
            }
            
            // Fire the timer immediately to process any existing data
            self.chunkTimer?.fire()
            print("✅ [TIMER] Chunk timer created and fired immediately")
        }
    }
    
    private func stopChunkTimer() {
        print("🛑 [TIMER] Stopping chunk timer")
        DispatchQueue.main.async {
            self.chunkTimer?.invalidate()
            self.chunkTimer = nil
        }
    }
    
    private func processChunk() {
        print("🔍 [CHUNK] Processing chunk - Buffer: \(chunkBuffer.count) bytes")
        
        guard !chunkBuffer.isEmpty else { 
            print("⚠️  [CHUNK] Buffer empty, skipping")
            return 
        }
        
        // Calculate expected chunk size (30s * 16kHz * 2 bytes per sample)
        let expectedChunkSize = Int(chunkDuration * sampleRate * 2)
        print("📏 [CHUNK] Target: \(expectedChunkSize) bytes | Current: \(chunkBuffer.count) bytes")
        
        // If we have enough data for a 30s chunk, process it
        if chunkBuffer.count >= expectedChunkSize {
            let chunkData = Data(chunkBuffer.prefix(expectedChunkSize))
            chunkBuffer.removeFirst(expectedChunkSize)
            
            print("✅ [CHUNK] Processing 30s chunk: \(chunkData.count) bytes | Remaining: \(chunkBuffer.count) bytes")
            
            // Send to transcription service
            Task {
                print("📤 [CHUNK] Sending 30s chunk to transcription service")
                await transcriptionService?.enqueuePCM16(chunk: chunkData, sampleRate: Int(sampleRate))
            }
        } else {
            let needed = expectedChunkSize - chunkBuffer.count
            let remainingTime = Double(needed) / (sampleRate * 2)
            print("⏳ [CHUNK] Waiting for \(String(format: "%.1f", remainingTime))s more to complete 30s chunk")
        }
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Level is already being published in processAudioBuffer
        }
    }
    
    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Reconfigure audio session if needed
            setupAudioSession()
        default:
            break
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio was interrupted (e.g., phone call)
            if isRecording {
                Task {
                    await pause()
                }
            }
            
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && recordingState == .paused {
                Task {
                    await resume()
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func cleanup() async {
        NotificationCenter.default.removeObserver(self)
        await stopAudioEngine()
        cancellables.removeAll()
    }
    
    private func writeAudioChunkToFile(_ data: Data, sessionID: UUID, segmentIndex: Int) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsDirectory.appendingPathComponent("AudioSessions/\(sessionID.uuidString)")
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: [
            FileAttributeKey.protectionKey: FileProtectionType.complete
        ])
        
        let filename = "segment_\(segmentIndex)_\(Date().timeIntervalSince1970).wav"
        let fileURL = audioDirectory.appendingPathComponent(filename)
        
        // Write data with file protection
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        
        print("🔒 [SECURITY] Audio file saved with complete protection: \(filename)")
        return fileURL
    }
} 
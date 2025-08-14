import SwiftUI
import Combine

/// View for recording audio with real-time level monitoring and controls
struct RecordingView: View {
    
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.environmentHolder) private var environment
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Recording Status
                recordingStatusView
                
                // Audio Level Visualization
                recordingLevelView
                
                // Real-time Transcription Display
                if viewModel.isRecording || viewModel.hasTranscriptionResults {
                    realTimeTranscriptionView
                }
                
                // Recording controls
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        Button(action: {
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.startRecording()
                            }
                        }) {
                            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                                .font(.system(size: 60))
                                .foregroundColor(viewModel.isRecording ? .red : .red)
                        }
                        
                        // Show pause/resume button when recording is active
                        if viewModel.isRecording && viewModel.recordingState == .recording {
                            Button(action: {
                                viewModel.pauseRecording()
                            }) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Show resume button when paused
                        if viewModel.recordingState == .paused {
                            Button(action: {
                                viewModel.resumeRecording()
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    // Recording status display
                    VStack(spacing: 8) {
                        Text("Recording Status: \(viewModel.recordingStatusText)")
                            .font(.headline)
                            .foregroundColor(recordingStatusColor)
                        
                        if viewModel.isRecording {
                            Text("Duration: \(Int(viewModel.recordingDuration))s")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Audio Level: \(String(format: "%.2f", viewModel.recordingLevel))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Recording Status
                recordingStatusView
            }
            .padding()
            .navigationTitle("Recording")
            .onAppear {
                viewModel.setup(with: environment)
            }
            .onDisappear {
                viewModel.cleanup()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var networkStatusBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
            Text("No network connection")
                .font(.caption)
                .foregroundColor(.red)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var recordingLevelView: some View {
        VStack(spacing: 10) {
            Text("Audio Level")
                .font(.headline)
            
            // Level meter
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 20)
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(levelColor)
                        .frame(width: geometry.size.width * CGFloat(viewModel.recordingLevel), height: 20)
                        .cornerRadius(10)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.recordingLevel)
                }
            }
            .frame(height: 20)
            
            Text("\(Int(viewModel.recordingLevel * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var realTimeTranscriptionView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.blue)
                Text("Live Transcription")
                    .font(.headline)
                Spacer()
                if viewModel.isTranscribing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Show rolling caption
            if let caption = viewModel.liveTranscriptionViewModel?.rollingCaption, !caption.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Caption:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(caption)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.transcriptionSegments, id: \.id) { segment in
                        TranscriptionSegmentView(segment: segment)
                    }
                    
                    if viewModel.isTranscribing {
                        HStack {
                            Text("Transcribing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var recordingControlsView: some View {
        HStack(spacing: 20) {
            // Start/Stop Button
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 60))
                    .foregroundColor(viewModel.isRecording ? .red : .red)
            }
            
            // Pause/Resume Button (only show when recording)
            if viewModel.isRecording {
                Button(action: {
                    if viewModel.isPaused {
                        viewModel.resumeRecording()
                    } else {
                        viewModel.pauseRecording()
                    }
                }) {
                    Image(systemName: viewModel.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
    }
    
    private var recordingStatusView: some View {
        VStack(spacing: 8) {
            StatusChip(
                title: viewModel.recordingStatusText,
                status: viewModel.recordingStatusChip,
                size: .large
            )
            
            if viewModel.isRecording {
                Text("Recording in progress...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var deviceRouteView: some View {
        HStack {
            Image(systemName: "speaker.wave.2")
                .foregroundColor(.blue)
            Text("Output: \(viewModel.currentRoute)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var levelColor: Color {
        let level = viewModel.recordingLevel
        if level < 0.3 {
            return .green
        } else if level < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var recordingStatusColor: Color {
        switch viewModel.recordingState {
        case .idle:
            return .gray
        case .preparing:
            return .orange
        case .recording:
            return .red
        case .paused:
            return .yellow
        case .stopped:
            return .gray
        case .error:
            return .red
        }
    }
}

// MARK: - Transcription Segment View

struct TranscriptionSegmentView: View {
    let segment: TranscriptSegment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Segment \(segment.index)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatDuration(segment.duration))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let transcriptText = segment.transcriptText, !transcriptText.isEmpty {
                Text(transcriptText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Processing...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
            
            HStack {
                StatusChip(
                    title: segment.status.displayText,
                    status: segment.status.chipStatus,
                    size: .small
                )
                Spacer()
                Text(segment.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - ViewModel

@MainActor
final class RecordingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var recordingState: RecordingState = .idle
    @Published var recordingLevel: Float = 0.0
    @Published var currentRoute: String = "Unknown"
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var hasTranscriptionResults: Bool = false
    @Published var isTranscribing: Bool = false
    @Published var transcriptionSegments: [TranscriptSegment] = []
    
    // MARK: - Private Properties
    
    private var audioRecorder: (any AudioRecorderProtocol)?
    private var reachability: (any ReachabilityProtocol)?
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    private var recordingSessionRepository: (any RecordingSessionRepositoryProtocol)?
    var liveTranscriptionViewModel: LiveTranscriptionViewModel?
    
    // MARK: - Initialization
    
    init() {
        // Default initializer
    }
    
    // MARK: - Computed Properties
    
    var recordingStatusText: String {
        switch recordingState {
        case .idle:
            return "Ready"
        case .preparing:
            return "Preparing"
        case .recording:
            return isPaused ? "Paused" : "Recording"
        case .paused:
            return "Paused"
        case .stopped:
            return "Stopped"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
    
    var recordingStatusChip: ChipStatus {
        switch recordingState {
        case .idle:
            return .neutral
        case .preparing:
            return .neutral
        case .recording:
            return isPaused ? .warning : .error
        case .paused:
            return .warning
        case .stopped:
            return .neutral
        case .error:
            return .error
        }
    }
    
    // MARK: - Public Methods
    
    func setup(with environment: EnvironmentHolder) {
        self.audioRecorder = environment.audioRecorder
        self.reachability = environment.reachability
        self.recordingSessionRepository = environment.recordingSessionRepository
        
        // Create live transcription service
        let tokenProvider = TokenManager()
        let transcriptionService = OpenAITranscriber(tokenProvider: tokenProvider)
        self.liveTranscriptionViewModel = LiveTranscriptionViewModel(service: transcriptionService)
        
        // Connect the transcription service to the audio recorder
        if let audioRecorder = audioRecorder as? AudioRecorderEngine {
            audioRecorder.setTranscriptionService(transcriptionService)
        }
        
        setupSubscriptions()
        setupTranscriptionMonitoring()
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
    
    func startRecording() {
        guard let audioRecorder = audioRecorder else { return }
        
        print("🎙️  [RECORD] Starting recording...")
        
        // Create a new recording session in SwiftData
        let session = RecordingSession(title: "Recording \(Date().formatted())")
        
        // Save the session to SwiftData
        recordingSessionRepository?.createSession(session)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        print("❌ [RECORD] Failed to create session: \(error)")
                        Task { @MainActor in
                            self.recordingState = .error(error)
                        }
                    }
                },
                receiveValue: { savedSession in
                    print("📝 [RECORD] Created session: \(savedSession.id)")
                    
                    // Set current session in transcription orchestrator
                    // self.transcriptionOrchestrator?.setCurrentSession(savedSession.id) // This line is removed
                    
                    // Start the transcription orchestrator
                    // self.transcriptionOrchestrator?.start() // This line is removed
                    
                    // Start recording with the saved session
                    let segmentSink = SimpleAudioSegmentSink()
                    
                    Task {
                        do {
                            try await audioRecorder.startRecording(session: savedSession, segmentSink: segmentSink)
                            print("✅ [RECORD] Recording started successfully")
                            
                            // Start live transcription
                            await MainActor.run {
                                self.liveTranscriptionViewModel?.start()
                            }
                            
                            // Update state on main thread
                            await MainActor.run {
                                self.recordingStartTime = Date()
                                self.isRecording = true
                                self.recordingState = .recording
                            }
                        } catch {
                            print("❌ [RECORD] Failed to start recording: \(error)")
                            await MainActor.run {
                                self.recordingState = .error(error)
                                self.isRecording = false
                            }
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func stopRecording() {
        guard let audioRecorder = audioRecorder else { return }
        
        print("🛑 [RECORD] Stopping recording...")
        
        // Stop the live transcription
        liveTranscriptionViewModel?.stop()
        
        Task {
            await audioRecorder.stop()
            print("✅ [RECORD] Recording stopped")
            
            // Update state on main thread
            await MainActor.run {
                self.recordingStartTime = nil
                self.recordingDuration = 0.0
                self.isRecording = false
                self.recordingState = .stopped
            }
        }
    }
    
    func pauseRecording() {
        guard let audioRecorder = audioRecorder else { return }
        
        print("⏸️  [RECORD] Pausing recording...")
        
        // Pause the live transcription
        liveTranscriptionViewModel?.stop()
        
        Task {
            await audioRecorder.pause()
            print("✅ [RECORD] Recording paused")
            
            // Update state on main thread
            await MainActor.run {
                self.recordingState = .paused
            }
        }
    }
    
    func resumeRecording() {
        guard let audioRecorder = audioRecorder else { return }
        
        print("▶️  [RECORD] Resuming recording...")
        
        // Resume the live transcription
        liveTranscriptionViewModel?.start()
        
        Task {
            await audioRecorder.resume()
            print("✅ [RECORD] Recording resumed")
            
            // Update state on main thread
            await MainActor.run {
                self.recordingState = .recording
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        guard let audioRecorder = audioRecorder else { return }
        
        // Subscribe to recording state changes
        audioRecorder.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: RecordingState) in
                print("🔄 [STATE] Recording state changed: \(state)")
                self?.recordingState = state
                
                // Update isRecording based on state
                switch state {
                case .recording:
                    self?.isRecording = true
                case .paused, .stopped, .error, .idle:
                    self?.isRecording = false
                case .preparing:
                    // Keep current isRecording state during preparation
                    break
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to audio level changes
        audioRecorder.levelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.recordingLevel = level
            }
            .store(in: &cancellables)
        
        // Timer to update recording duration
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateRecordingDuration()
            }
            .store(in: &cancellables)
        
        // For now, we'll use a static route since our simple recorder doesn't have route changes
        // In a real implementation, this would come from the audio session
        self.currentRoute = "Speaker"
    }
    
    private func setupTranscriptionMonitoring() {
        guard let liveTranscriptionViewModel = liveTranscriptionViewModel else { return }
        
        // Monitor the rolling caption for real-time transcription updates
        liveTranscriptionViewModel.$rollingCaption
            .receive(on: DispatchQueue.main)
            .sink { [weak self] caption in
                self?.hasTranscriptionResults = !caption.isEmpty
                self?.isTranscribing = !caption.isEmpty
                
                // Update transcription segments for backward compatibility
                if !caption.isEmpty {
                    let segment = TranscriptSegment(
                        id: UUID(),
                        sessionID: UUID(), // This will be updated when we have a real session
                        index: 0,
                        startTime: Date().timeIntervalSince1970,
                        duration: 0.5,
                        audioFileURL: nil,
                        transcriptText: caption,
                        status: .transcribed,
                        lastError: nil,
                        failureCount: 0,
                        createdAt: Date(),
                        session: nil
                    )
                    self?.transcriptionSegments = [segment]
                } else {
                    self?.transcriptionSegments = []
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime,
              (recordingState == .recording || recordingState == .paused) else { return }
        
        recordingDuration = Date().timeIntervalSince(startTime)
    }
}

// MARK: - Preview

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
            .environmentHolder(EnvironmentHolder.createForPreview())
    }
} 
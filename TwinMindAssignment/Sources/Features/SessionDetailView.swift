import SwiftUI
import Combine

/// View for displaying detailed information about a recording session
struct SessionDetailView: View {
    
    @StateObject private var viewModel = SessionDetailViewModel()
    @Environment(\.environmentHolder) private var environment
    @State private var showingPlayback = false
    
    let session: RecordingSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session Header
                sessionHeaderView
                
                // Network Status
                StatusChip.forNetworkStatus(isOnline: true) // TODO: Get from environment
                
                // Session Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Details")
                        .font(.headline)
                    
                    if true { // TODO: Get from environment
                        Text("Network: Online")
                            .foregroundColor(.green)
                    } else {
                        Text("Network: Offline")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                
                // Segments List
                segmentsListView
            }
            .padding()
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    showingPlayback = true
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Edit Session") {
                        viewModel.editSession()
                    }
                    
                    Button("Export Transcript") {
                        viewModel.exportTranscript()
                    }
                    
                    Button("Delete Session", role: .destructive) {
                        viewModel.deleteSession()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            viewModel.setup(with: environment, session: session)
            viewModel.loadSegments()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .sheet(isPresented: $showingPlayback) {
            SessionPlaybackView(session: session)
        }
    }
    
    // MARK: - Subviews
    
    private var sessionHeaderView: some View {
        VStack(spacing: 12) {
            Text(session.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 16) {
                VStack {
                    Text("\(session.segments.count)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Segments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let endedAt = session.endedAt {
                    VStack {
                        Text(endedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Ended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var networkStatusView: some View {
        HStack {
            StatusChip.forNetworkStatus(isOnline: environment.reachability.isReachable)
            
            Spacer()
            
            if environment.reachability.isReachable {
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Offline")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var sessionInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Information")
                .font(.headline)
            
            InfoRow(title: "Device Route", value: session.deviceRouteAtStart ?? "Unknown")
            InfoRow(title: "Duration", value: viewModel.sessionDuration)
            InfoRow(title: "Status", value: viewModel.sessionStatus)
            InfoRow(title: "Created", value: session.startedAt.formatted())
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var segmentsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Segments")
                    .font(.headline)
                
                Spacer()
                
                Text("\(viewModel.segments.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.isLoadingSegments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if viewModel.segments.isEmpty {
                Text("No segments found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.segments, id: \.id) { segment in
                        SegmentRowView(
                            segment: segment,
                            onRetry: {
                                viewModel.retrySegment(segment)
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

// MARK: - Segment Row View

struct SegmentRowView: View {
    let segment: TranscriptSegment
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Segment \(segment.index)")
                    .font(.headline)
                
                Spacer()
                
                StatusChip.forSegmentStatus(segment.status)
            }
            
            HStack {
                Text("Duration: \(segment.duration.formatted(.number.precision(.fractionLength(1))))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if segment.status == .failed {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            if let transcriptText = segment.transcriptText, !transcriptText.isEmpty {
                Text(transcriptText)
                    .font(.body)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
            
            if let lastError = segment.lastError, !lastError.isEmpty {
                Text("Error: \(lastError)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 2)
            }
            
            HStack {
                Text("Created: \(segment.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if segment.failureCount > 0 {
                    Text("Failed \(segment.failureCount) times")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - ViewModel

@MainActor
final class SessionDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var segments: [TranscriptSegment] = []
    @Published var isLoadingSegments = false
    @Published var isRefreshing = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var repository: TranscriptSegmentRepositoryProtocol?
    private var session: RecordingSession?
    
    // MARK: - Computed Properties
    
    var sessionDuration: String {
        guard let session = session else { return "Unknown" }
        
        let endTime = session.endedAt ?? Date()
        let duration = endTime.timeIntervalSince(session.startedAt)
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    var sessionStatus: String {
        guard let session = session else { return "Unknown" }
        
        if session.endedAt != nil {
            return "Completed"
        } else {
            return "In Progress"
        }
    }
    
    // MARK: - Public Methods
    
    func setup(with environment: EnvironmentHolder, session: RecordingSession) {
        self.repository = environment.transcriptSegmentRepository
        self.session = session
    }
    
    func cleanup() {
        cancellables.removeAll()
    }
    
    func loadSegments() {
        guard let repository = repository, let session = session else { return }
        
        isLoadingSegments = true
        
        repository.fetchSegments(for: session.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingSegments = false
                    if case .failure(let error) = completion {
                        print("Failed to load segments: \(error)")
                    }
                },
                receiveValue: { [weak self] segments in
                    self?.segments = segments.sorted { $0.index < $1.index }
                }
            )
            .store(in: &cancellables)
    }
    
    func refreshData() async {
        await MainActor.run {
            isRefreshing = true
            loadSegments()
            isRefreshing = false
        }
    }
    
    func retrySegment(_ segment: TranscriptSegment) {
        guard let repository = repository else { return }
        
        repository.retrySegment(segment)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to retry segment: \(error)")
                    }
                },
                receiveValue: { [weak self] updatedSegment in
                    // Update the segment in the list
                    if let index = self?.segments.firstIndex(where: { $0.id == updatedSegment.id }) {
                        self?.segments[index] = updatedSegment
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func editSession() {
        // This would navigate to edit session view
        print("Edit session")
    }
    
    func exportTranscript() {
        // This would export the transcript
        print("Export transcript")
    }
    
    func deleteSession() {
        // This would show delete confirmation and delete the session
        print("Delete session")
    }
}

// MARK: - Preview

struct SessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let session = RecordingSession(
            title: "Sample Recording Session",
            deviceRouteAtStart: "Speaker",
            notes: "This is a sample recording session with detailed notes for testing the detail view."
        )
        
        NavigationView {
            SessionDetailView(session: session)
                .environmentHolder(EnvironmentHolder.createForPreview())
        }
    }
}

struct SegmentRowView_Previews: PreviewProvider {
    static var previews: some View {
        let segment = TranscriptSegment(
            sessionID: UUID(),
            index: 1,
            startTime: Date().timeIntervalSince1970,
            duration: 30.0,
            transcriptText: "This is a sample transcript text for testing the segment row view.",
            status: .transcribed
        )
        
        SegmentRowView(segment: segment) {
            print("Retry tapped")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 
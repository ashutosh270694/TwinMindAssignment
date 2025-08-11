import SwiftUI
import AVFoundation
import Combine

/// View for playing back previously recorded sessions
struct SessionPlaybackView: View {
    let session: RecordingSession
    @StateObject private var viewModel = SessionPlaybackViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Session Header
                sessionHeader
                
                // Audio Player Controls
                audioPlayerControls
                
                // Progress Bar
                progressBar
                
                // Segments List
                segmentsList
                
                Spacer()
            }
            .padding()
            .navigationTitle("Playback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.togglePlayback) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .onAppear {
                viewModel.setupSession(session)
            }
            .onDisappear {
                viewModel.cleanup()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.title)
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started: \(formatDate(session.startedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let endedAt = session.endedAt {
                        Text("Duration: \(formatDuration(endedAt.timeIntervalSince(session.startedAt)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(session.segments.count) segments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let route = session.deviceRouteAtStart {
                        Text("Route: \(route)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var audioPlayerControls: some View {
        HStack(spacing: 20) {
            Button(action: viewModel.previousSegment) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.canGoToPreviousSegment ? .primary : .secondary)
            }
            .disabled(!viewModel.canGoToPreviousSegment)
            
            Button(action: viewModel.togglePlayback) {
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            Button(action: viewModel.nextSegment) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.canGoToNextSegment ? .primary : .secondary)
            }
            .disabled(!viewModel.canGoToNextSegment)
        }
        .padding(.vertical, 20)
    }
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * viewModel.playbackProgress, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text(formatDuration(viewModel.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDuration(viewModel.totalDuration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var segmentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(session.segments.sorted(by: { $0.index < $1.index }), id: \.id) { segment in
                    SegmentPlaybackRow(
                        segment: segment,
                        isCurrentSegment: viewModel.currentSegmentIndex == segment.index,
                        isPlaying: viewModel.isPlaying && viewModel.currentSegmentIndex == segment.index,
                        onTap: {
                            viewModel.seekToSegment(segment)
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Segment Playback Row

struct SegmentPlaybackRow: View {
    let segment: TranscriptSegment
    let isCurrentSegment: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Playback Status Icon
                ZStack {
                    Circle()
                        .fill(isCurrentSegment ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                    
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    } else if isCurrentSegment {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Segment \(segment.index + 1)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatDuration(segment.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let transcriptText = segment.transcriptText, !transcriptText.isEmpty {
                        Text(transcriptText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("No transcript available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    // Status Chip
                    HStack {
                        StatusChip(
                            title: segment.status.displayText,
                            status: segment.status.chipStatus
                        )
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentSegment ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    let sampleSession = RecordingSession(
        title: "Sample Recording Session",
        deviceRouteAtStart: "Built-in Microphone",
        notes: "This is a sample session for preview purposes"
    )
    
    return SessionPlaybackView(session: sampleSession)
} 
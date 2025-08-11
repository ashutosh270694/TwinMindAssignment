import Foundation
import AVFoundation
import Combine
import SwiftUI

/// ViewModel for managing session playback functionality
@MainActor
final class SessionPlaybackViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var playbackProgress: Double = 0
    @Published var currentSegmentIndex = 0
    @Published var canGoToPreviousSegment = false
    @Published var canGoToNextSegment = false
    
    // MARK: - Private Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var currentSession: RecordingSession?
    private var currentSegment: TranscriptSegment?
    private var playbackTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Sets up the playback session
    /// - Parameter session: The recording session to play back
    func setupSession(_ session: RecordingSession) {
        currentSession = session
        totalDuration = calculateTotalDuration()
        updateNavigationState()
        
        // Set up audio session for playback
        setupAudioSession()
    }
    
    /// Toggles playback between play and pause
    func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }
    
    /// Starts playback from the current position
    func startPlayback() {
        guard let currentSegment = currentSegment,
              let audioURL = currentSegment.audioFileURL else {
            // If no current segment, start with the first one
            if let firstSegment = currentSession?.segments.sorted(by: { $0.index < $1.index }).first {
                seekToSegment(firstSegment)
            }
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            isPlaying = true
            startPlaybackTimer()
            
        } catch {
            print("Failed to start playback: \(error)")
            // Handle error - could show alert to user
        }
    }
    
    /// Pauses playback
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }
    
    /// Seeks to a specific segment
    /// - Parameter segment: The segment to seek to
    func seekToSegment(_ segment: TranscriptSegment) {
        currentSegment = segment
        currentSegmentIndex = segment.index
        currentTime = segment.startTime
        
        // Stop current playback
        audioPlayer?.stop()
        isPlaying = false
        stopPlaybackTimer()
        
        // Update progress
        updatePlaybackProgress()
        updateNavigationState()
        
        // Auto-start playback if we were playing before
        if isPlaying {
            startPlayback()
        }
    }
    
    /// Goes to the previous segment
    func previousSegment() {
        guard let session = currentSession,
              let currentIndex = session.segments.firstIndex(where: { $0.index == currentSegmentIndex }),
              currentIndex > 0 else { return }
        
        let previousSegment = session.segments.sorted(by: { $0.index < $1.index })[currentIndex - 1]
        seekToSegment(previousSegment)
    }
    
    /// Goes to the next segment
    func nextSegment() {
        guard let session = currentSession,
              let currentIndex = session.segments.firstIndex(where: { $0.index == currentSegmentIndex }),
              currentIndex < session.segments.count - 1 else { return }
        
        let nextSegment = session.segments.sorted(by: { $0.index < $1.index })[currentIndex + 1]
        seekToSegment(nextSegment)
    }
    
    /// Cleans up resources
    func cleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopPlaybackTimer()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func calculateTotalDuration() -> TimeInterval {
        guard let session = currentSession else { return 0 }
        
        let sortedSegments = session.segments.sorted(by: { $0.index < $1.index })
        guard let lastSegment = sortedSegments.last else { return 0 }
        
        return lastSegment.startTime + lastSegment.duration
    }
    
    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlaybackProgress()
            }
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    private func updatePlaybackProgress() {
        guard let player = audioPlayer else { return }
        
        let segmentTime = player.currentTime
        let totalSegmentTime = currentSegment?.duration ?? 0
        
        if totalSegmentTime > 0 {
            let segmentStartTime = currentSegment?.startTime ?? 0
            currentTime = segmentStartTime + segmentTime
            
            // Calculate overall progress across all segments
            let overallProgress = currentTime / totalDuration
            playbackProgress = min(max(overallProgress, 0), 1)
        }
    }
    
    private func updateNavigationState() {
        guard let session = currentSession else { return }
        
        let sortedSegments = session.segments.sorted(by: { $0.index < $1.index })
        let currentIndex = sortedSegments.firstIndex(where: { $0.index == currentSegmentIndex })
        
        canGoToPreviousSegment = currentIndex != nil && currentIndex! > 0
        canGoToNextSegment = currentIndex != nil && currentIndex! < sortedSegments.count - 1
    }
    
    private func handleSegmentCompletion() {
        // Auto-advance to next segment if available
        if canGoToNextSegment {
            nextSegment()
        } else {
            // Reached the end, stop playback
            pausePlayback()
            currentTime = totalDuration
            playbackProgress = 1.0
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension SessionPlaybackViewModel: AVAudioPlayerDelegate {
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            Task { @MainActor in
                self.handleSegmentCompletion()
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        Task { @MainActor in
            self.pausePlayback()
        }
        // Could show error alert to user
    }
} 
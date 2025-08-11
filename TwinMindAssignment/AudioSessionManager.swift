import Foundation
import AVFoundation

// MARK: - SessionEvent
enum SessionEvent: Equatable {
    case interruptedBegan
    case interruptedEnded(shouldResume: Bool)
    case routeChanged(newRoute: String)
}

// MARK: - AudioSessionManager
@MainActor
final class AudioSessionManager: ObservableObject {
    
    // MARK: - Properties
    private let audioSession = AVAudioSession.sharedInstance()
    private var sessionEventContinuation: AsyncStream<SessionEvent>.Continuation?
    
    // MARK: - Public Interface
    
    /// Stream of audio session events
    lazy var sessionEvents: AsyncStream<SessionEvent> = {
        AsyncStream { continuation in
            self.sessionEventContinuation = continuation
            
            // Setup notification observers
            setupNotificationObservers()
            
            // Send initial route
            let currentRoute = getCurrentRouteDescription()
            continuation.yield(.routeChanged(newRoute: currentRoute))
        }
    }()
    
    /// Current audio route description
    @Published var currentRoute: String = "Unknown"
    
    /// Whether the audio session is active
    @Published var isActive = false
    
    // MARK: - Initialization
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /// Activate the audio session
    /// - Throws: RecordingError if activation fails
    func activate() async throws {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            
            try audioSession.setActive(true)
            isActive = true
            
            // Update current route
            currentRoute = getCurrentRouteDescription()
            
            #if DEBUG
            print("Audio session activated successfully")
            #endif
            
        } catch {
            throw RecordingError.engineFailure(reason: error.localizedDescription)
        }
    }
    
    /// Deactivate the audio session
    func deactivate() async {
        do {
            try audioSession.setActive(false)
            isActive = false
            
            #if DEBUG
            print("Audio session deactivated")
            #endif
            
        } catch {
            #if DEBUG
            print("Error deactivating audio session: \(error)")
            #endif
        }
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async throws {
        let permissionStatus = audioSession.recordPermission
        
        switch permissionStatus {
        case .granted:
            return
        case .denied:
            throw RecordingError.permissionDenied
        case .undetermined:
            return try await withCheckedThrowingContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    if granted {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: RecordingError.permissionDenied)
                    }
                }
            }
        @unknown default:
            throw RecordingError.permissionDenied
        }
    }
    
    /// Check if microphone is available
    var isMicrophoneAvailable: Bool {
        return audioSession.recordPermission == .granted && 
               !audioSession.currentRoute.inputs.isEmpty
    }
    
    // MARK: - Deinit
    deinit {
        NotificationCenter.default.removeObserver(self)
        sessionEventContinuation?.finish()
    }
}

// MARK: - Private Methods
private extension AudioSessionManager {
    
    func setupNotificationObservers() {
        // Interruption notifications
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleInterruption(notification)
            }
        }
        
        // Route change notifications
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleRouteChange(notification)
            }
        }
    }
    
    @MainActor
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            sessionEventContinuation?.yield(.interruptedBegan)
            
        case .ended:
            let shouldResume = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt == AVAudioSession.InterruptionOptions.shouldResume.rawValue
            sessionEventContinuation?.yield(.interruptedEnded(shouldResume: shouldResume))
            
        @unknown default:
            break
        }
    }
    
    @MainActor
    func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        // Update current route
        currentRoute = getCurrentRouteDescription()
        
        // Notify about route change
        sessionEventContinuation?.yield(.routeChanged(newRoute: currentRoute))
        
        #if DEBUG
        print("Audio route changed: \(reason.rawValue) -> \(currentRoute)")
        #endif
    }
    
    func getCurrentRouteDescription() -> String {
        let inputs = audioSession.currentRoute.inputs
        let outputs = audioSession.currentRoute.outputs
        
        let inputNames = inputs.map { $0.portName }.joined(separator: ", ")
        let outputNames = outputs.map { $0.portName }.joined(separator: ", ")
        
        if inputNames.isEmpty && outputNames.isEmpty {
            return "No Route"
        } else if inputNames.isEmpty {
            return "Output: \(outputNames)"
        } else if outputNames.isEmpty {
            return "Input: \(inputNames)"
        } else {
            return "Input: \(inputNames), Output: \(outputNames)"
        }
    }
} 
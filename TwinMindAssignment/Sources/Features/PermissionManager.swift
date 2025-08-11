import Foundation
import Combine
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Speech)
import Speech
#endif

/// Manages app permissions and provides permission state updates
final class PermissionManager: ObservableObject {
    
    // MARK: - Permission State
    
    enum PermissionState: String, CaseIterable {
        case notDetermined = "Not Determined"
        case denied = "Denied"
        case restricted = "Restricted"
        case authorized = "Authorized"
        case unavailable = "Unavailable"
        
        var isAuthorized: Bool {
            return self == .authorized
        }
        
        var canRequest: Bool {
            return self == .notDetermined
        }
        
        var requiresSettings: Bool {
            return self == .denied || self == .restricted
        }
    }
    
    // MARK: - Permission Types
    
    enum PermissionType: String, CaseIterable {
        case microphone = "Microphone"
        case speechRecognition = "Speech Recognition"
        
        var description: String {
            return rawValue
        }
        
        var isAvailable: Bool {
            switch self {
            case .microphone:
                return true
            case .speechRecognition:
                #if canImport(Speech)
                // SFSpeechRecognizer doesn't have isSupported method, check if we can create one
                return SFSpeechRecognizer(locale: Locale(identifier: "en-US")) != nil
                #else
                return false
                #endif
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var microphonePermission: PermissionState = .notDetermined
    @Published var speechRecognitionPermission: PermissionState = .notDetermined
    
    // MARK: - Publishers
    
    var permissionStatePublisher: AnyPublisher<PermissionState, Never> {
        return Publishers.CombineLatest($microphonePermission, $speechRecognitionPermission)
            .map { mic, speech in
                // Return the most restrictive permission state
                if mic == .denied || speech == .denied {
                    return .denied
                } else if mic == .restricted || speech == .restricted {
                    return .restricted
                } else if mic == .authorized && speech == .authorized {
                    return .authorized
                } else if mic == .notDetermined || speech == .notDetermined {
                    return .notDetermined
                } else {
                    return .unavailable
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() {
        checkCurrentPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Checks current permission states
    func checkCurrentPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
    }
    
    /// Requests microphone permission with clear rationale
    func requestMicrophonePermission() -> AnyPublisher<PermissionState, Never> {
        return Future { [weak self] promise in
            // Show rationale before requesting permission
            let rationale = """
            Microphone access is required to:
            • Record audio for transcription
            • Monitor audio levels during recording
            • Ensure high-quality audio capture
            
            Your audio is processed locally and not shared.
            """
            
            // In a real app, you might show an alert with this rationale
            print("Microphone Permission Rationale: \(rationale)")
            
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    let state: PermissionState = granted ? .authorized : .denied
                    self?.microphonePermission = state
                    promise(.success(state))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Requests speech recognition permission with clear rationale
    func requestSpeechRecognitionPermission() -> AnyPublisher<PermissionState, Never> {
        #if canImport(Speech)
        return Future { [weak self] promise in
            // Show rationale before requesting permission
            let rationale = """
            Speech Recognition access is required to:
            • Transcribe recorded audio to text
            • Enable searchable transcriptions
            • Provide accessibility features
            
            All processing is done on-device for privacy.
            """
            
            // In a real app, you might show an alert with this rationale
            print("Speech Recognition Permission Rationale: \(rationale)")
            
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    let state = self?.mapSpeechAuthorizationStatus(status) ?? .unavailable
                    self?.speechRecognitionPermission = state
                    promise(.success(state))
                }
            }
        }
        .eraseToAnyPublisher()
        #else
        return Just(.unavailable).eraseToAnyPublisher()
        #endif
    }
    
    /// Requests all permissions
    func requestAllPermissions() -> AnyPublisher<[PermissionState], Never> {
        let micPublisher = requestMicrophonePermission()
        let speechPublisher = requestSpeechRecognitionPermission()
        
        return Publishers.CombineLatest(micPublisher, speechPublisher)
            .map { micState, speechState in
                return [micState, speechState]
            }
            .eraseToAnyPublisher()
    }
    
    /// Opens app settings for permission management
    func openAppSettings() {
        #if canImport(UIKit)
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
        #endif
    }
    
    /// Gets permission state for a specific type
    func getPermissionState(for type: PermissionType) -> PermissionState {
        switch type {
        case .microphone:
            return microphonePermission
        case .speechRecognition:
            return speechRecognitionPermission
        }
    }
    
    /// Checks if all required permissions are granted
    var allPermissionsGranted: Bool {
        return microphonePermission.isAuthorized && speechRecognitionPermission.isAuthorized
    }
    
    /// Gets a summary of all permission states
    var permissionSummary: String {
        let micStatus = "Microphone: \(microphonePermission.rawValue)"
        let speechStatus = "Speech Recognition: \(speechRecognitionPermission.rawValue)"
        return "\(micStatus), \(speechStatus)"
    }
    
    // MARK: - Private Methods
    
    private func checkMicrophonePermission() {
        let status = AVAudioSession.sharedInstance().recordPermission
        microphonePermission = mapAVAudioSessionPermissionStatus(status)
    }
    
    private func checkSpeechRecognitionPermission() {
        #if canImport(Speech)
        let status = SFSpeechRecognizer.authorizationStatus()
        speechRecognitionPermission = mapSpeechAuthorizationStatus(status)
        #else
        speechRecognitionPermission = .unavailable
        #endif
    }
    
    private func mapAVAudioSessionPermissionStatus(_ status: AVAudioSession.RecordPermission) -> PermissionState {
        switch status {
        case .undetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .granted:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }
    

    
    #if canImport(Speech)
    private func mapSpeechAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
    }
    #endif
}

// MARK: - Convenience Extensions

extension PermissionManager {
    
    /// Returns true if the app can request permissions
    var canRequestPermissions: Bool {
        return microphonePermission.canRequest || speechRecognitionPermission.canRequest
    }
    
    /// Returns true if any permissions require going to settings
    var requiresSettingsAccess: Bool {
        return microphonePermission.requiresSettings || speechRecognitionPermission.requiresSettings
    }
    
    /// Gets a list of permissions that need to be requested
    var permissionsToRequest: [PermissionType] {
        var types: [PermissionType] = []
        
        if microphonePermission.canRequest {
            types.append(.microphone)
        }
        
        if speechRecognitionPermission.canRequest {
            types.append(.speechRecognition)
        }
        
        return types
    }
    
    /// Gets a list of permissions that are denied
    var deniedPermissions: [PermissionType] {
        var types: [PermissionType] = []
        
        if microphonePermission == .denied {
            types.append(.microphone)
        }
        
        if speechRecognitionPermission == .denied {
            types.append(.speechRecognition)
        }
        
        return types
    }
}

// MARK: - Testing Support

extension PermissionManager {
    
    #if DEBUG
    /// Simulates permission state changes for testing
    func simulatePermissionChange(for type: PermissionType, to state: PermissionState) {
        switch type {
        case .microphone:
            microphonePermission = state
        case .speechRecognition:
            speechRecognitionPermission = state
        }
    }
    
    /// Resets all permissions to not determined for testing
    func resetPermissionsForTesting() {
        microphonePermission = .notDetermined
        speechRecognitionPermission = .notDetermined
    }
    #endif
} 
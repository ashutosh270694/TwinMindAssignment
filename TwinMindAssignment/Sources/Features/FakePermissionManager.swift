import Foundation
import Combine

/// Fake implementation of PermissionManager for testing purposes
/// Ensures all types used by UI exist even if implementation is stubbed
final class FakePermissionManager: ObservableObject {
    
    // MARK: - Permission State (Same as real PermissionManager)
    
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
    
    // MARK: - Permission Types (Same as real PermissionManager)
    
    enum PermissionType: String, CaseIterable {
        case microphone = "Microphone"
        case speechRecognition = "Speech Recognition"
        
        var description: String {
            return rawValue
        }
        
        var isAvailable: Bool {
            return true // Always available in fake implementation
        }
    }
    
    // MARK: - Published Properties
    
    @Published var microphonePermission: PermissionState = .authorized
    @Published var speechRecognitionPermission: PermissionState = .authorized
    
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
    
    init(
        microphonePermission: PermissionState = .authorized,
        speechRecognitionPermission: PermissionState = .authorized
    ) {
        self.microphonePermission = microphonePermission
        self.speechRecognitionPermission = speechRecognitionPermission
    }
    
    // MARK: - Public Methods (Stubbed)
    
    /// Checks current permission states (no-op in fake)
    func checkCurrentPermissions() {
        // No-op for testing
    }
    
    /// Requests microphone permission (simulated)
    func requestMicrophonePermission() -> AnyPublisher<PermissionState, Never> {
        // Simulate permission request with delay
        return Just(microphonePermission)
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    /// Requests speech recognition permission (simulated)
    func requestSpeechRecognitionPermission() -> AnyPublisher<PermissionState, Never> {
        // Simulate permission request with delay
        return Just(speechRecognitionPermission)
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    /// Requests all permissions (simulated)
    func requestAllPermissions() -> AnyPublisher<[PermissionState], Never> {
        let micPublisher = requestMicrophonePermission()
        let speechPublisher = requestSpeechRecognitionPermission()
        
        return Publishers.CombineLatest(micPublisher, speechPublisher)
            .map { micState, speechState in
                return [micState, speechState]
            }
            .eraseToAnyPublisher()
    }
    
    /// Opens app settings (no-op in fake)
    func openAppSettings() {
        // No-op for testing
        print("FakePermissionManager: Would open app settings")
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
    
    // MARK: - Convenience Extensions (Same as real PermissionManager)
    
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

// MARK: - Convenience Initializers

extension FakePermissionManager {
    
    /// Creates a fake permission manager with all permissions granted
    static func allGranted() -> FakePermissionManager {
        return FakePermissionManager(
            microphonePermission: .authorized,
            speechRecognitionPermission: .authorized
        )
    }
    
    /// Creates a fake permission manager with all permissions denied
    static func allDenied() -> FakePermissionManager {
        return FakePermissionManager(
            microphonePermission: .denied,
            speechRecognitionPermission: .denied
        )
    }
    
    /// Creates a fake permission manager with mixed permission states
    static func mixed() -> FakePermissionManager {
        return FakePermissionManager(
            microphonePermission: .authorized,
            speechRecognitionPermission: .denied
        )
    }
    
    /// Creates a fake permission manager with permissions not determined
    static func notDetermined() -> FakePermissionManager {
        return FakePermissionManager(
            microphonePermission: .notDetermined,
            speechRecognitionPermission: .notDetermined
        )
    }
    
    /// Creates a fake permission manager with restricted permissions
    static func restricted() -> FakePermissionManager {
        return FakePermissionManager(
            microphonePermission: .restricted,
            speechRecognitionPermission: .restricted
        )
    }
}

// MARK: - Testing Support

extension FakePermissionManager {
    
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
    
    /// Simulates a permission request flow
    func simulatePermissionRequest(for type: PermissionType, willGrant: Bool) {
        let newState: PermissionState = willGrant ? .authorized : .denied
        
        switch type {
        case .microphone:
            microphonePermission = newState
        case .speechRecognition:
            speechRecognitionPermission = newState
        }
    }
    
    /// Simulates a permission request that takes time
    func simulateDelayedPermissionRequest(for type: PermissionType, willGrant: Bool, delay: TimeInterval = 1.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.simulatePermissionRequest(for: type, willGrant: willGrant)
        }
    }
} 
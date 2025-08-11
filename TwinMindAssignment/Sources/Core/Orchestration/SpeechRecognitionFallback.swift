import Foundation
import Combine
import Speech

/// Provides Apple SFSpeechRecognizer as a fallback when the transcription API fails
final class SpeechRecognitionFallback: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isAuthorized = false
    @Published var isAvailable = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Check availability on initialization
        _ = checkAvailability()
        requestAuthorization()
    }
    
    // MARK: - Public Methods
    
    /// Transcribes audio using Apple's SFSpeechRecognizer
    /// - Parameter audioFileURL: URL of the audio file to transcribe
    /// - Returns: Publisher that emits transcription result or error
    func transcribe(audioFileURL: URL) -> AnyPublisher<String, Error> {
        guard isAvailable && isAuthorized else {
            return Fail(error: SpeechRecognitionError.notAvailable)
                .eraseToAnyPublisher()
        }
        
        return performTranscription(audioFileURL: audioFileURL)
    }
    
    /// Checks if speech recognition is available on the device
    func checkAvailability() -> Bool {
        #if DEBUG
        // In DEBUG builds, always return true for testing
        isAvailable = true
        return true
        #else
        // Check actual availability - SFSpeechRecognizer doesn't have isSupported method
        // Instead, we'll try to create one and see if it's available
        let isAvailable = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) != nil
        self.isAvailable = isAvailable
        return isAvailable
        #endif
    }
    
    /// Requests authorization to use speech recognition
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.isAuthorized = (status == .authorized)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performTranscription(audioFileURL: URL) -> AnyPublisher<String, Error> {
        return Future { promise in
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
                promise(.failure(SpeechRecognitionError.recognizerNotAvailable))
                return
            }
            
            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
            request.shouldReportPartialResults = false
            
            // Perform recognition
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                if let result = result, result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    promise(.success(transcription))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Error Types

extension SpeechRecognitionFallback {
    
    /// Errors that can occur during speech recognition
    enum SpeechRecognitionError: Error, LocalizedError {
        case notAvailable
        case notAuthorized
        case recognizerNotAvailable
        case audioFileNotFound
        case transcriptionFailed
        
        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "Speech recognition is not available on this device"
            case .notAuthorized:
                return "Speech recognition permission not granted"
            case .recognizerNotAvailable:
                return "Speech recognizer could not be created"
            case .audioFileNotFound:
                return "Audio file not found"
            case .transcriptionFailed:
                return "Speech transcription failed"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .notAvailable:
                return "This device does not support speech recognition"
            case .notAuthorized:
                return "Please grant speech recognition permission in Settings"
            case .recognizerNotAvailable:
                return "Try again or restart the app"
            case .audioFileNotFound:
                return "Ensure the audio file exists and is accessible"
            case .transcriptionFailed:
                return "Check the audio file quality and try again"
            }
        }
    }
}

// MARK: - Convenience Extensions

extension SpeechRecognitionFallback {
    
    /// Returns a human-readable status description
    var statusDescription: String {
        if !isAvailable {
            return "Not Available"
        } else if !isAuthorized {
            return "Not Authorized"
        } else {
            return "Ready"
        }
    }
    
    /// Returns true if speech recognition is ready to use
    var isReady: Bool {
        return isAvailable && isAuthorized
    }
    
    /// Gets the current authorization status
    var authorizationStatus: String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .authorized:
            return "Authorized"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Testing Support

extension SpeechRecognitionFallback {
    
    #if DEBUG
    /// Simulates transcription for testing purposes
    /// - Parameter audioFileURL: Audio file URL (ignored in testing)
    /// - Returns: Publisher that emits a fake transcription result
    func transcribeForTesting(audioFileURL: URL) -> AnyPublisher<String, Error> {
        // Return a stub string in DEBUG builds
        return Just("This is a fake transcription result from Apple SFSpeechRecognizer for testing purposes.")
            .setFailureType(to: Error.self)
            .delay(for: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
    
    /// Simulates authorization status for testing
    /// - Parameter authorized: Simulated authorization status
    func simulateAuthorization(_ authorized: Bool) {
        isAuthorized = authorized
    }
    
    /// Simulates availability for testing
    /// - Parameter available: Simulated availability status
    func simulateAvailability(_ available: Bool) {
        isAvailable = available
    }
    #endif
}

// MARK: - Conditional Compilation

#if DEBUG
// In DEBUG builds, provide additional testing capabilities
extension SpeechRecognitionFallback {
    
    /// Creates a test instance with specific configuration
    static func createForTesting(
        isAvailable: Bool = true,
        isAuthorized: Bool = true
    ) -> SpeechRecognitionFallback {
        let fallback = SpeechRecognitionFallback()
        fallback.simulateAvailability(isAvailable)
        fallback.simulateAuthorization(isAuthorized)
        return fallback
    }
}
#endif 
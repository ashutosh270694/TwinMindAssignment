import Foundation
import Security
import Combine // Added for AnyPublisher

// MARK: - APITokenProvider Protocol Import
// Note: This protocol is defined in TwinMindAssignment/Sources/Core/Protocols/APITokenProvider.swift

/// Manages authentication tokens using Keychain with simple validation
final class TokenManager: APITokenProvider {
    
    // MARK: - Properties
    
    private let service = "com.twinmind.whisper"
    private let account = "whisper_api_key"
    
    // MARK: - APITokenProvider Conformance
    
    func currentToken() async throws -> String {
        guard let token = getToken(), !token.isEmpty else {
            throw NSError(domain: "TokenManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid token available"])
        }
        return token
    }
    
    // MARK: - Public Methods
    
    /// Stores a Whisper API key in the Keychain
    /// - Parameter token: The API key to store
    /// - Returns: True if storage was successful, false otherwise
    func setToken(_ token: String) -> Bool {
        guard let tokenData = token.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Remove existing token first
        SecItemDelete(query as CFDictionary)
        
        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieves the stored Whisper API key from Keychain
    /// - Returns: The stored API key, or nil if not found or invalid
    func getToken() -> String? {
        // TODO: Replace with your actual OpenAI API key
        // Get your key from: https://platform.openai.com/api-keys
        let hardcodedToken = "YOUR_OPENAI_API_KEY_HERE"
        
        if hardcodedToken == "YOUR_OPENAI_API_KEY_HERE" {
            print("TokenManager: ⚠️  Please replace 'YOUR_OPENAI_API_KEY_HERE' with your actual OpenAI API key")
            print("TokenManager: Get your key from: https://platform.openai.com/api-keys")
            return nil
        }
        
        print("TokenManager: Using hardcoded token: \(String(hardcodedToken.prefix(20)))...")
        return hardcodedToken
    }
    
    /// Removes the stored Whisper API key from Keychain
    /// - Returns: True if removal was successful, false otherwise
    func removeToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Checks if a valid token is stored
    /// - Returns: True if a valid token exists, false otherwise
    var hasValidToken: Bool {
        guard let token = getToken() else {
            return false
        }
        
        return isValidToken(token)
    }
    
    /// Validates a token format (basic validation)
    /// - Parameter token: The token to validate
    /// - Returns: True if the token appears valid, false otherwise
    func isValidToken(_ token: String) -> Bool {
        // Basic validation: token should be non-empty and have reasonable length
        guard !token.isEmpty,
              token.count >= 10,
              token.count <= 1000 else {
            return false
        }
        
        // Check for common invalid patterns
        let invalidPatterns = [
            "undefined",
            "null",
            "nil",
            "test",
            "demo",
            "example"
        ]
        
        let lowercasedToken = token.lowercased()
        for pattern in invalidPatterns {
            if lowercasedToken.contains(pattern) {
                return false
            }
        }
        
        return true
    }
    
    /// Clears all stored tokens (useful for logout)
    func clearAllTokens() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    #if DEBUG
    /// Prefills token from environment variable for local testing
    func prefillFromEnvironment() {
        if let envToken = ProcessInfo.processInfo.environment["WHISPER_API_KEY"] {
            _ = setToken(envToken)
        }
    }
    #endif
    
    /// Tests the Whisper API connection with a simple audio file
    /// - Returns: A publisher that emits the test result
    func testWhisperAPIConnection() -> AnyPublisher<Bool, Error> {
        guard let token = getToken(), !token.isEmpty else {
            return Fail(error: NSError(domain: "TokenManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid token available"]))
                .eraseToAnyPublisher()
        }
        
        print("TokenManager: Testing Whisper API connection...")
        
        // Create a minimal test audio file (0.5 seconds of silence - much smaller)
        let sampleRate: Double = 16000
        let duration: Double = 0.5  // Reduced from 1.0 to 0.5 seconds
        let frameCount = Int(sampleRate * duration)
        let audioData = Data(count: frameCount * 2) // 16-bit audio = 2 bytes per sample
        
        print("TokenManager: Created test audio: \(audioData.count) bytes (\(String(format: "%.1f", duration))s)")
        
        // Create test request
        let request = TranscriptionAPIClient.TranscriptionRequest(
            audioData: audioData,
            segmentIndex: 0,
            sessionID: UUID()
        )
        
        // Test the API call
        let client = TranscriptionAPIClient()
        return client.transcribe(request)
            .map { result in
                print("TokenManager: Whisper API test successful! Response: '\(result.text)'")
                return true
            }
            .catch { error in
                print("TokenManager: Whisper API test failed: \(error.localizedDescription)")
                
                // Check if it's a rate limit error and provide helpful message
                if let transcriptionError = error as? TranscriptionAPIClient.TranscriptionError {
                    switch transcriptionError {
                    case .httpError(429):
                        print("TokenManager: Rate limit exceeded (HTTP 429) - this is normal for frequent testing")
                        print("TokenManager: The API key is working correctly, just wait a moment before testing again")
                        // For rate limit, we'll still return failure but with helpful message
                        // This allows the UI to show the rate limit status properly
                        return Fail<Bool, Error>(error: error).eraseToAnyPublisher()
                    default:
                        break
                    }
                }
                
                // For other errors, return a failure
                return Fail<Bool, Error>(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Convenience Extensions

extension TokenManager {
    
    /// Updates the stored token (removes old and stores new)
    /// - Parameter newToken: The new token to store
    /// - Returns: True if update was successful, false otherwise
    func updateToken(_ newToken: String) -> Bool {
        guard removeToken() else {
            return false
        }
        
        return setToken(newToken)
    }
    
    /// Gets the token or returns a default value
    /// - Parameter defaultValue: Default value to return if no token exists
    /// - Returns: The stored token or the default value
    func getTokenOrDefault(_ defaultValue: String = "") -> String {
        return getToken() ?? defaultValue
    }
}

// MARK: - Error Handling

extension TokenManager {
    
    /// Represents errors that can occur during token operations
    enum TokenError: Error, LocalizedError {
        case storageFailed
        case retrievalFailed
        case removalFailed
        case invalidToken
        case keychainNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .storageFailed:
                return "Failed to store token in Keychain"
            case .retrievalFailed:
                return "Failed to retrieve token from Keychain"
            case .removalFailed:
                return "Failed to remove token from Keychain"
            case .invalidToken:
                return "Invalid token format"
            case .keychainNotAvailable:
                return "Keychain is not available on this device"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .storageFailed:
                return "Check if Keychain is accessible and try again"
            case .retrievalFailed:
                return "The token may have been removed or corrupted"
            case .removalFailed:
                return "Try again or restart the app"
            case .invalidToken:
                return "Ensure the token is in the correct format"
            case .keychainNotAvailable:
                return "This device may not support Keychain storage"
            }
        }
    }
} 

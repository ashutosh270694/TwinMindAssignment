import Foundation

/// Represents various API-related errors that can occur during transcription requests
enum APIError: Error, LocalizedError, Equatable {
    
    // MARK: - Network Errors
    
    case networkError(Error)
    case invalidResponse
    case invalidStatusCode(Int)
    case noData
    
    // MARK: - File Errors
    
    case fileNotFound
    case fileReadError(Error)
    case invalidFileFormat
    
    // MARK: - Authentication Errors
    
    case unauthorized
    case invalidToken
    case tokenExpired
    
    // MARK: - Server Errors
    
    case serverError(String)
    case rateLimited
    case serviceUnavailable
    
    // MARK: - Request Errors
    
    case invalidRequest
    case requestTimeout
    case multipartEncodingError
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidStatusCode(let code):
            return "Server returned invalid status code: \(code)"
        case .noData:
            return "No data received from server"
        case .fileNotFound:
            return "Audio file not found"
        case .fileReadError(let error):
            return "Failed to read audio file: \(error.localizedDescription)"
        case .invalidFileFormat:
            return "Invalid audio file format"
        case .unauthorized:
            return "Unauthorized access"
        case .invalidToken:
            return "Invalid authentication token"
        case .tokenExpired:
            return "Authentication token has expired"
        case .serverError(let message):
            return "Server error: \(message)"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        case .invalidRequest:
            return "Invalid request format"
        case .requestTimeout:
            return "Request timed out"
        case .multipartEncodingError:
            return "Failed to encode multipart form data"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkError:
            return "Network connectivity issue"
        case .invalidResponse, .invalidStatusCode, .noData:
            return "Server response issue"
        case .fileNotFound, .fileReadError, .invalidFileFormat:
            return "File handling issue"
        case .unauthorized, .invalidToken, .tokenExpired:
            return "Authentication issue"
        case .serverError, .rateLimited, .serviceUnavailable:
            return "Server-side issue"
        case .invalidRequest, .requestTimeout, .multipartEncodingError:
            return "Request formatting issue"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again"
        case .invalidResponse, .invalidStatusCode, .noData:
            return "Contact support if the problem persists"
        case .fileNotFound:
            return "Ensure the audio file exists and is accessible"
        case .fileReadError:
            return "Try selecting a different audio file"
        case .invalidFileFormat:
            return "Ensure the audio file is in a supported format (M4A, MP3, WAV)"
        case .unauthorized, .invalidToken, .tokenExpired:
            return "Please log in again with valid credentials"
        case .serverError:
            return "The server is experiencing issues. Please try again later"
        case .rateLimited:
            return "Wait a few minutes before making another request"
        case .serviceUnavailable:
            return "The service is temporarily down. Please try again later"
        case .invalidRequest:
            return "Check your request parameters and try again"
        case .requestTimeout:
            return "Try again with a smaller audio file or better connection"
        case .multipartEncodingError:
            return "There was an issue preparing your request. Please try again"
        }
    }
}

// MARK: - Equatable Conformance

extension APIError {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError),
             (.invalidResponse, .invalidResponse),
             (.noData, .noData),
             (.fileNotFound, .fileNotFound),
             (.invalidFileFormat, .invalidFileFormat),
             (.unauthorized, .unauthorized),
             (.invalidToken, .invalidToken),
             (.tokenExpired, .tokenExpired),
             (.rateLimited, .rateLimited),
             (.serviceUnavailable, .serviceUnavailable),
             (.invalidRequest, .invalidRequest),
             (.requestTimeout, .requestTimeout),
             (.multipartEncodingError, .multipartEncodingError):
            return true
            
        case (.invalidStatusCode(let lhsCode), .invalidStatusCode(let rhsCode)):
            return lhsCode == rhsCode
            
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.fileReadError, .fileReadError):
            // For testing purposes, consider file read errors equal
            return true
            
        default:
            return false
        }
    }
} 
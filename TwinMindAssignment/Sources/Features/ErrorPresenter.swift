import Foundation
import Combine
import SwiftUI

/// Represents user-facing errors that can be displayed in the UI
struct UserFacingError: Identifiable, LocalizedError {
    
    // MARK: - Properties
    
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?
    let error: Error?
    let severity: ErrorSeverity
    let category: ErrorCategory
    
    // MARK: - Initialization
    
    init(
        title: String,
        message: String,
        recoverySuggestion: String? = nil,
        error: Error? = nil,
        severity: ErrorSeverity = .medium,
        category: ErrorCategory = .general
    ) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
        self.error = error
        self.severity = severity
        self.category = category
    }
    
    // MARK: - LocalizedError Conformance
    
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return error?.localizedDescription
    }
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .low:
            return "info.circle"
        case .medium:
            return "exclamationmark.triangle"
        case .high:
            return "exclamationmark.octagon"
        case .critical:
            return "xmark.octagon"
        }
    }
}

// MARK: - Error Category

enum ErrorCategory: String, CaseIterable {
    case general = "General"
    case network = "Network"
    case audio = "Audio"
    case transcription = "Transcription"
    case permission = "Permission"
    case file = "File"
    case database = "Database"
    
    var icon: String {
        switch self {
        case .general:
            return "exclamationmark.triangle"
        case .network:
            return "wifi.slash"
        case .audio:
            return "speaker.slash"
        case .transcription:
            return "text.bubble"
        case .permission:
            return "lock.shield"
        case .file:
            return "doc.badge.ellipsis"
        case .database:
            return "externaldrive"
        }
    }
}

// MARK: - Error Presenter

/// Manages error presentation and provides error mapping helpers
final class ErrorPresenter: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentError: UserFacingError?
    @Published var errorHistory: [UserFacingError] = []
    @Published var isShowingError = false
    
    // MARK: - Error Events
    
    let errorEvents = PassthroughSubject<UserFacingError, Never>()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupErrorHandling()
    }
    
    // MARK: - Public Methods
    
    /// Presents an error to the user
    /// - Parameter error: The error to present
    func presentError(_ error: UserFacingError) {
        DispatchQueue.main.async {
            self.currentError = error
            self.errorHistory.append(error)
            self.isShowingError = true
            
            // Auto-dismiss low severity errors after 3 seconds
            if error.severity == .low {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.currentError?.id == error.id {
                        self.dismissCurrentError()
                    }
                }
            }
        }
        
        // Emit error event
        errorEvents.send(error)
    }
    
    /// Dismisses the current error
    func dismissCurrentError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    /// Clears error history
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    /// Gets errors by category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of errors in the specified category
    func getErrorsByCategory(_ category: ErrorCategory) -> [UserFacingError] {
        return errorHistory.filter { $0.category == category }
    }
    
    /// Gets errors by severity
    /// - Parameter severity: The severity to filter by
    /// - Returns: Array of errors with the specified severity
    func getErrorsBySeverity(_ severity: ErrorSeverity) -> [UserFacingError] {
        return errorHistory.filter { $0.severity == severity }
    }
    
    // MARK: - Private Methods
    
    private func setupErrorHandling() {
        errorEvents
            .sink { [weak self] error in
                self?.presentError(error)
            }
            .store(in: &cancellables)
    }
}

// MARK: - Error Mapping Helpers

extension ErrorPresenter {
    
    /// Maps APIError to UserFacingError
    /// - Parameter apiError: The API error to map
    /// - Returns: User-facing error representation
    static func mapAPIError(_ apiError: APIError) -> UserFacingError {
        let category: ErrorCategory
        let severity: ErrorSeverity
        
        switch apiError {
        case .networkError, .requestTimeout, .serviceUnavailable:
            category = .network
            severity = .high
        case .unauthorized, .invalidToken, .tokenExpired:
            category = .permission
            severity = .high
        case .fileNotFound, .fileReadError, .invalidFileFormat:
            category = .file
            severity = .medium
        case .rateLimited:
            category = .network
            severity = .medium
        case .serverError:
            category = .network
            severity = .high
        default:
            category = .general
            severity = .medium
        }
        
        return UserFacingError(
            title: "API Error",
            message: apiError.localizedDescription,
            recoverySuggestion: apiError.recoverySuggestion,
            error: apiError,
            severity: severity,
            category: category
        )
    }
    
    /// Maps permission errors to UserFacingError
    /// - Parameter permissionType: The type of permission that failed
    /// - Returns: User-facing error representation
    static func mapPermissionError(_ permissionType: PermissionManager.PermissionType) -> UserFacingError {
        return UserFacingError(
            title: "Permission Required",
            message: "\(permissionType.description) permission is required to use this feature.",
            recoverySuggestion: "Please grant permission in Settings or try again.",
            severity: .high,
            category: .permission
        )
    }
    
    /// Maps audio recording errors to UserFacingError
    /// - Parameter error: The audio recording error
    /// - Returns: User-facing error representation
    static func mapAudioError(_ error: Error) -> UserFacingError {
        return UserFacingError(
            title: "Audio Recording Error",
            message: error.localizedDescription,
            recoverySuggestion: "Please check your microphone settings and try again.",
            error: error,
            severity: .medium,
            category: .audio
        )
    }
    
    /// Maps transcription errors to UserFacingError
    /// - Parameter error: The transcription error
    /// - Returns: User-facing error representation
    static func mapTranscriptionError(_ error: Error) -> UserFacingError {
        return UserFacingError(
            title: "Transcription Error",
            message: error.localizedDescription,
            recoverySuggestion: "Please check your audio file and try again.",
            error: error,
            severity: .medium,
            category: .transcription
        )
    }
    
    /// Maps network errors to UserFacingError
    /// - Parameter error: The network error
    /// - Returns: User-facing error representation
    static func mapNetworkError(_ error: Error) -> UserFacingError {
        return UserFacingError(
            title: "Network Error",
            message: error.localizedDescription,
            recoverySuggestion: "Please check your internet connection and try again.",
            error: error,
            severity: .high,
            category: .network
        )
    }
    
    /// Maps file system errors to UserFacingError
    /// - Parameter error: The file system error
    /// - Returns: User-facing error representation
    static func mapFileError(_ error: Error) -> UserFacingError {
        return UserFacingError(
            title: "File Error",
            message: error.localizedDescription,
            recoverySuggestion: "Please check file permissions and try again.",
            error: error,
            severity: .medium,
            category: .file
        )
    }
}

// MARK: - Convenience Methods

extension ErrorPresenter {
    
    /// Presents an API error
    /// - Parameter apiError: The API error to present
    func presentAPIError(_ apiError: APIError) {
        let userError = Self.mapAPIError(apiError)
        presentError(userError)
    }
    
    /// Presents a permission error
    /// - Parameter permissionType: The permission type that failed
    func presentPermissionError(_ permissionType: PermissionManager.PermissionType) {
        let userError = Self.mapPermissionError(permissionType)
        presentError(userError)
    }
    
    /// Presents an audio error
    /// - Parameter error: The audio error to present
    func presentAudioError(_ error: Error) {
        let userError = Self.mapAudioError(error)
        presentError(userError)
    }
    
    /// Presents a transcription error
    /// - Parameter error: The transcription error to present
    func presentTranscriptionError(_ error: Error) {
        let userError = Self.mapTranscriptionError(error)
        presentError(userError)
    }
    
    /// Presents a network error
    /// - Parameter error: The network error to present
    func presentNetworkError(_ error: Error) {
        let userError = Self.mapNetworkError(error)
        presentError(userError)
    }
    
    /// Presents a file error
    /// - Parameter error: The file error to present
    func presentFileError(_ error: Error) {
        let userError = Self.mapFileError(error)
        presentError(userError)
    }
}

// MARK: - Testing Support

extension ErrorPresenter {
    
    #if DEBUG
    /// Simulates an error for testing
    /// - Parameter error: The error to simulate
    func simulateError(_ error: UserFacingError) {
        presentError(error)
    }
    
    /// Creates a test error
    /// - Parameter severity: The severity of the test error
    /// - Returns: A test UserFacingError
    static func createTestError(severity: ErrorSeverity = .medium) -> UserFacingError {
        return UserFacingError(
            title: "Test Error",
            message: "This is a test error for testing purposes.",
            recoverySuggestion: "This error is for testing only.",
            severity: severity,
            category: .general
        )
    }
    #endif
} 
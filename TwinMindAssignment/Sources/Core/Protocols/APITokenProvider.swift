import Foundation

/// Protocol for providing API tokens asynchronously
public protocol APITokenProvider {
    func currentToken() async throws -> String
} 
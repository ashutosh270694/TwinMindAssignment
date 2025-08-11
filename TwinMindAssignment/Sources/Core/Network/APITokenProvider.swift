import Foundation

/// APITokenProvider implementation that wraps the existing TokenManager
final class APITokenProviderWrapper: APITokenProvider {
    private let tokenManager: TokenManager
    
    init(tokenManager: TokenManager) {
        self.tokenManager = tokenManager
    }
    
    func currentToken() async throws -> String {
        guard let token = tokenManager.getToken(), !token.isEmpty else {
            throw NSError(domain: "APITokenProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No valid token available"])
        }
        return token
    }
} 
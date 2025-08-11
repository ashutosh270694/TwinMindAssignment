import Foundation
import Combine
import OSLog

/// Real OpenAI Whisper API client for audio transcription
final class TranscriptionAPIClient: ObservableObject {
    
    // MARK: - Types
    
    struct WhisperAPIResponse: Codable {
        let text: String
    }
    
    struct TranscriptionRequest {
        let audioData: Data
        let segmentIndex: Int
        let sessionID: UUID
    }
    
    enum TranscriptionError: LocalizedError {
        case missingToken
        case invalidResponse
        case networkError(Error)
        case httpError(Int)
        case maxRetriesExceeded
        
        var errorDescription: String? {
            switch self {
            case .missingToken:
                return "Missing API token"
            case .invalidResponse:
                return "Invalid API response"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .maxRetriesExceeded:
                return "Maximum retries exceeded"
            }
        }
    }
    
    // MARK: - Properties
    
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "TwinMindAssignment", category: "api")
    private let tokenManager = TokenManager()
    
    // MARK: - Public Methods
    
    /// Transcribes audio data using OpenAI Whisper API
    func transcribe(_ request: TranscriptionRequest) -> AnyPublisher<TranscriptionResult, Error> {
        guard let token = tokenManager.getToken(), !token.isEmpty else {
            logger.error("Missing or empty API token")
            return Fail(error: TranscriptionError.missingToken)
                .eraseToAnyPublisher()
        }
        
        let requestID = UUID()
        logger.info("Starting transcription request \(requestID) for segment \(request.segmentIndex)")
        logger.info("Audio data size: \(request.audioData.count) bytes")
        logger.info("Using token: \(String(token.prefix(20)))...")
        
        return createTranscriptionRequest(request, token: token)
            .flatMap { [weak self] urlRequest in
                // Log curl command before execution
                self?.logCurlCommand(request: urlRequest, audioData: request.audioData)
                return self?.executeWithRetry(urlRequest, requestID: requestID, segmentIndex: request.segmentIndex) ?? Empty().eraseToAnyPublisher()
            }
            .map { response in
                self.logger.info("Transcription successful for request \(requestID): '\(response.text)'")
                return TranscriptionResult(
                    id: UUID().uuidString,
                    text: response.text,
                    confidence: 1.0,
                    language: "en",
                    duration: 0.0,
                    completedAt: Date(),
                    processingTimeMs: 0
                )
            }
            .handleEvents(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.logger.error("Transcription failed for request \(requestID): \(error.localizedDescription)")
                    } else {
                        self?.logger.info("Transcription completed for request \(requestID)")
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func createTranscriptionRequest(_ request: TranscriptionRequest, token: String) -> AnyPublisher<URLRequest, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(TranscriptionError.networkError(NSError(domain: "TranscriptionAPIClient", code: -1, userInfo: nil))))
                return
            }
            
            var urlRequest = URLRequest(url: URL(string: self.baseURL)!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let boundary = UUID().uuidString
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add model field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("whisper-1\r\n".data(using: .utf8)!)
            
            // Add audio file
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"segment_\(request.segmentIndex).m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(request.audioData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add closing boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            urlRequest.httpBody = body
            
            promise(.success(urlRequest))
        }
        .eraseToAnyPublisher()
    }
    
    private func executeWithRetry(_ request: URLRequest, requestID: UUID, segmentIndex: Int) -> AnyPublisher<WhisperAPIResponse, Error> {
        let maxRetries = 5
        let baseDelay: TimeInterval = 1.0
        
        return executeRequest(request, requestID: requestID, segmentIndex: segmentIndex)
            .catch { [weak self] error -> AnyPublisher<WhisperAPIResponse, Error> in
                guard let self = self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                // Only retry on network errors or 5xx server errors
                let shouldRetry = self.shouldRetry(error)
                if shouldRetry && maxRetries > 0 {
                    let delay = baseDelay * pow(2.0, Double(maxRetries - 1)) + Double.random(in: 0...0.1)
                    self.logger.info("Retrying request \(requestID) for segment \(segmentIndex) in \(String(format: "%.1f", delay))s (attempts left: \(maxRetries))")
                    
                    return Just(())
                        .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                        .flatMap { _ in
                            self.executeWithRetry(request, requestID: requestID, segmentIndex: segmentIndex)
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func executeRequest(_ request: URLRequest, requestID: UUID, segmentIndex: Int) -> AnyPublisher<WhisperAPIResponse, Error> {
        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TranscriptionError.invalidResponse
                }
                
                // Enhanced response logging
                self?.logResponseDetails(response: httpResponse, data: data, requestID: requestID, segmentIndex: segmentIndex)
                
                guard httpResponse.statusCode == 200 else {
                    if httpResponse.statusCode >= 500 {
                        throw TranscriptionError.httpError(httpResponse.statusCode)
                    } else if httpResponse.statusCode == 429 {
                        // Rate limit error - provide helpful message
                        self?.logger.error("Rate limit exceeded (HTTP 429) - too many requests")
                        throw TranscriptionError.httpError(httpResponse.statusCode)
                    } else {
                        throw TranscriptionError.httpError(httpResponse.statusCode)
                    }
                }
                
                do {
                    let whisperResponse = try JSONDecoder().decode(WhisperAPIResponse.self, from: data)
                    self?.logger.info("Transcription successful for request \(requestID), segment \(segmentIndex)")
                    return whisperResponse
                } catch {
                    self?.logger.error("Failed to decode response for request \(requestID): \(error.localizedDescription)")
                    throw TranscriptionError.invalidResponse
                }
            }
            .mapError { error in
                if let transcriptionError = error as? TranscriptionError {
                    return transcriptionError
                } else {
                    return TranscriptionError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func shouldRetry(_ error: Error) -> Bool {
        switch error {
        case TranscriptionError.httpError(let code):
            return code >= 500 // Retry on server errors
        case TranscriptionError.networkError:
            return true // Retry on network errors
        default:
            return false
        }
    }
    
    private func logCurlCommand(request: URLRequest, audioData: Data) {
        guard let url = request.url else {
            logger.error("Could not get URL for curl command")
            return
        }
        
        var curlCommand = "curl -X POST \"\(url.absoluteString)\""
        
        if let method = request.httpMethod {
            curlCommand += " -X \(method)"
        }
        
        if let token = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(of: "Bearer ", with: "") {
            curlCommand += " -H \"Authorization: Bearer \(token)\""
        }
        
        if let contentType = request.value(forHTTPHeaderField: "Content-Type") {
            curlCommand += " -H \"Content-Type: \(contentType)\""
        }
        
        if let boundary = request.value(forHTTPHeaderField: "Content-Type")?.replacingOccurrences(of: "multipart/form-data; boundary=", with: "") {
            curlCommand += " -F \"file=@segment_\(audioData.count)bytes\"" // Placeholder for audio data size
        }
        
        logger.info("Executing curl command: \(curlCommand)")
    }
    
    private func logResponseDetails(response: HTTPURLResponse, data: Data, requestID: UUID, segmentIndex: Int) {
        let statusCode = response.statusCode
        let statusMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let contentType = response.allHeaderFields["Content-Type"] as? String
        let contentLength = response.allHeaderFields["Content-Length"] as? String
        
        logger.info("HTTP \(statusCode) \(statusMessage) for request \(requestID), segment \(segmentIndex)")
        logger.info("Content-Type: \(contentType ?? "N/A")")
        logger.info("Content-Length: \(contentLength ?? "N/A")")
        
        if let headers = response.allHeaderFields as? [String: String] {
            logger.info("Headers: \(headers.map { "\($0.key): \($0.value)" }.joined(separator: ", "))")
        }
        
        if let responseBody = String(data: data, encoding: .utf8) {
            logger.info("Response Body (first 100 chars): \(responseBody.prefix(100))")
        }
    }
} 
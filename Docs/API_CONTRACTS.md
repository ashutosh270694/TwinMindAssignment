# API Contracts Documentation

## Overview

This document defines the API contracts for the TwinMindAssignment application, including endpoint specifications, request/response formats, error handling, and security considerations. The application integrates with external transcription services through RESTful APIs.

## 🔗 API Endpoints

### Transcription Service

#### POST /transcribe
Transcribes an audio file and returns the transcription result.

**Endpoint**: `/transcribe`  
**Method**: `POST`  
**Content-Type**: `multipart/form-data`  
**Authentication**: Bearer Token

**Request Headers**:
```
Authorization: Bearer <api_token>
Content-Type: multipart/form-data; boundary=<boundary>
User-Agent: TwinMindAssignment/1.0
Accept: application/json
```

**Request Body (Multipart Form Data)**:
```
--<boundary>
Content-Disposition: form-data; name="session_id"
Content-Type: text/plain

<uuid_string>
--<boundary>
Content-Disposition: form-data; name="segment_index"
Content-Type: text/plain

<integer>
--<boundary>
Content-Disposition: form-data; name="audio_file"
Content-Type: audio/m4a
Content-Transfer-Encoding: binary

<binary_audio_data>
--<boundary>--
```

**Request Fields**:
- `session_id` (string): Unique identifier for the recording session
- `segment_index` (integer): Index of the audio segment within the session
- `audio_file` (file): M4A audio file to transcribe

**Sample Request**:
```bash
curl -X POST "https://api.transcriptionservice.com/transcribe" \
  -H "Authorization: Bearer your_api_token_here" \
  -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" \
  -F "session_id=123e4567-e89b-12d3-a456-426614174000" \
  -F "segment_index=0" \
  -F "audio_file=@segment_0.m4a"
```

**Response Headers**:
```
Content-Type: application/json
Cache-Control: no-cache
X-Request-ID: req_1234567890abcdef
```

**Success Response (200 OK)**:
```json
{
  "success": true,
  "data": {
    "transcription_id": "trans_9876543210fedcba",
    "session_id": "123e4567-e89b-12d3-a456-426614174000",
    "segment_index": 0,
    "transcript_text": "Hello, this is a test recording for transcription.",
    "confidence_score": 0.95,
    "language_detected": "en-US",
    "processing_time_ms": 1250,
    "word_count": 12,
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "meta": {
    "api_version": "v1.0",
    "model_version": "whisper-large-v3",
    "request_id": "req_1234567890abcdef"
  }
}
```

**Error Response (4xx/5xx)**:
```json
{
  "success": false,
  "error": {
    "code": "AUDIO_FILE_TOO_LARGE",
    "message": "Audio file size exceeds maximum limit of 25MB",
    "details": {
      "max_size_mb": 25,
      "actual_size_mb": 32.5
    }
  },
  "meta": {
    "api_version": "v1.0",
    "request_id": "req_1234567890abcdef",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

## 🚨 Error Handling

### Error Codes

The API uses standardized error codes for consistent error handling:

#### Client Errors (4xx)
- `INVALID_TOKEN` (401): Authentication token is invalid or expired
- `MISSING_REQUIRED_FIELD` (400): Required field is missing from request
- `INVALID_AUDIO_FORMAT` (400): Audio file format is not supported
- `AUDIO_FILE_TOO_LARGE` (400): Audio file exceeds size limit
- `AUDIO_FILE_TOO_SMALL` (400): Audio file is too small for processing
- `INVALID_SESSION_ID` (400): Session ID format is invalid
- `SESSION_NOT_FOUND` (404): Specified session does not exist
- `RATE_LIMIT_EXCEEDED` (429): Too many requests in time period

#### Server Errors (5xx)
- `INTERNAL_SERVER_ERROR` (500): Unexpected server error
- `SERVICE_UNAVAILABLE` (503): Transcription service temporarily unavailable
- `PROCESSING_TIMEOUT` (504): Audio processing exceeded time limit
- `STORAGE_ERROR` (507): Insufficient storage for processing

### Error Response Structure

All error responses follow a consistent structure:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "additional_info": "value"
    }
  },
  "meta": {
    "api_version": "v1.0",
    "request_id": "unique_request_id",
    "timestamp": "ISO_8601_timestamp"
  }
}
```

## 🔄 Retry Policy

### Exponential Backoff Strategy

The application implements a custom retry mechanism with exponential backoff:

```swift
extension Publisher where Failure == Error {
    func retryBackoff(
        maxRetries: Int,
        baseDelay: TimeInterval,
        customRetryCondition: @escaping (Error) -> Bool
    ) -> AnyPublisher<Output, Failure>
}
```

**Retry Configuration**:
- **Maximum Retries**: 5 attempts
- **Base Delay**: 1 second
- **Backoff Multiplier**: 2x (exponential)
- **Maximum Delay**: 30 seconds
- **Jitter**: ±10% random variation

**Retry Schedule**:
1. **1st Retry**: 1 second delay
2. **2nd Retry**: 2 seconds delay
3. **3rd Retry**: 4 seconds delay
4. **4th Retry**: 8 seconds delay
5. **5th Retry**: 16 seconds delay

**Retryable Errors**:
- Network timeouts
- Service unavailable (503)
- Rate limiting (429)
- Internal server errors (5xx)

**Non-Retryable Errors**:
- Authentication failures (401)
- Invalid requests (400)
- Resource not found (404)
- Client-side errors (4xx)

### Implementation Details

```swift
final class TranscriptionAPIClient {
    func transcribe(
        fileURL: URL,
        sessionID: UUID,
        segmentIndex: Int
    ) -> AnyPublisher<TranscriptionResult, APIError> {
        return createTranscriptionRequest(fileURL: fileURL, sessionID: sessionID, segmentIndex: segmentIndex)
            .flatMap { request in
                URLSession.shared.dataTaskPublisher(for: request)
                    .tryMap { data, response in
                        try self.validateResponse(data: data, response: response)
                    }
                    .decode(type: TranscriptionResult.self, decoder: JSONDecoder())
                    .mapError { error in
                        self.mapError(error)
                    }
            }
            .retryBackoff(
                maxRetries: 5,
                baseDelay: 1.0,
                customRetryCondition: { error in
                    self.isRetryableError(error)
                }
            )
            .eraseToAnyPublisher()
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        // Implementation of retryable error logic
    }
}
```

## 🔐 Security Considerations

### Authentication

**Token Management**:
- **Storage**: Secure storage using iOS Keychain Services
- **Format**: Bearer token authentication
- **Expiration**: Tokens have configurable expiration times
- **Refresh**: Automatic token refresh before expiration
- **Validation**: Local token validation before API calls

**Token Storage Implementation**:
```swift
final class TokenManager {
    private let keychain = Keychain(service: "com.twinmind.transcription")
    private let tokenKey = "api_token"
    
    func storeToken(_ token: String) -> Bool {
        do {
            try keychain.set(token, key: tokenKey)
            return true
        } catch {
            Loggers.api.error("Failed to store token: \(error)")
            return false
        }
    }
    
    func retrieveToken() -> String? {
        do {
            return try keychain.get(tokenKey)
        } catch {
            Loggers.api.error("Failed to retrieve token: \(error)")
            return nil
        }
    }
    
    func hasValidToken: Bool {
        guard let token = retrieveToken() else { return false }
        return isValidToken(token)
    }
    
    func isValidToken(_ token: String) -> Bool {
        // Basic validation: non-empty, valid format
        return !token.isEmpty && token.count >= 32
    }
}
```

### Data Protection

**Audio File Security**:
- **File Protection**: Complete file protection for audio files
- **Access Control**: Restricted access to audio files
- **Encryption**: Files encrypted at rest using iOS data protection
- **Temporary Files**: Secure cleanup of temporary processing files

**Network Security**:
- **HTTPS**: All API calls use HTTPS with TLS 1.2+
- **Certificate Pinning**: Optional certificate pinning for production
- **Request Signing**: Request integrity verification
- **Rate Limiting**: Client-side rate limiting to prevent abuse

### Privacy Protection

**Data Minimization**:
- **No PII**: Audio files contain no personally identifiable information
- **Metadata**: Limited metadata collection
- **Retention**: Configurable data retention policies
- **User Control**: User can delete all data at any time

**Compliance**:
- **GDPR**: Right to be forgotten, data portability
- **CCPA**: California Consumer Privacy Act compliance
- **HIPAA**: Healthcare data protection (if applicable)
- **COPPA**: Children's privacy protection

## 📊 Rate Limiting

### Client-Side Rate Limiting

**Request Throttling**:
- **Maximum Requests**: 10 requests per minute
- **Burst Limit**: 5 requests per 10 seconds
- **Queue Management**: Automatic request queuing when limits exceeded
- **Backpressure**: Combine backpressure handling for rate limiting

**Implementation**:
```swift
final class RateLimiter {
    private let maxRequestsPerMinute = 10
    private let maxBurstRequests = 5
    private let burstTimeWindow: TimeInterval = 10
    
    private var requestCount = 0
    private var lastRequestTime = Date()
    private var burstRequests: [Date] = []
    
    func canMakeRequest() -> Bool {
        let now = Date()
        
        // Check minute limit
        if now.timeIntervalSince(lastRequestTime) >= 60 {
            requestCount = 0
            lastRequestTime = now
        }
        
        if requestCount >= maxRequestsPerMinute {
            return false
        }
        
        // Check burst limit
        let recentRequests = burstRequests.filter { 
            now.timeIntervalSince($0) <= burstTimeWindow 
        }
        
        if recentRequests.count >= maxBurstRequests {
            return false
        }
        
        return true
    }
    
    func recordRequest() {
        requestCount += 1
        burstRequests.append(Date())
        
        // Clean up old burst requests
        let now = Date()
        burstRequests = burstRequests.filter { 
            now.timeIntervalSince($0) <= burstTimeWindow 
        }
    }
}
```

## 🔍 Request/Response Validation

### Request Validation

**Input Validation**:
- **Session ID**: UUID format validation
- **Segment Index**: Non-negative integer validation
- **Audio File**: File existence and format validation
- **File Size**: Size limit validation (25MB max)
- **Audio Duration**: Duration limit validation (5 minutes max)

**Validation Implementation**:
```swift
private func validateRequest(
    fileURL: URL,
    sessionID: UUID,
    segmentIndex: Int
) throws {
    // Validate file exists
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        throw APIError.invalidAudioFile("File does not exist")
    }
    
    // Validate file size
    let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
    let maxSizeBytes = 25 * 1024 * 1024 // 25MB
    
    guard fileSize <= maxSizeBytes else {
        throw APIError.audioFileTooLarge(actualSize: fileSize, maxSize: maxSizeBytes)
    }
    
    // Validate segment index
    guard segmentIndex >= 0 else {
        throw APIError.invalidSegmentIndex(segmentIndex)
    }
    
    // Validate session ID format
    guard sessionID.uuidString.count == 36 else {
        throw APIError.invalidSessionID(sessionID.uuidString)
    }
}
```

### Response Validation

**Response Validation**:
- **Status Code**: HTTP status code validation
- **Content Type**: JSON content type validation
- **Response Schema**: JSON schema validation
- **Data Integrity**: Checksum validation (if provided)

**Response Processing**:
```swift
private func validateResponse(data: Data, response: URLResponse) throws -> Data {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse("Not an HTTP response")
    }
    
    // Validate status code
    guard (200...299).contains(httpResponse.statusCode) else {
        let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        throw APIError.serverError(
            statusCode: httpResponse.statusCode,
            message: errorResponse?.error.message ?? "Unknown server error"
        )
    }
    
    // Validate content type
    guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
          contentType.contains("application/json") else {
        throw APIError.invalidResponse("Invalid content type")
    }
    
    return data
}
```

## 📈 Monitoring and Analytics

### API Metrics

**Performance Metrics**:
- **Response Time**: Average, median, 95th percentile
- **Success Rate**: Percentage of successful requests
- **Error Rate**: Breakdown by error type
- **Retry Count**: Average retries per request
- **Queue Depth**: Offline queue size

**Monitoring Implementation**:
```swift
final class APIMetrics {
    private var metrics: [String: [TimeInterval]] = [:]
    private var errorCounts: [String: Int] = [:]
    private var retryCounts: [String: Int] = [:]
    
    func recordRequest(
        endpoint: String,
        duration: TimeInterval,
        success: Bool,
        retryCount: Int
    ) {
        // Record response time
        if metrics[endpoint] == nil {
            metrics[endpoint] = []
        }
        metrics[endpoint]?.append(duration)
        
        // Record error count
        if !success {
            errorCounts[endpoint, default: 0] += 1
        }
        
        // Record retry count
        retryCounts[endpoint, default: 0] += retryCount
    }
    
    func getMetrics(for endpoint: String) -> EndpointMetrics {
        let responseTimes = metrics[endpoint] ?? []
        let errorCount = errorCounts[endpoint] ?? 0
        let retryCount = retryCounts[endpoint] ?? 0
        
        return EndpointMetrics(
            endpoint: endpoint,
            averageResponseTime: responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count),
            successRate: responseTimes.isEmpty ? 1.0 : 1.0 - (Double(errorCount) / Double(responseTimes.count)),
            averageRetryCount: responseTimes.isEmpty ? 0 : Double(retryCount) / Double(responseTimes.count)
        )
    }
}
```

## 🚀 Room for Improvement

### Current Limitations
1. **No Request Batching**: Individual segment processing only
2. **Limited Format Support**: M4A format only
3. **Basic Authentication**: Simple token-based auth
4. **No Webhook Support**: Polling-based status updates only

### API Enhancements
1. **Batch Processing**: Support for multiple segments in single request
2. **Streaming API**: Real-time transcription streaming
3. **Webhook Integration**: Push-based status notifications
4. **Multiple Formats**: Support for WAV, FLAC, MP3

### Security Enhancements
1. **OAuth 2.0**: More secure authentication flow
2. **Request Signing**: HMAC-based request verification
3. **Certificate Pinning**: Enhanced TLS security
4. **Audit Logging**: Comprehensive request/response logging

### Performance Improvements
1. **Connection Pooling**: HTTP connection reuse
2. **Response Caching**: Intelligent response caching
3. **Compression**: Request/response compression
4. **CDN Integration**: Content delivery network support

## 🔮 Future Scope

### Advanced Features
1. **Real-time Transcription**: WebSocket-based live transcription
2. **Custom Models**: User-trained transcription models
3. **Language Detection**: Automatic language identification
4. **Speaker Diarization**: Multiple speaker identification

### Integration Capabilities
1. **Webhook System**: Event-driven architecture
2. **API Versioning**: Backward-compatible API evolution
3. **Rate Limit Headers**: Standard rate limiting headers
4. **Pagination**: Large result set pagination

### Developer Experience
1. **OpenAPI Specification**: Machine-readable API documentation
2. **SDK Generation**: Automatic client SDK generation
3. **Interactive Documentation**: API testing interface
4. **Developer Portal**: Comprehensive developer resources 
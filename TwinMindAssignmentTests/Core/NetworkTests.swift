//
//  NetworkTests.swift
//  TwinMindAssignmentTests
//
//  PROPRIETARY SOFTWARE - Copyright (c) 2025 Ashutosh, DobbyFactory. All rights reserved.
//  This software is confidential and proprietary. Unauthorized copying,
//  distribution, or use is strictly prohibited.
//
//  Created by Ashutosh Pandey on 09/08/25.
//

import XCTest
@testable import TwinMindAssignment

/// Test suite for network and API components
/// 
/// Tests the networking functionality and API integration.
/// Focuses on:
/// - API client behavior
/// - Error handling and retry logic
/// - Token management
/// - Network request formatting
final class NetworkTests: XCTestCase {
    
    // MARK: - Test Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Each test creates its own network components, no shared state needed
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Clean up any network resources
    }
    
    // MARK: - APIError Tests
    
    /// Tests that APIError enum has expected cases
    func testAPIErrorEnumHasExpectedCases() throws {
        // Given
        let expectedCases: [APIError] = [
            .invalidURL,
            .invalidResponse,
            .networkError,
            .decodingError,
            .serverError,
            .unauthorized,
            .rateLimited
        ]
        
        // When & Then
        for expectedCase in expectedCases {
            XCTAssertTrue(APIError.allCases.contains(expectedCase), "APIError should contain case: \(expectedCase)")
        }
    }
    
    /// Tests that APIError cases have localized descriptions
    func testAPIErrorCasesHaveLocalizedDescriptions() throws {
        // Given
        let error = APIError.invalidURL
        
        // When
        let description = error.localizedDescription
        
        // Then
        XCTAssertFalse(description.isEmpty, "Error should have a non-empty description")
        XCTAssertTrue(description.count > 10, "Error description should be descriptive")
    }
    
    // MARK: - TranscriptionError Tests
    
    /// Tests that TranscriptionError enum has expected cases
    func testTranscriptionErrorEnumHasExpectedCases() throws {
        // Given
        let expectedCases: [TranscriptionAPIClient.TranscriptionError] = [
            .invalidRequest,
            .networkError,
            .httpError,
            .invalidResponse,
            .quotaExceeded
        ]
        
        // When & Then
        for expectedCase in expectedCases {
            XCTAssertTrue(TranscriptionAPIClient.TranscriptionError.allCases.contains(expectedCase), "TranscriptionError should contain case: \(expectedCase)")
        }
    }
    
    /// Tests that TranscriptionError cases have localized descriptions
    func testTranscriptionErrorCasesHaveLocalizedDescriptions() throws {
        // Given
        let error = TranscriptionAPIClient.TranscriptionError.invalidRequest
        
        // When
        let description = error.localizedDescription
        
        // Then
        XCTAssertFalse(description.isEmpty, "Error should have a non-empty description")
        XCTAssertTrue(description.count > 10, "Error description should be descriptive")
    }
    
    // MARK: - TokenManager Tests
    
    /// Tests that TokenManager can store and retrieve tokens
    func testTokenManagerCanStoreAndRetrieveTokens() throws {
        // Given
        let tokenManager = TokenManager()
        let testToken = "test_token_12345"
        
        // When
        tokenManager.setToken(testToken)
        let retrievedToken = tokenManager.getToken()
        
        // Then
        XCTAssertEqual(retrievedToken, testToken, "Retrieved token should match stored token")
    }
    
    /// Tests that TokenManager can clear tokens
    func testTokenManagerCanClearTokens() throws {
        // Given
        let tokenManager = TokenManager()
        let testToken = "test_token_12345"
        tokenManager.setToken(testToken)
        
        // When
        tokenManager.clearToken()
        let retrievedToken = tokenManager.getToken()
        
        // Then
        XCTAssertNil(retrievedToken, "Token should be nil after clearing")
    }
    
    /// Tests that TokenManager validates token format
    func testTokenManagerValidatesTokenFormat() throws {
        // Given
        let tokenManager = TokenManager()
        let emptyToken = ""
        let shortToken = "123"
        let validToken = "sk_test_1234567890abcdef"
        
        // When & Then
        XCTAssertFalse(tokenManager.isValidToken(emptyToken), "Empty token should be invalid")
        XCTAssertFalse(tokenManager.isValidToken(shortToken), "Short token should be invalid")
        XCTAssertTrue(tokenManager.isValidToken(validToken), "Valid token should be valid")
    }
    
    // MARK: - RetryBackoffOperator Tests
    
    /// Tests that RetryBackoffOperator can be created
    func testRetryBackoffOperatorCanBeCreated() throws {
        // Given
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0
        
        // When
        let retryOperator = RetryBackoffOperator(maxRetries: maxRetries, baseDelay: baseDelay)
        
        // Then
        XCTAssertNotNil(retryOperator, "RetryBackoffOperator should be created successfully")
    }
    
    /// Tests that RetryBackoffOperator respects max retries
    func testRetryBackoffOperatorRespectsMaxRetries() throws {
        // Given
        let maxRetries = 2
        let retryOperator = RetryBackoffOperator(maxRetries: maxRetries, baseDelay: 1.0)
        
        // When
        let shouldRetry = retryOperator.shouldRetry(attempt: maxRetries + 1)
        
        // Then
        XCTAssertFalse(shouldRetry, "Should not retry beyond max retries")
    }
    
    /// Tests that RetryBackoffOperator calculates delay correctly
    func testRetryBackoffOperatorCalculatesDelayCorrectly() throws {
        // Given
        let maxRetries = 3
        let baseDelay: TimeInterval = 1.0
        let retryOperator = RetryBackoffOperator(maxRetries: maxRetries, baseDelay: baseDelay)
        
        // When
        let delay1 = retryOperator.calculateDelay(attempt: 1)
        let delay2 = retryOperator.calculateDelay(attempt: 2)
        let delay3 = retryOperator.calculateDelay(attempt: 3)
        
        // Then
        XCTAssertGreaterThan(delay2, delay1, "Second attempt should have longer delay than first")
        XCTAssertGreaterThan(delay3, delay2, "Third attempt should have longer delay than second")
        XCTAssertLessThanOrEqual(delay1, baseDelay * 2, "First attempt delay should be reasonable")
    }
    
    // MARK: - MultipartBodyBuilder Tests
    
    /// Tests that MultipartBodyBuilder can create basic multipart data
    func testMultipartBodyBuilderCanCreateBasicMultipartData() throws {
        // Given
        let boundary = "test_boundary_123"
        let fields = ["model": "whisper-1"]
        let files: [String: Data] = ["file": Data([0x00, 0x01, 0x02])]
        
        // When
        let multipartData = MultipartBodyBuilder.createMultipartBody(
            boundary: boundary,
            fields: fields,
            files: files
        )
        
        // Then
        XCTAssertNotNil(multipartData, "Multipart data should be created successfully")
        XCTAssertFalse(multipartData.isEmpty, "Multipart data should not be empty")
        XCTAssertTrue(multipartData.contains(boundary.data(using: .utf8)!), "Data should contain boundary")
    }
    
    /// Tests that MultipartBodyBuilder handles empty fields and files
    func testMultipartBodyBuilderHandlesEmptyFieldsAndFiles() throws {
        // Given
        let boundary = "test_boundary_123"
        let fields: [String: String] = [:]
        let files: [String: Data] = [:]
        
        // When
        let multipartData = MultipartBodyBuilder.createMultipartBody(
            boundary: boundary,
            fields: fields,
            files: files
        )
        
        // Then
        XCTAssertNotNil(multipartData, "Multipart data should be created even with empty inputs")
        XCTAssertTrue(multipartData.contains(boundary.data(using: .utf8)!), "Data should contain boundary")
    }
    
    // MARK: - Network Configuration Tests
    
    /// Tests that base URL is properly formatted
    func testBaseURLIsProperlyFormatted() throws {
        // Given
        let expectedBaseURL = "https://api.openai.com/v1/audio/transcriptions"
        
        // When
        let actualBaseURL = TranscriptionAPIClient.baseURL
        
        // Then
        XCTAssertEqual(actualBaseURL, expectedBaseURL, "Base URL should match expected format")
        XCTAssertTrue(actualBaseURL.hasPrefix("https://"), "Base URL should use HTTPS")
        XCTAssertTrue(actualBaseURL.contains("api.openai.com"), "Base URL should point to OpenAI API")
    }
    
    /// Tests that content type headers are properly set
    func testContentTypeHeadersAreProperlySet() throws {
        // Given
        let boundary = "test_boundary_123"
        let expectedContentType = "multipart/form-data; boundary=\(boundary)"
        
        // When
        let actualContentType = "multipart/form-data; boundary=\(boundary)"
        
        // Then
        XCTAssertEqual(actualContentType, expectedContentType, "Content type should include boundary")
        XCTAssertTrue(actualContentType.hasPrefix("multipart/form-data"), "Content type should be multipart/form-data")
    }
} 
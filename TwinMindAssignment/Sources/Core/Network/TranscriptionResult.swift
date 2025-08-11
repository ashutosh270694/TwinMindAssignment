import Foundation

/// Represents the result of a transcription API request
struct TranscriptionResult: Codable {
    
    // MARK: - Properties
    
    /// Unique identifier for the transcription request
    let id: String
    
    /// The transcribed text content
    let text: String
    
    /// Confidence score for the transcription (0.0 to 1.0)
    let confidence: Double
    
    /// Language code of the transcribed content
    let language: String
    
    /// Duration of the audio in seconds
    let duration: TimeInterval
    
    /// Timestamp when the transcription was completed
    let completedAt: Date
    
    /// Processing time in milliseconds
    let processingTimeMs: Int
    
    /// Any additional metadata returned by the API
    let metadata: [String: String]?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case confidence
        case language
        case duration
        case completedAt = "completed_at"
        case processingTimeMs = "processing_time_ms"
        case metadata
    }
    
    // MARK: - Initialization
    
    init(
        id: String,
        text: String,
        confidence: Double,
        language: String,
        duration: TimeInterval,
        completedAt: Date,
        processingTimeMs: Int,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.language = language
        self.duration = duration
        self.completedAt = completedAt
        self.processingTimeMs = processingTimeMs
        self.metadata = metadata
    }
    
    // MARK: - Decoding
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Double.self, forKey: .confidence)
        language = try container.decode(String.self, forKey: .language)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        
        // Handle date decoding with flexible format
        if let dateString = try? container.decode(String.self, forKey: .completedAt) {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateString) {
                completedAt = date
            } else {
                // Fallback to current date if parsing fails
                completedAt = Date()
            }
        } else {
            completedAt = Date()
        }
        
        processingTimeMs = try container.decode(Int.self, forKey: .processingTimeMs)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
    }
}

// MARK: - Convenience Extensions

extension TranscriptionResult {
    
    /// Returns a formatted confidence percentage
    var confidencePercentage: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    /// Returns a formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Returns a formatted processing time
    var formattedProcessingTime: String {
        if processingTimeMs < 1000 {
            return "\(processingTimeMs)ms"
        } else {
            return String(format: "%.1fs", Double(processingTimeMs) / 1000.0)
        }
    }
} 
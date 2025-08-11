import Foundation
import os

/// Centralized logging system using OSLog with categorized logging
final class Loggers {
    
    // MARK: - Log Categories
    
    /// Audio-related logging (recording, playback, audio session)
    static let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.twinmind", category: "audio")
    
    /// Segment-related logging (creation, processing, status changes)
    static let segments = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.twinmind", category: "segments")
    
    /// API-related logging (network requests, responses, errors)
    static let api = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.twinmind", category: "api")
    
    /// Orchestration-related logging (workflow management, coordination)
    static let orchestration = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.twinmind", category: "orchestration")
    
    /// UI-related logging (view lifecycle, user interactions)
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.twinmind", category: "ui")
    
    /// General application logging
    static let general = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.twinmind", category: "general")
    
    // MARK: - Log Levels
    
    enum LogLevel: String, CaseIterable {
        case debug = "Debug"
        case info = "Info"
        case notice = "Notice"
        case warning = "Warning"
        case error = "Error"
        case fault = "Fault"
        case critical = "Critical"
        
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .notice:
                return .default
            case .warning:
                return .default
            case .error:
                return .error
            case .fault:
                return .fault
            case .critical:
                return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug:
                return "🔍"
            case .info:
                return "ℹ️"
            case .notice:
                return "📝"
            case .warning:
                return "⚠️"
            case .error:
                return "❌"
            case .fault:
                return "💥"
            case .critical:
                return "🚨"
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// Logs a message with the specified level and category
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - category: The logger category to use
    ///   - file: The source file (automatically captured)
    ///   - function: The source function (automatically captured)
    ///   - line: The source line (automatically captured)
    static func log(
        _ message: String,
        level: LogLevel = .info,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(level.emoji) [\(fileName):\(line)] \(function): \(message)"
        
        category.log(level: level.osLogType, "\(logMessage, privacy: .public)")
        
        #if DEBUG
        // Also print to console in debug builds
        print(logMessage)
        #endif
    }
    
    /// Logs a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func debug(
        _ message: String,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// Logs an info message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func info(
        _ message: String,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Logs a warning message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func warning(
        _ message: String,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Logs an error message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func error(
        _ message: String,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Logs a fault message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func fault(
        _ message: String,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .fault, category: category, file: file, function: function, line: line)
    }
    
    /// Logs a critical message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func critical(
        _ message: String,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Convenience Extensions

extension Loggers {
    
    /// Logs audio-related messages
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func audio(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: audio, file: file, function: function, line: line)
    }
    
    /// Logs segment-related messages
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func segments(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: segments, file: file, function: function, line: line)
    }
    
    /// Logs API-related messages
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func api(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: api, file: file, function: function, line: line)
    }
    
    /// Logs orchestration-related messages
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func orchestration(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: orchestration, file: file, function: function, line: line)
    }
    
    /// Logs UI-related messages
    /// - Parameters:
    ///   - message: The message to log
    ///   - level: The log level
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func ui(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: level, category: ui, file: file, function: function, line: line)
    }
}

// MARK: - Error Logging

extension Loggers {
    
    /// Logs an error with context
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context information
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func error(
        _ error: Error,
        context: String = "",
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        log(message, level: .error, category: category, file: file, function: function, line: line)
        
        if let nsError = error as NSError? {
            let nsErrorMessage = "NSError: domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)"
            log(nsErrorMessage, level: .debug, category: category, file: file, function: function, line: line)
        }
    }
    
    /// Logs an error with context using the appropriate category
    /// - Parameters:
    ///   - error: The error to log
    ///   - context: Additional context information
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func logError(
        _ error: Error,
        context: String = "",
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.error(error, context: context, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Performance Logging

extension Loggers {
    
    /// Logs performance metrics
    /// - Parameters:
    ///   - operation: The operation being measured
    ///   - duration: The duration in seconds
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func performance(
        _ operation: String,
        duration: TimeInterval,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let message = "⏱️ Performance: \(operation) took \(duration.formatted(.number.precision(.fractionLength(3))))s"
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Logs memory usage
    /// - Parameters:
    ///   - context: Context for the memory measurement
    ///   - bytes: Memory usage in bytes
    ///   - category: The logger category to use
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line
    static func memory(
        _ context: String,
        bytes: Int64,
        category: Logger = general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let megabytes = Double(bytes) / 1024.0 / 1024.0
        let message = "💾 Memory: \(context) - \(megabytes.formatted(.number.precision(.fractionLength(2)))) MB"
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
}

// MARK: - Testing Support

extension Loggers {
    
    #if DEBUG
    /// Clears all log categories (for testing)
    static func clearLogs() {
        // This would clear logs in debug builds
        // In a real implementation, you might want to clear console output or log files
    }
    
    /// Gets the current log level for a category
    /// - Parameter category: The logger category
    /// - Returns: The current log level
    static func getLogLevel(for category: Logger) -> LogLevel {
        // This would return the current log level
        // For now, return info as default
        return .info
    }
    #endif
} 
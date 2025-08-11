import Foundation
import Combine
import SwiftUI

/// Protocol for analytics tracking
protocol AnalyticsProtocol {
    /// Tracks an event
    /// - Parameter event: The event to track
    func trackEvent(_ event: AnalyticsEvent)
    
    /// Tracks a screen view
    /// - Parameter screen: The screen being viewed
    func trackScreenView(_ screen: String)
    
    /// Tracks user action
    /// - Parameters:
    ///   - action: The action performed
    ///   - category: The category of the action
    ///   - label: Optional label for the action
    func trackUserAction(action: String, category: String, label: String?)
    
    /// Sets user property
    /// - Parameters:
    ///   - key: The property key
    ///   - value: The property value
    func setUserProperty(key: String, value: String)
    
    /// Sets user ID
    /// - Parameter userId: The user identifier
    func setUserId(_ userId: String)
}

/// Represents an analytics event
struct AnalyticsEvent {
    let name: String
    let parameters: [String: Any]
    let timestamp: Date
    
    init(name: String, parameters: [String: Any] = [:]) {
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
    }
}

/// Default analytics implementation
final class DefaultAnalytics: AnalyticsProtocol {
    
    // MARK: - Properties
    
    private var userId: String?
    private var userProperties: [String: String] = [:]
    private let eventQueue = DispatchQueue(label: "AnalyticsQueue", qos: .utility)
    
    // MARK: - AnalyticsProtocol Implementation
    
    func trackEvent(_ event: AnalyticsEvent) {
        eventQueue.async { [weak self] in
            self?.processEvent(event)
        }
    }
    
    func trackScreenView(_ screen: String) {
        let event = AnalyticsEvent(
            name: "screen_view",
            parameters: [
                "screen_name": screen,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        trackEvent(event)
    }
    
    func trackUserAction(action: String, category: String, label: String? = nil) {
        var parameters: [String: Any] = [
            "action": action,
            "category": category,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let label = label {
            parameters["label"] = label
        }
        
        let event = AnalyticsEvent(name: "user_action", parameters: parameters)
        trackEvent(event)
    }
    
    func setUserProperty(key: String, value: String) {
        userProperties[key] = value
    }
    
    func setUserId(_ userId: String) {
        self.userId = userId
    }
    
    // MARK: - Private Methods
    
    private func processEvent(_ event: AnalyticsEvent) {
        // Add user context to event
        var enrichedParameters = event.parameters
        
        if let userId = userId {
            enrichedParameters["user_id"] = userId
        }
        
        // Add user properties
        for (key, value) in userProperties {
            enrichedParameters["user_property_\(key)"] = value
        }
        
        // Log the event (in a real implementation, this would send to analytics service)
        Loggers.api.info("Analytics Event: \(event.name) - \(enrichedParameters)")
        
        // Here you would implement actual analytics service integration
        // For example: Firebase Analytics, Mixpanel, Amplitude, etc.
    }
}

/// No-op analytics implementation for testing
final class NoopAnalytics: AnalyticsProtocol {
    
    func trackEvent(_ event: AnalyticsEvent) {
        // No-op for testing
    }
    
    func trackScreenView(_ screen: String) {
        // No-op for testing
    }
    
    func trackUserAction(action: String, category: String, label: String? = nil) {
        // No-op for testing
    }
    
    func setUserProperty(key: String, value: String) {
        // No-op for testing
    }
    
    func setUserId(_ userId: String) {
        // No-op for testing
    }
}

// MARK: - Analytics Event Definitions

extension AnalyticsEvent {
    
    // MARK: - Recording Events
    
    static func recordingStarted(sessionId: UUID, deviceRoute: String) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "recording_started",
            parameters: [
                "session_id": sessionId.uuidString,
                "device_route": deviceRoute,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func recordingStopped(sessionId: UUID, duration: TimeInterval, segmentCount: Int) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "recording_stopped",
            parameters: [
                "session_id": sessionId.uuidString,
                "duration": duration,
                "segment_count": segmentCount,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func recordingPaused(sessionId: UUID) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "recording_paused",
            parameters: [
                "session_id": sessionId.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func recordingResumed(sessionId: UUID) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "recording_resumed",
            parameters: [
                "session_id": sessionId.uuidString,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    // MARK: - Transcription Events
    
    static func transcriptionStarted(sessionId: UUID, segmentIndex: Int) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "transcription_started",
            parameters: [
                "session_id": sessionId.uuidString,
                "segment_index": segmentIndex,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func transcriptionCompleted(sessionId: UUID, segmentIndex: Int, duration: TimeInterval) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "transcription_completed",
            parameters: [
                "session_id": sessionId.uuidString,
                "segment_index": segmentIndex,
                "duration": duration,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func transcriptionFailed(sessionId: UUID, segmentIndex: Int, error: String) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "transcription_failed",
            parameters: [
                "session_id": sessionId.uuidString,
                "segment_index": segmentIndex,
                "error": error,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    // MARK: - UI Events
    
    static func screenViewed(screenName: String) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "screen_viewed",
            parameters: [
                "screen_name": screenName,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func buttonTapped(buttonName: String, screen: String) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "button_tapped",
            parameters: [
                "button_name": buttonName,
                "screen": screen,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func searchPerformed(query: String, resultCount: Int) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "search_performed",
            parameters: [
                "query_length": query.count,
                "result_count": resultCount,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    // MARK: - Export Events
    
    static func exportStarted(format: String, sessionCount: Int) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "export_started",
            parameters: [
                "format": format,
                "session_count": sessionCount,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func exportCompleted(format: String, sessionCount: Int, duration: TimeInterval) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "export_completed",
            parameters: [
                "format": format,
                "session_count": sessionCount,
                "duration": duration,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
    
    static func exportFailed(format: String, error: String) -> AnalyticsEvent {
        return AnalyticsEvent(
            name: "export_failed",
            parameters: [
                "format": format,
                "error": error,
                "timestamp": Date().timeIntervalSince1970
            ]
        )
    }
}

// MARK: - Analytics Manager

/// Centralized analytics manager
final class AnalyticsManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isEnabled = true
    @Published var analyticsProvider: AnalyticsProtocol
    
    // MARK: - Initialization
    
    init(provider: AnalyticsProtocol = DefaultAnalytics()) {
        self.analyticsProvider = provider
    }
    
    // MARK: - Public Methods
    
    /// Tracks an event if analytics is enabled
    /// - Parameter event: The event to track
    func trackEvent(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        analyticsProvider.trackEvent(event)
    }
    
    /// Tracks a screen view if analytics is enabled
    /// - Parameter screen: The screen being viewed
    func trackScreenView(_ screen: String) {
        guard isEnabled else { return }
        analyticsProvider.trackScreenView(screen)
    }
    
    /// Tracks user action if analytics is enabled
    /// - Parameters:
    ///   - action: The action performed
    ///   - category: The category of the action
    ///   - label: Optional label for the action
    func trackUserAction(action: String, category: String, label: String? = nil) {
        guard isEnabled else { return }
        analyticsProvider.trackUserAction(action: action, category: category, label: label)
    }
    
    /// Sets user property if analytics is enabled
    /// - Parameters:
    ///   - key: The property key
    ///   - value: The property value
    func setUserProperty(key: String, value: String) {
        guard isEnabled else { return }
        analyticsProvider.setUserProperty(key: key, value: value)
    }
    
    /// Sets user ID if analytics is enabled
    /// - Parameter userId: The user identifier
    func setUserId(_ userId: String) {
        guard isEnabled else { return }
        analyticsProvider.setUserId(userId)
    }
    
    /// Enables or disables analytics
    /// - Parameter enabled: Whether analytics should be enabled
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}

// MARK: - Debug Log Console View

#if DEBUG
/// Debug view for displaying logs in the console
struct LogConsoleView: View {
    
    @StateObject private var logManager = LogConsoleManager()
    @State private var selectedCategory: String = "All"
    @State private var selectedLevel: Loggers.LogLevel = .info
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter controls
                filterControls
                
                // Log entries
                logList
            }
            .navigationTitle("Log Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        logManager.clearLogs()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export") {
                        exportLogs()
                    }
                }
            }
        }
        .onAppear {
            logManager.startMonitoring()
        }
        .onDisappear {
            logManager.stopMonitoring()
        }
    }
    
    // MARK: - Subviews
    
    private var filterControls: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Category and level filters
            HStack {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("All")
                    Text("Audio").tag("audio")
                    Text("Segments").tag("segments")
                    Text("API").tag("api")
                    Text("Orchestration").tag("orchestration")
                    Text("UI").tag("ui")
                    Text("General").tag("general")
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                // Level picker
                Picker("Level", selection: $selectedLevel) {
                    ForEach(Loggers.LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var logList: some View {
        List {
            ForEach(filteredLogs, id: \.id) { logEntry in
                LogEntryRow(logEntry: logEntry)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var filteredLogs: [LogEntry] {
        var logs = logManager.logs
        
        // Filter by category
        if selectedCategory != "All" {
            logs = logs.filter { $0.category == selectedCategory }
        }
        
        // Filter by level
        logs = logs.filter { $0.level.rawValue >= selectedLevel.rawValue }
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter { logEntry in
                logEntry.message.localizedCaseInsensitiveContains(searchText) ||
                logEntry.file.localizedCaseInsensitiveContains(searchText) ||
                logEntry.function.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs
    }
    
    // MARK: - Private Methods
    
    private func exportLogs() {
        let content = filteredLogs.map { logEntry in
            "[\(logEntry.timestamp.formatted())] \(logEntry.level.rawValue) [\(logEntry.category)] \(logEntry.file):\(logEntry.line) \(logEntry.function): \(logEntry.message)"
        }.joined(separator: "\n")
        
        // This would implement actual export functionality
        print("Exporting logs:\n\(content)")
    }
}

// MARK: - Log Entry Model

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: Loggers.LogLevel
    let category: String
    let message: String
    let file: String
    let function: String
    let line: Int
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let logEntry: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(logEntry.level.emoji)
                    .font(.caption)
                
                Text(logEntry.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(logEntry.level.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(logEntry.message)
                .font(.caption)
                .lineLimit(3)
            
            HStack {
                Text("[\(logEntry.category)]")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                Text("\(logEntry.file):\(logEntry.line)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(logEntry.function)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Log Console Manager

@MainActor
final class LogConsoleManager: ObservableObject {
    
    @Published var logs: [LogEntry] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    func startMonitoring() {
        // In a real implementation, this would monitor the actual log system
        // For now, we'll simulate some logs
        simulateLogs()
    }
    
    func stopMonitoring() {
        cancellables.removeAll()
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    private func simulateLogs() {
        // Simulate some sample logs
        let sampleLogs = [
            LogEntry(
                timestamp: Date(),
                level: .info,
                category: "ui",
                message: "RecordingView appeared",
                file: "RecordingView.swift",
                function: "onAppear",
                line: 45
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-1),
                level: .debug,
                category: "audio",
                message: "Audio session configured",
                file: "AudioRecorderEngine.swift",
                function: "configureAudioSession",
                line: 23
            ),
            LogEntry(
                timestamp: Date().addingTimeInterval(-2),
                level: .warning,
                category: "api",
                message: "Network request timeout",
                file: "TranscriptionAPIClient.swift",
                function: "transcribe",
                line: 67
            )
        ]
        
        logs = sampleLogs
    }
}
#endif 
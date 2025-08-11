import Foundation
import Combine
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Service for exporting recording sessions to various formats
final class ExportService: ObservableObject {
    
    // MARK: - Export Formats
    
    enum ExportFormat: String, CaseIterable {
        case text = "txt"
        case zip = "zip"
        
        var displayName: String {
            switch self {
            case .text:
                return "Plain Text"
            case .zip:
                return "ZIP Archive"
            }
        }
        
        var mimeType: String {
            switch self {
            case .text:
                return "text/plain"
            case .zip:
                return "application/zip"
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
    }
    
    // MARK: - Export Options
    
    struct ExportOptions {
        let includeMetadata: Bool
        let includeTimestamps: Bool
        let includeConfidence: Bool
        let format: ExportFormat
        
        static let `default` = ExportOptions(
            includeMetadata: true,
            includeTimestamps: true,
            includeConfidence: true,
            format: .text
        )
    }
    
    // MARK: - Published Properties
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var lastExportURL: URL?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /// Exports a session to the specified format
    /// - Parameters:
    ///   - session: The recording session to export
    ///   - options: Export configuration options
    /// - Returns: Publisher that emits the export result
    func exportSession(
        _ session: RecordingSession,
        options: ExportOptions = .default
    ) -> AnyPublisher<URL, Error> {
        return Future { [weak self] promise in
            self?.performExport(session: session, options: options) { result in
                switch result {
                case .success(let url):
                    promise(.success(url))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Exports multiple sessions to a single file
    /// - Parameters:
    ///   - sessions: Array of recording sessions to export
    ///   - options: Export configuration options
    /// - Returns: Publisher that emits the export result
    func exportSessions(
        _ sessions: [RecordingSession],
        options: ExportOptions = .default
    ) -> AnyPublisher<URL, Error> {
        return Future { [weak self] promise in
            self?.performBatchExport(sessions: sessions, options: options) { result in
                switch result {
                case .success(let url):
                    promise(.success(url))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Shows the share sheet for an exported file
    /// - Parameter fileURL: The URL of the file to share
    func shareExportedFile(_ fileURL: URL) {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            self.showShareSheet(for: fileURL)
        }
        #endif
    }
    
    // MARK: - Private Methods
    
    private func performExport(
        session: RecordingSession,
        options: ExportOptions,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.isExporting = true
            self?.exportProgress = 0.0
            
            do {
                let exportURL = try self?.createExportFile(
                    for: session,
                    options: options
                )
                
                DispatchQueue.main.async {
                    self?.isExporting = false
                    self?.exportProgress = 1.0
                    self?.lastExportURL = exportURL
                    
                    if let url = exportURL {
                        completion(.success(url))
                    } else {
                        completion(.failure(ExportError.exportFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isExporting = false
                    self?.exportProgress = 0.0
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performBatchExport(
        sessions: [RecordingSession],
        options: ExportOptions,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.isExporting = true
            self?.exportProgress = 0.0
            
            do {
                let exportURL = try self?.createBatchExportFile(
                    for: sessions,
                    options: options
                )
                
                DispatchQueue.main.async {
                    self?.isExporting = false
                    self?.exportProgress = 1.0
                    self?.lastExportURL = exportURL
                    
                    if let url = exportURL {
                        completion(.success(url))
                    } else {
                        completion(.failure(ExportError.exportFailed))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isExporting = false
                    self?.exportProgress = 0.0
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func createExportFile(
        for session: RecordingSession,
        options: ExportOptions
    ) throws -> URL {
        let fileName = "\(session.title)_\(Date().formatted(date: .abbreviated, time: .omitted)).\(options.format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsPath.appendingPathComponent(fileName)
        
        switch options.format {
        case .text:
            let content = generateTextContent(for: session, options: options)
            try content.write(to: exportURL, atomically: true, encoding: .utf8)
        case .zip:
            try createZipArchive(for: session, at: exportURL, options: options)
        }
        
        return exportURL
    }
    
    private func createBatchExportFile(
        for sessions: [RecordingSession],
        options: ExportOptions
    ) throws -> URL {
        let fileName = "Sessions_\(Date().formatted(date: .abbreviated, time: .omitted)).\(options.format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let exportURL = documentsPath.appendingPathComponent(fileName)
        
        switch options.format {
        case .text:
            let content = generateBatchTextContent(for: sessions, options: options)
            try content.write(to: exportURL, atomically: true, encoding: .utf8)
        case .zip:
            try createBatchZipArchive(for: sessions, at: exportURL, options: options)
        }
        
        return exportURL
    }
    
    private func generateTextContent(
        for session: RecordingSession,
        options: ExportOptions
    ) -> String {
        var content = ""
        
        // Header
        content += "Recording Session: \(session.title)\n"
        content += "Date: \(session.startedAt.formatted())\n"
        if let notes = session.notes, !notes.isEmpty {
            content += "Notes: \(notes)\n"
        }
        content += "\n"
        
        // Segments
        for segment in session.segments.sorted(by: { $0.index < $1.index }) {
            content += "Segment \(segment.index)\n"
            content += "Start Time: \(segment.startTime.formatted(.number.precision(.fractionLength(1))))s\n"
            content += "Duration: \(segment.duration.formatted(.number.precision(.fractionLength(1))))s\n"
            content += "Status: \(segment.status.rawValue)\n"
            
            if options.includeConfidence, let transcriptText = segment.transcriptText {
                content += "Transcript: \(transcriptText)\n"
            }
            
            if let lastError = segment.lastError, !lastError.isEmpty {
                content += "Error: \(lastError)\n"
            }
            
            content += "\n"
        }
        
        return content
    }
    
    private func generateBatchTextContent(
        for sessions: [RecordingSession],
        options: ExportOptions
    ) -> String {
        var content = "Batch Export - \(sessions.count) Sessions\n"
        content += "Export Date: \(Date().formatted())\n\n"
        
        for session in sessions {
            content += generateTextContent(for: session, options: options)
            content += "---\n\n"
        }
        
        return content
    }
    
    private func createZipArchive(
        for session: RecordingSession,
        at exportURL: URL,
        options: ExportOptions
    ) throws {
        // This would implement actual ZIP creation
        // For now, we'll create a placeholder
        let content = generateTextContent(for: session, options: options)
        try content.write(to: exportURL, atomically: true, encoding: .utf8)
    }
    
    private func createBatchZipArchive(
        for sessions: [RecordingSession],
        at exportURL: URL,
        options: ExportOptions
    ) throws {
        // This would implement actual ZIP creation
        // For now, we'll create a placeholder
        let content = generateBatchTextContent(for: sessions, options: options)
        try content.write(to: exportURL, atomically: true, encoding: .utf8)
    }
    
    #if canImport(UIKit)
    private func showShareSheet(for fileURL: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        if let presenter = window.rootViewController {
            presenter.present(activityViewController, animated: true)
        }
    }
    #endif
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case exportFailed
    case invalidFormat
    case fileCreationFailed
    case zipCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .exportFailed:
            return "Export failed"
        case .invalidFormat:
            return "Invalid export format"
        case .fileCreationFailed:
            return "Failed to create export file"
        case .zipCreationFailed:
            return "Failed to create ZIP archive"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .exportFailed:
            return "Please try again or check available storage space"
        case .invalidFormat:
            return "Please select a valid export format"
        case .fileCreationFailed:
            return "Please check file permissions and try again"
        case .zipCreationFailed:
            return "Please try again or use a different format"
        }
    }
}

// MARK: - SwiftUI Share Sheet Wrapper

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    init(activityItems: [Any], applicationActivities: [UIActivity]? = nil) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
#endif

// MARK: - Convenience Extensions

extension ExportService {
    
    /// Exports a session and automatically shows the share sheet
    /// - Parameters:
    ///   - session: The recording session to export
    ///   - options: Export configuration options
    /// - Returns: Publisher that emits when export is complete
    func exportAndShare(
        _ session: RecordingSession,
        options: ExportOptions = .default
    ) -> AnyPublisher<Void, Error> {
        return exportSession(session, options: options)
            .handleEvents(receiveOutput: { [weak self] url in
                self?.shareExportedFile(url)
            })
            .map { _ in }
            .eraseToAnyPublisher()
    }
    
    /// Exports multiple sessions and automatically shows the share sheet
    /// - Parameters:
    ///   - sessions: Array of recording sessions to export
    ///   - options: Export configuration options
    /// - Returns: Publisher that emits when export is complete
    func exportAndShare(
        _ sessions: [RecordingSession],
        options: ExportOptions = .default
    ) -> AnyPublisher<Void, Error> {
        return exportSessions(sessions, options: options)
            .handleEvents(receiveOutput: { [weak self] url in
                self?.shareExportedFile(url)
            })
            .map { _ in }
            .eraseToAnyPublisher()
    }
}

// MARK: - Testing Support

extension ExportService {
    
    #if DEBUG
    /// Simulates export for testing
    /// - Parameter session: The session to simulate export for
    /// - Returns: Publisher that emits a mock export result
    func simulateExport(_ session: RecordingSession) -> AnyPublisher<URL, Error> {
        return Just(URL(fileURLWithPath: "/tmp/mock_export.txt"))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    #endif
} 
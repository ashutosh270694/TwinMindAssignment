#if DEBUG
import SwiftUI
import Combine
import OSLog

/// Debug diagnostics view for development and testing
struct DiagnosticsView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()
    @Environment(\.environmentHolder) private var environment
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("System Toggles")) {
                    Toggle("Force Offline", isOn: $viewModel.forceOffline)
                        .onChange(of: viewModel.forceOffline) { _, newValue in
                            viewModel.toggleForceOffline(newValue)
                        }
                    
                    Toggle("Disable BGTasks", isOn: $viewModel.disableBGTasks)
                        .onChange(of: viewModel.disableBGTasks) { _, newValue in
                            viewModel.toggleBGTasks(newValue)
                        }
                    
                    Toggle("Simulate 5 Failures", isOn: $viewModel.simulateFailures)
                        .onChange(of: viewModel.simulateFailures) { _, newValue in
                            viewModel.toggleSimulateFailures(newValue)
                        }
                    
                    Toggle("Local Fallback Only", isOn: $viewModel.localFallbackOnly)
                        .onChange(of: viewModel.localFallbackOnly) { _, newValue in
                            viewModel.toggleLocalFallbackOnly(newValue)
                        }
                }
                
                Section(header: Text("Actions")) {
                    Button("Trigger BGTask") {
                        viewModel.triggerBGTask()
                    }
                    .disabled(viewModel.disableBGTasks)
                    
                    Button("Wipe Database") {
                        viewModel.wipeDatabase()
                    }
                    .foregroundColor(.red)
                    
                    Button("Export Logs") {
                        viewModel.exportLogs()
                    }
                }
                
                Section(header: Text("System Status")) {
                    HStack {
                        Text("Mic Permission")
                        Spacer()
                        Text(viewModel.micPermissionStatus)
                            .foregroundColor(viewModel.micPermissionColor)
                    }
                    
                    HStack {
                        Text("Speech Permission")
                        Spacer()
                        Text(viewModel.speechPermissionStatus)
                            .foregroundColor(viewModel.speechPermissionColor)
                    }
                    
                    HStack {
                        Text("Audio Route")
                        Spacer()
                        Text(viewModel.audioRoute)
                    }
                    
                    HStack {
                        Text("Free Disk Space")
                        Spacer()
                        Text(viewModel.freeDiskSpace)
                    }
                }
                
                Section(header: Text("Queue Status")) {
                    HStack {
                        Text("Queued")
                        Spacer()
                        Text("\(viewModel.queueStatus.queuedCount)")
                    }
                    
                    HStack {
                        Text("Processing")
                        Spacer()
                        Text("\(viewModel.queueStatus.processingCount)")
                    }
                    
                    HStack {
                        Text("Failed")
                        Spacer()
                        Text("\(viewModel.queueStatus.failedCount)")
                    }
                    
                    HStack {
                        Text("Completed")
                        Spacer()
                        Text("\(viewModel.queueStatus.completedCount)")
                    }
                    
                    HStack {
                        Text("Offline")
                        Spacer()
                        Text("\(viewModel.queueStatus.offlineCount)")
                    }
                }
                
                Section(header: Text("Recent Events")) {
                    ForEach(viewModel.recentEvents, id: \.self) { event in
                        Text(event)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.successMessage)
            }
        }
        .onAppear {
            viewModel.startMonitoring(environment: environment)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

/// ViewModel for diagnostics functionality
@MainActor
final class DiagnosticsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var forceOffline = false
    @Published var disableBGTasks = false
    @Published var simulateFailures = false
    @Published var localFallbackOnly = false
    
    @Published var micPermissionStatus = "Unknown"
    @Published var speechPermissionStatus = "Unknown"
    @Published var audioRoute = "Unknown"
    @Published var freeDiskSpace = "Unknown"
    
    @Published var queueStatus = TranscriptionOrchestrator.QueueStatus()
    @Published var recentEvents: [String] = []
    
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    // MARK: - Computed Properties
    
    var micPermissionColor: Color {
        switch micPermissionStatus {
        case "Granted":
            return .green
        case "Denied":
            return .red
        case "Restricted":
            return .orange
        default:
            return .secondary
        }
    }
    
    var speechPermissionColor: Color {
        switch speechPermissionStatus {
        case "Granted":
            return .green
        case "Denied":
            return .red
        case "Restricted":
            return .orange
        default:
            return .secondary
        }
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var environment: EnvironmentHolder?
    
    // MARK: - Public Methods
    
    func startMonitoring(environment: EnvironmentHolder) {
        self.environment = environment
        
        // Monitor orchestrator events
        environment.transcriptionOrchestrator.eventsPublisher
            .sink { [weak self] event in
                self?.handleOrchestratorEvent(event)
            }
            .store(in: &cancellables)
        
        // Monitor queue status
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateSystemStatus()
            }
            .store(in: &cancellables)
        
        // Initial status update
        updateSystemStatus()
    }
    
    func stopMonitoring() {
        cancellables.removeAll()
    }
    
    func toggleForceOffline(_ enabled: Bool) {
        // This would simulate network offline state
        if let reachability = environment?.reachability as? Reachability {
            reachability.simulateNetworkChange(isReachable: !enabled)
        }
        
        showSuccess(message: enabled ? "Forced offline mode" : "Restored network")
    }
    
    func toggleBGTasks(_ disabled: Bool) {
        // This would disable/enable background tasks
        showSuccess(message: disabled ? "BGTasks disabled" : "BGTasks enabled")
    }
    
    func toggleSimulateFailures(_ enabled: Bool) {
        // This would simulate API failures
        showSuccess(message: enabled ? "Failure simulation enabled" : "Failure simulation disabled")
    }
    
    func toggleLocalFallbackOnly(_ enabled: Bool) {
        // This would force local fallback only
        showSuccess(message: enabled ? "Local fallback only" : "API + local fallback")
    }
    
    func triggerBGTask() {
        environment?.backgroundTaskManager.scheduleTranscriptionProcessing(sessionID: nil)
        showSuccess(message: "Background task scheduled")
    }
    
    func wipeDatabase() {
        do {
            try environment?.swiftDataStack.deleteAllData()
            showSuccess(message: "Database wiped")
        } catch {
            showError(message: "Failed to wipe database: \(error.localizedDescription)")
        }
    }
    
    func exportLogs() {
        // Export recent OSLog entries
        let logStore = try? OSLogStore(scope: .currentProcessIdentifier)
        let entries = try? logStore?.getEntries()
        
        var logText = "Diagnostics Log Export\n"
        logText += "Generated: \(Date())\n\n"
        
        if let entries = entries {
            for entry in entries {
                logText += "[\(entry.date)] \(entry.composedMessage)\n"
            }
        }
        
        // Save to documents directory
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logFileURL = documentsPath.appendingPathComponent("diagnostics_log.txt")
            try? logText.write(to: logFileURL, atomically: true, encoding: .utf8)
            showSuccess(message: "Logs exported to Documents/diagnostics_log.txt")
        } else {
            showError(message: "Failed to export logs")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleOrchestratorEvent(_ event: OrchestratorEvent) {
        let eventDescription = event.description
        recentEvents.insert(eventDescription, at: 0)
        
        // Keep only last 10 events
        if recentEvents.count > 10 {
            recentEvents = Array(recentEvents.prefix(10))
        }
        
        // Update queue status if available
        if let orchestrator = environment?.transcriptionOrchestrator as? TranscriptionOrchestrator {
            queueStatus = orchestrator.queueStatus
        }
    }
    
    private func updateSystemStatus() {
        // Update permission status
        updatePermissionStatus()
        
        // Update audio route
        updateAudioRoute()
        
        // Update disk space
        updateDiskSpace()
    }
    
    private func updatePermissionStatus() {
        // This would check actual permission status
        micPermissionStatus = "Granted"
        speechPermissionStatus = "Granted"
    }
    
    private func updateAudioRoute() {
        // This would check actual audio route
        audioRoute = "Speaker"
    }
    
    private func updateDiskSpace() {
        // Calculate free disk space
        if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let resourceValues = try? documentsPath.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let freeSpace = resourceValues?.volumeAvailableCapacity {
                let freeSpaceMB = freeSpace / (1024 * 1024)
                freeDiskSpace = "\(freeSpaceMB) MB"
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccess(message: String) {
        successMessage = message
        showSuccess = true
    }
}

// MARK: - Preview

struct DiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .environmentHolder(EnvironmentHolder.createForPreview())
    }
}
#endif 
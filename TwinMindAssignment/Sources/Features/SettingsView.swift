import SwiftUI
import Combine

/// View for managing application settings, including Whisper API key
struct SettingsView: View {
    
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Whisper API")) {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text(viewModel.tokenStatus)
                            .foregroundColor(viewModel.tokenStatusColor)
                            .font(.caption)
                    }
                    
                    SecureField("Enter Whisper API Key", text: $viewModel.tokenInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Button("Save Key") {
                            viewModel.saveToken()
                        }
                        .disabled(viewModel.tokenInput.isEmpty)
                        
                        Button("Clear Key") {
                            viewModel.clearToken()
                        }
                        .foregroundColor(.red)
                        .disabled(!viewModel.hasValidToken)
                    }
                }
                
                Section(header: Text("API Status")) {
                    HStack {
                        Text("Connection")
                        Spacer()
                        Text(viewModel.connectionStatus)
                            .foregroundColor(viewModel.connectionStatusColor)
                    }
                    
                    HStack {
                        Text("Last Test")
                        Spacer()
                        Text(viewModel.lastTestTime)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Test Connection") {
                        viewModel.testConnection()
                    }
                    .disabled(!viewModel.hasValidToken)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(viewModel.buildNumber)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
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
            viewModel.loadSettings()
        }
    }
}

/// ViewModel for managing settings and Whisper API authentication
@MainActor
final class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var tokenInput = ""
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    // MARK: - Private Properties
    
    private let tokenManager = TokenManager()
    private let apiClient = TranscriptionAPIClient()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var hasValidToken: Bool {
        return tokenManager.hasValidToken
    }
    
    var tokenStatus: String {
        if hasValidToken {
            return "Valid"
        } else {
            return "Not Set"
        }
    }
    
    var tokenStatusColor: Color {
        if hasValidToken {
            return .green
        } else {
            return .red
        }
    }
    
    var connectionStatus: String {
        if hasValidToken {
            return "Ready"
        } else {
            return "No API Key"
        }
    }
    
    var connectionStatusColor: Color {
        if hasValidToken {
            return .green
        } else {
            return .orange
        }
    }
    
    var lastTestTime: String {
        // This would be stored in UserDefaults or similar
        return "Never"
    }
    
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        // Load any saved settings
        if let savedToken = tokenManager.getToken() {
            tokenInput = savedToken
        }
        
        #if DEBUG
        // Prefill from environment variable in DEBUG builds
        tokenManager.prefillFromEnvironment()
        if let envToken = tokenManager.getToken() {
            tokenInput = envToken
        }
        #endif
    }
    
    func saveToken() {
        guard !tokenInput.isEmpty else {
            showError(message: "API key cannot be empty")
            return
        }
        
        if tokenManager.setToken(tokenInput) {
            showSuccess(message: "Whisper API key saved successfully")
            objectWillChange.send()
        } else {
            showError(message: "Failed to save API key")
        }
    }
    
    func clearToken() {
        if tokenManager.removeToken() {
            tokenInput = ""
            showSuccess(message: "API key cleared successfully")
            objectWillChange.send()
        } else {
            showError(message: "Failed to clear API key")
        }
    }
    
    func testConnection() {
        // Create a dummy audio data for testing
        let dummyAudioData = Data("test audio data".utf8)
        let request = TranscriptionAPIClient.TranscriptionRequest(
            audioData: dummyAudioData,
            segmentIndex: 0,
            sessionID: UUID()
        )
        
        apiClient.transcribe(request)
        .sink(
            receiveCompletion: { [weak self] completion in
                switch completion {
                case .finished:
                    self?.showSuccess(message: "Connection test successful")
                case .failure(let error):
                    self?.showError(message: "Connection test failed: \(error.localizedDescription)")
                }
            },
            receiveValue: { _ in
                // Success case handled in completion
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 
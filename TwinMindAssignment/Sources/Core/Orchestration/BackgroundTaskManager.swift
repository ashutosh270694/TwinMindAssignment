import Foundation
import Combine

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Manages background task registration and processing for offline transcription
final class BackgroundTaskManager: ObservableObject, BackgroundTaskManagerProtocol {
    
    // MARK: - Properties
    
    @Published var isRegistered = false
    @Published var lastTaskExecution: Date?
    @Published var taskExecutionCount = 0
    
    var isBackgroundTasksSupported: Bool {
        #if canImport(BackgroundTasks)
        return true
        #else
        return false
        #endif
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Task Identifiers
    
    struct TaskIdentifiers {
        static let transcriptionProcessing = "com.acme.recording.transcription.process"
        static let offlineQueueProcessing = "com.acme.recording.offline.queue"
        static let cleanup = "com.acme.recording.cleanup"
    }
    
    // MARK: - Initialization
    
    init() {
        setupBackgroundTasks()
    }
    
    // MARK: - Public Methods
    
    /// Registers background tasks with the system
    func registerBackgroundTasks() {
        #if canImport(BackgroundTasks)
        registerTranscriptionProcessingTask()
        registerOfflineQueueProcessingTask()
        registerCleanupTask()
        isRegistered = true
        print("BackgroundTaskManager: Background tasks registered successfully")
        #else
        print("BackgroundTaskManager: BackgroundTasks framework not available")
        #endif
    }
    
    /// Schedules a background task for transcription processing
    /// - Parameter sessionID: Optional session ID to process
    func scheduleTranscriptionProcessing(sessionID: UUID? = nil) {
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: TaskIdentifiers.transcriptionProcessing)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 1 minute from now
        
        if sessionID != nil {
            request.requiresNetworkConnectivity = false
            request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // 30 seconds from now
        }
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Transcription processing task scheduled")
        } catch {
            print("BackgroundTaskManager: Failed to schedule transcription processing task: \(error)")
        }
        #else
        print("BackgroundTaskManager: BackgroundTasks framework not available")
        #endif
    }
    
    /// Schedules a background task for offline queue processing
    /// - Parameter sessionID: Optional session ID to process
    func scheduleOfflineQueueProcessing(sessionID: UUID? = nil) {
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: TaskIdentifiers.offlineQueueProcessing)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 120) // 2 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Offline queue processing task scheduled")
        } catch {
            print("BackgroundTaskManager: Failed to schedule offline queue processing task: \(error)")
        }
        #else
        print("BackgroundTaskManager: BackgroundTasks framework not available")
        #endif
    }
    
    /// Schedules a background cleanup task
    func scheduleCleanupTask() {
        #if canImport(BackgroundTasks)
        let request = BGProcessingTaskRequest(identifier: TaskIdentifiers.cleanup)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 300) // 5 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Cleanup task scheduled")
        } catch {
            print("BackgroundTaskManager: Failed to schedule cleanup task: \(error)")
        }
        #else
        print("BackgroundTaskManager: BackgroundTasks framework not available")
        #endif
    }
    
    /// Cancels all scheduled background tasks
    func cancelAllTasks() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("BackgroundTaskManager: All background tasks cancelled")
        #else
        print("BackgroundTaskManager: BackgroundTasks framework not available")
        #endif
    }
    
    // MARK: - Private Methods
    
    private func setupBackgroundTasks() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifiers.transcriptionProcessing,
            using: nil
        ) { task in
            self.handleTranscriptionProcessingTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifiers.offlineQueueProcessing,
            using: nil
        ) { task in
            self.handleOfflineQueueProcessingTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifiers.cleanup,
            using: nil
        ) { task in
            self.handleCleanupTask(task as! BGProcessingTask)
        }
        
        print("BackgroundTaskManager: Background task handlers registered")
        #else
        print("BackgroundTaskManager: BackgroundTasks framework not available")
        #endif
    }
    
    #if canImport(BackgroundTasks)
    private func registerTranscriptionProcessingTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifiers.transcriptionProcessing,
            using: nil
        ) { task in
            self.handleTranscriptionProcessingTask(task as! BGProcessingTask)
        }
    }
    
    private func registerOfflineQueueProcessingTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifiers.offlineQueueProcessing,
            using: nil
        ) { task in
            self.handleOfflineQueueProcessingTask(task as! BGProcessingTask)
        }
    }
    
    private func registerCleanupTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: TaskIdentifiers.cleanup,
            using: nil
        ) { task in
            self.handleCleanupTask(task as! BGProcessingTask)
        }
    }
    
    private func handleTranscriptionProcessingTask(_ task: BGProcessingTask) {
        print("BackgroundTaskManager: Transcription processing task started")
        
        // Set up task expiration handler
        task.expirationHandler = {
            print("BackgroundTaskManager: Transcription processing task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Process transcription queue
        processTranscriptionQueue { success in
            DispatchQueue.main.async {
                self.lastTaskExecution = Date()
                self.taskExecutionCount += 1
            }
            
            task.setTaskCompleted(success: success)
            print("BackgroundTaskManager: Transcription processing task completed with success: \(success)")
        }
    }
    
    private func handleOfflineQueueProcessingTask(_ task: BGProcessingTask) {
        print("BackgroundTaskManager: Offline queue processing task started")
        
        // Set up task expiration handler
        task.expirationHandler = {
            print("BackgroundTaskManager: Offline queue processing task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Process offline queue
        processOfflineQueue { success in
            DispatchQueue.main.async {
                self.lastTaskExecution = Date()
                self.taskExecutionCount += 1
            }
            
            task.setTaskCompleted(success: success)
            print("BackgroundTaskManager: Offline queue processing task completed with success: \(success)")
        }
    }
    
    private func handleCleanupTask(_ task: BGProcessingTask) {
        print("BackgroundTaskManager: Cleanup task started")
        
        // Set up task expiration handler
        task.expirationHandler = {
            print("BackgroundTaskManager: Cleanup task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform cleanup operations
        performCleanup { success in
            DispatchQueue.main.async {
                self.lastTaskExecution = Date()
                self.taskExecutionCount += 1
            }
            
            task.setTaskCompleted(success: success)
            print("BackgroundTaskManager: Cleanup task completed with success: \(success)")
        }
    }
    #endif
    
    // MARK: - Task Processing Methods
    
    private func processTranscriptionQueue(completion: @escaping (Bool) -> Void) {
        // This would integrate with the TranscriptionOrchestrator
        // For now, simulate processing
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            completion(true)
        }
    }
    
    private func processOfflineQueue(completion: @escaping (Bool) -> Void) {
        // This would process segments marked as .queuedOffline
        // For now, simulate processing
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            completion(true)
        }
    }
    
    private func performCleanup(completion: @escaping (Bool) -> Void) {
        // This would clean up old files, expired sessions, etc.
        // For now, simulate cleanup
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            completion(true)
        }
    }
}

// MARK: - Convenience Extensions

extension BackgroundTaskManager {
    
    /// Gets the current background task status
    var statusDescription: String {
        if !isBackgroundTasksSupported {
            return "Not supported"
        } else if isRegistered {
            return "Registered"
        } else {
            return "Not registered"
        }
    }
}

// MARK: - Testing Support

extension BackgroundTaskManager {
    
    #if DEBUG
    /// Simulates background task execution for testing
    func simulateTaskExecution() {
        lastTaskExecution = Date()
        taskExecutionCount += 1
    }
    
    /// Resets task execution count for testing
    func resetTaskExecutionCount() {
        taskExecutionCount = 0
    }
    #endif
} 
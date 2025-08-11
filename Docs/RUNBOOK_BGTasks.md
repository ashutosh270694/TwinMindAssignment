# Background Tasks Runbook

## Overview

This document provides comprehensive guidance for testing, debugging, and troubleshooting background tasks in the TwinMindAssignment application, including required entitlements, testing procedures, and common issues.

## 🔧 Background Task Configuration

### Required Entitlements

**File**: `TwinMindAssignment.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>background-processing</string>
        <string>background-audio</string>
    </array>
    <key>com.apple.developer.background-task-scheduler</key>
    <true/>
</dict>
</plist>
```

**Background Modes**:
- `background-processing`: For offline transcription processing
- `background-audio`: For background audio recording (if needed)

### Info.plist Configuration

**File**: `Info.plist`

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.twinmind.transcription.processing</string>
    <string>com.twinmind.transcription.cleanup</string>
</array>
```

**Task Identifiers**:
- `com.twinmind.transcription.processing`: Main transcription processing
- `com.twinmind.transcription.cleanup`: Cleanup and maintenance tasks

## 🧪 Testing Background Tasks

### Local Testing

#### 1. Simulate Background App Refresh

**Steps**:
1. Run app in simulator or device
2. Start recording or create pending segments
3. Go to Settings → General → Background App Refresh
4. Toggle off/on to trigger background processing
5. Check console logs for background task execution

**Code Example**:
```swift
func testBackgroundAppRefresh() {
    // Create pending segments
    let segment = TranscriptSegment.createTestSegment(status: .queuedOffline)
    repository.saveSegment(segment)
    
    // Simulate background refresh
    NotificationCenter.default.post(
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
    )
    
    // Wait for background processing
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        // Check if segment was processed
        let updatedSegment = self.repository.fetchSegment(id: segment.id)
        XCTAssertEqual(updatedSegment?.status, .completed)
    }
}
```

#### 2. Force Background Task Execution

**Steps**:
1. Add debug button to trigger background task manually
2. Use Xcode's "Simulate Background Fetch" feature
3. Monitor console logs for task execution

**Debug Implementation**:
```swift
#if DEBUG
struct DebugBackgroundTaskView: View {
    @StateObject private var backgroundTaskManager: BackgroundTaskManager
    
    var body: some View {
        VStack {
            Button("Trigger Background Task") {
                backgroundTaskManager.scheduleBackgroundProcessing(for: UUID())
            }
            
            Button("Simulate Background Fetch") {
                UIApplication.shared.performBackgroundTask { _ in
                    // Simulate background work
                    self.backgroundTaskManager.handleBackgroundProcessing(nil)
                }
            }
        }
    }
}
#endif
```

### TestFlight Testing

#### 1. Background Processing Test

**Steps**:
1. Install TestFlight build on device
2. Create offline segments (disable network)
3. Force close app
4. Wait for background processing (15-30 minutes)
5. Reopen app and check segment status

**Test Scenario**:
```swift
func testFlightBackgroundProcessing() {
    // 1. Create offline scenario
    networkManager.simulateOffline()
    
    // 2. Create pending segments
    for i in 0..<5 {
        let segment = createTestSegment(index: i)
        repository.saveSegment(segment)
    }
    
    // 3. Force background
    UIApplication.shared.performBackgroundTask { _ in
        // Simulate background work
        self.processOfflineQueue()
    }
    
    // 4. Verify processing
    let pendingSegments = repository.fetchPendingSegments()
    XCTAssertEqual(pendingSegments.count, 0)
}
```

#### 2. Background Audio Test

**Steps**:
1. Start recording in app
2. Switch to another app or lock device
3. Verify recording continues
4. Check audio file creation

**Audio Session Configuration**:
```swift
func configureBackgroundAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .allowBluetoothA2DP]
        )
        try audioSession.setActive(true)
    } catch {
        Loggers.audio.error("Failed to configure audio session: \(error)")
    }
}
```

## 🐛 Debugging Background Tasks

### Console Logging

**Background Task Logging**:
```swift
final class BackgroundTaskManager {
    func handleBackgroundProcessing(_ task: BGProcessingTask?) {
        Loggers.orchestration.info("Background task started: \(task?.identifier ?? "unknown")")
        
        // Set expiration handler
        task?.expirationHandler = {
            Loggers.orchestration.warning("Background task expired: \(task?.identifier ?? "unknown")")
            self.cleanupBackgroundTask()
        }
        
        // Process offline queue
        processOfflineQueue()
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        Loggers.orchestration.info("Background task completed successfully")
                        task?.setTaskCompleted(success: true)
                    case .failure(let error):
                        Loggers.orchestration.error("Background task failed: \(error)")
                        task?.setTaskCompleted(success: false)
                    }
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
}
```

**Log Categories**:
- `background`: Background task execution
- `orchestration`: Transcription orchestration
- `network`: Network operations
- `storage`: File and database operations

### Debug Console View

**DEBUG-only Log Console**:
```swift
#if DEBUG
struct BackgroundTaskDebugView: View {
    @StateObject private var logManager: LogConsoleManager
    
    var body: some View {
        VStack {
            Text("Background Task Logs")
                .font(.headline)
            
            List(logManager.logEntries.filter { $0.category == "background" }) { entry in
                LogEntryRow(entry: entry)
            }
            
            HStack {
                Button("Refresh") {
                    logManager.refreshLogs()
                }
                
                Button("Clear") {
                    logManager.clearLogs()
                }
            }
        }
    }
}
#endif
```

### Performance Monitoring

**Background Task Metrics**:
```swift
final class BackgroundTaskMetrics {
    private var taskDurations: [String: TimeInterval] = [:]
    private var taskSuccessRates: [String: (success: Int, total: Int)] = [:]
    
    func recordTaskExecution(
        identifier: String,
        duration: TimeInterval,
        success: Bool
    ) {
        taskDurations[identifier, default: 0] += duration
        
        let current = taskSuccessRates[identifier] ?? (0, 0)
        taskSuccessRates[identifier] = (
            success: current.success + (success ? 1 : 0),
            total: current.total + 1
        )
        
        Loggers.background.info("""
            Task metrics updated:
            - Identifier: \(identifier)
            - Duration: \(duration)s
            - Success: \(success)
            - Success Rate: \(Double(current.success + (success ? 1 : 0)) / Double(current.total + 1))
            """)
    }
    
    func getMetrics() -> BackgroundTaskMetricsReport {
        return BackgroundTaskMetricsReport(
            taskDurations: taskDurations,
            taskSuccessRates: taskSuccessRates
        )
    }
}
```

## 🚨 Common Issues and Solutions

### Issue 1: Background Task Not Executing

**Symptoms**:
- Offline segments remain pending
- No background processing logs
- App doesn't process when backgrounded

**Causes**:
1. Missing entitlements
2. Incorrect task identifier registration
3. Background app refresh disabled
4. System resource constraints

**Solutions**:
```swift
// 1. Verify entitlements
func verifyBackgroundTaskConfiguration() {
    #if canImport(BackgroundTasks)
    guard BGTaskScheduler.shared.registeredIdentifiers.contains("com.twinmind.transcription.processing") else {
        Loggers.background.error("Background task not registered")
        return
    }
    #endif
    
    // 2. Check background app refresh
    let backgroundRefreshStatus = UIApplication.shared.backgroundRefreshStatus
    switch backgroundRefreshStatus {
    case .available:
        Loggers.background.info("Background refresh available")
    case .denied:
        Loggers.background.warning("Background refresh denied")
    case .restricted:
        Loggers.background.warning("Background refresh restricted")
    @unknown default:
        Loggers.background.warning("Unknown background refresh status")
    }
}
```

### Issue 2: Background Task Expiring Too Quickly

**Symptoms**:
- Tasks complete but don't finish processing
- "Background task expired" warnings
- Incomplete offline queue processing

**Causes**:
1. Task taking too long to complete
2. System resource pressure
3. Inefficient processing algorithms

**Solutions**:
```swift
// 1. Implement chunked processing
func processOfflineQueueInChunks() -> AnyPublisher<Void, Error> {
    return fetchPendingSegments()
        .flatMap { segments in
            // Process in chunks of 10
            let chunks = segments.chunked(into: 10)
            return Publishers.Sequence(sequence: chunks)
                .flatMap(maxPublishers: .max(1)) { chunk in
                    self.processSegmentChunk(chunk)
                }
                .collect()
                .map { _ in }
        }
        .eraseToAnyPublisher()
}

// 2. Monitor task expiration
func handleBackgroundProcessing(_ task: BGProcessingTask?) {
    let startTime = Date()
    
    task?.expirationHandler = {
        let elapsed = Date().timeIntervalSince(startTime)
        Loggers.background.warning("Task expired after \(elapsed)s")
        
        // Save progress for next execution
        self.saveProcessingProgress()
    }
    
    // Process with progress tracking
    processWithProgressTracking()
}
```

### Issue 3: Background Audio Interruption

**Symptoms**:
- Recording stops when app backgrounds
- Audio session deactivation
- Background audio not working

**Causes**:
1. Audio session not configured for background
2. Missing background audio entitlement
3. Audio session interruption handling

**Solutions**:
```swift
// 1. Configure background audio session
func configureBackgroundAudioSession() {
    do {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
        Loggers.audio.error("Background audio session configuration failed: \(error)")
    }
}

// 2. Handle audio interruptions
func handleAudioInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }
    
    switch type {
    case .began:
        Loggers.audio.info("Audio interruption began")
        pauseRecording()
    case .ended:
        Loggers.audio.info("Audio interruption ended")
        if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumeRecording()
            }
        }
    @unknown default:
        break
    }
}
```

## 📱 Testing on Physical Devices

### Device-Specific Testing

#### iPhone Testing

**Background App Refresh**:
1. Settings → General → Background App Refresh
2. Enable for TwinMindAssignment
3. Test with different refresh settings

**Battery Optimization**:
1. Settings → Battery → Low Power Mode
2. Test background processing with low power
3. Monitor battery usage

#### iPad Testing

**Multitasking**:
1. Use Split View or Slide Over
2. Test background processing while multitasking
3. Verify audio session handling

**Background App Refresh**:
1. Settings → General → Background App Refresh
2. Test with different iPad models
3. Verify background processing timing

### Network Testing

**Offline Scenarios**:
```swift
func testOfflineBackgroundProcessing() {
    // 1. Disable network
    networkManager.simulateOffline()
    
    // 2. Create offline segments
    createOfflineSegments()
    
    // 3. Background app
    NotificationCenter.default.post(
        name: UIApplication.didEnterBackgroundNotification,
        object: nil
    )
    
    // 4. Wait for background processing
    DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
        // Check processing results
        self.verifyOfflineProcessing()
    }
}
```

**Network Transition Testing**:
```swift
func testNetworkTransitionHandling() {
    // 1. Start offline
    networkManager.simulateOffline()
    
    // 2. Create offline segments
    createOfflineSegments()
    
    // 3. Simulate network restoration
    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
        self.networkManager.simulateOnline()
        
        // 4. Verify immediate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.verifyOnlineProcessing()
        }
    }
}
```

## 🔍 Monitoring and Analytics

### Background Task Analytics

**Task Execution Tracking**:
```swift
final class BackgroundTaskAnalytics {
    func trackBackgroundTaskExecution(
        identifier: String,
        duration: TimeInterval,
        success: Bool,
        segmentsProcessed: Int
    ) {
        let event = AnalyticsEvent.backgroundTaskExecuted(
            identifier: identifier,
            duration: duration,
            success: success,
            segmentsProcessed: segmentsProcessed
        )
        
        analytics.trackEvent(event)
        
        // Log detailed metrics
        Loggers.background.info("""
            Background task analytics:
            - Identifier: \(identifier)
            - Duration: \(duration)s
            - Success: \(success)
            - Segments: \(segmentsProcessed)
            """)
    }
}
```

**Performance Metrics**:
```swift
struct BackgroundTaskPerformanceMetrics {
    let averageExecutionTime: TimeInterval
    let successRate: Double
    let segmentsPerTask: Double
    let batteryImpact: Double
    
    static func calculate(from tasks: [BackgroundTaskExecution]) -> BackgroundTaskPerformanceMetrics {
        // Calculate performance metrics
        let totalTime = tasks.map { $0.duration }.reduce(0, +)
        let averageTime = totalTime / Double(tasks.count)
        
        let successCount = tasks.filter { $0.success }.count
        let successRate = Double(successCount) / Double(tasks.count)
        
        let totalSegments = tasks.map { $0.segmentsProcessed }.reduce(0, +)
        let segmentsPerTask = Double(totalSegments) / Double(tasks.count)
        
        return BackgroundTaskPerformanceMetrics(
            averageExecutionTime: averageTime,
            successRate: successRate,
            segmentsPerTask: segmentsPerTask,
            batteryImpact: 0.0 // Calculate based on actual measurements
        )
    }
}
```

## 🚀 Room for Improvement

### Current Limitations
1. **Basic Background Processing**: Simple offline queue processing
2. **Limited Resource Management**: No sophisticated resource optimization
3. **Basic Error Recovery**: Simple retry logic without advanced recovery
4. **Limited Monitoring**: Basic logging without comprehensive metrics

### Background Task Enhancements
1. **Intelligent Scheduling**: Battery and network-aware task scheduling
2. **Resource Optimization**: Memory and CPU usage optimization
3. **Advanced Recovery**: Sophisticated error recovery and retry strategies
4. **Performance Monitoring**: Real-time performance metrics and alerts

### Future Scope
1. **Background Audio Enhancement**: Advanced background audio capabilities
2. **Smart Processing**: AI-powered processing prioritization
3. **Cross-Device Sync**: Background processing across multiple devices
4. **Predictive Processing**: Anticipatory background processing
5. **Advanced Analytics**: Comprehensive background task analytics and optimization 
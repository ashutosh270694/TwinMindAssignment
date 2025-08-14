# TwinMind Assignment - Features & Architecture

## 🎯 **System Overview**

TwinMind Assignment is an iOS audio recording and transcription application that allows users to record audio, automatically transcribe it using AI services, and manage recording sessions. The system is built with a clean architecture approach, separating concerns into distinct layers.

## 🚀 **Core Features**

### 1. **Audio Recording**
- **Real-time audio capture** using device microphone
- **Automatic audio session management** with proper permissions
- **Background recording support** for continuous operation
- **Audio quality configuration** (sample rate, bit depth, format)

### 2. **Automatic Transcription**
- **30-second segment-based transcription** for real-time processing
- **AI-powered transcription** using OpenAI Whisper API
- **Local fallback transcription** using Apple Speech framework
- **Concurrent processing** with retry logic and offline queuing

### 3. **Session Management**
- **Recording session creation** and management
- **Audio segment organization** within sessions
- **Transcription storage** and retrieval
- **Session metadata** (title, duration, timestamps)

### 4. **Data Persistence**
- **SwiftData integration** for local storage
- **Background data processing** for performance
- **Data migration** and schema management
- **Storage cleanup** and optimization

### 5. **User Interface**
- **Recording controls** (start/stop/pause)
- **Session listing** with search and filtering
- **Session detail views** with transcription display
- **Settings and configuration** management

## 🏗️ **Architecture Layers**

### **Domain Layer** (Pure Swift)
- **Models**: `RecordingSession`, `AudioSegment`, `Transcription`
- **Protocols**: Core interfaces for services
- **Business Logic**: Core application rules

### **Core Layer** (Framework Integration)
- **Audio Services**: `AVFoundation` integration
- **Network Services**: API communication
- **Data Services**: SwiftData persistence
- **Orchestration**: Background task management

### **Features Layer** (UI & User Experience)
- **Views**: SwiftUI interfaces
- **ViewModels**: State management
- **User Interactions**: Recording, playback, settings

## 🔄 **Class Communication Flow**

### **1. Audio Recording Flow**

```
User → RecordingView → RecordingViewModel → AudioRecorder → AudioSessionManager
                                                              ↓
                                                      PermissionManager
                                                              ↓
                                                      AVAudioSession
```

**Detailed Flow:**
1. **User** taps record button in `RecordingView`
2. **RecordingViewModel** receives the action and calls `AudioRecorder.startRecording()`
3. **AudioRecorder** requests microphone permission via `PermissionManager`
4. **AudioSessionManager** configures `AVAudioSession` for recording
5. **AudioRecorder** initializes `AVAudioRecorder` and begins recording
6. **RecordingViewModel** updates UI state to show recording status

**Key Classes:**
- `RecordingView`: UI for recording controls
- `RecordingViewModel`: Manages recording state and coordinates services
- `AudioRecorder`: Handles audio recording lifecycle
- `AudioSessionManager`: Manages audio session configuration
- `PermissionManager`: Handles microphone and speech permissions

### **2. Transcription Flow**

```
AudioRecorder → Segmenter → TranscriptionOrchestrator → TranscriptionAPIClient
                              ↓
                      SpeechRecognitionFallback (if API fails)
                              ↓
                      SwiftDataStack (store results)
```

**Detailed Flow:**
1. **AudioRecorder** captures audio and sends to `Segmenter`
2. **Segmenter** splits audio into 30-second segments
3. **TranscriptionOrchestrator** manages transcription queue
4. **TranscriptionAPIClient** sends segments to OpenAI Whisper API
5. **SpeechRecognitionFallback** handles API failures with local transcription
6. **SwiftDataStack** stores transcription results locally

**Key Classes:**
- `Segmenter`: Splits audio into time-based segments
- `TranscriptionOrchestrator`: Manages transcription workflow
- `TranscriptionAPIClient`: Communicates with external AI services
- `SpeechRecognitionFallback`: Provides local transcription backup
- `SwiftDataStack`: Manages data persistence

### **3. Session Management Flow**

```
RecordingView → RecordingViewModel → SessionManager → SwiftDataStack
                                                      ↓
                                              ModelContainer
```

**Detailed Flow:**
1. **RecordingView** requests session creation
2. **RecordingViewModel** calls `SessionManager.createSession()`
3. **SessionManager** creates new `RecordingSession` instance
4. **SwiftDataStack** saves session to `ModelContainer`
5. **UI** updates to show new session in list

**Key Classes:**
- `SessionManager`: Manages recording session lifecycle
- `SwiftDataStack`: Handles SwiftData operations
- `ModelContainer`: SwiftData persistent container

### **4. Data Persistence Flow**

```
Services → SwiftDataStack → ModelContainer → SQLite Database
    ↓
Background Context (for performance)
```

**Detailed Flow:**
1. **Services** request data operations (save, load, delete)
2. **SwiftDataStack** creates appropriate `ModelContext`
3. **ModelContainer** executes operations on background queue
4. **SQLite Database** stores data persistently
5. **UI** receives updates via `@Query` or manual fetches

**Key Classes:**
- `SwiftDataStack`: Central data management
- `ModelContainer`: SwiftData container configuration
- `ModelContext`: Individual data operation contexts

## 🔌 **Key Interfaces & Protocols**

### **AudioRecorderProtocol**
```swift
protocol AudioRecorderProtocol {
    var recordingState: RecordingState { get }
    func startRecording() async throws
    func stopRecording() async throws
    func pauseRecording() async throws
}
```

### **TranscriptionServiceProtocol**
```swift
protocol TranscriptionServiceProtocol {
    var transcriptionState: TranscriptionState { get }
    func transcribeSegment(_ segment: AudioSegment) async throws -> TranscriptionResult
}
```

### **SessionManagerProtocol**
```swift
protocol SessionManagerProtocol {
    func createSession(title: String) async throws -> RecordingSession
    func saveSession(_ session: RecordingSession) async throws
    func loadSessions() async throws -> [RecordingSession]
}
```

## 🌐 **Network Communication**

### **API Client Architecture**
```
TranscriptionAPIClient → URLSession → OpenAI Whisper API
    ↓
RetryBackoffOperator (handles failures)
    ↓
MultipartBodyBuilder (creates request bodies)
```

**Key Components:**
- **TranscriptionAPIClient**: Main API communication
- **RetryBackoffOperator**: Exponential backoff for failed requests
- **MultipartBodyBuilder**: Creates multipart form data for audio uploads
- **TokenManager**: Manages API authentication tokens

## 🔄 **Background Processing**

### **Background Task Management**
```
BackgroundTaskManager → BGTask → TranscriptionOrchestrator
    ↓
Background Context → SwiftData Operations
```

**Key Components:**
- **BackgroundTaskManager**: Registers background tasks with iOS
- **BGTask**: iOS background task framework
- **TranscriptionOrchestrator**: Manages background transcription queue

## 📱 **User Interface Architecture**

### **SwiftUI View Hierarchy**
```
ContentView (TabView)
├── RecordingView (Recording Controls)
├── SessionsListView (Session List)
└── SettingsView (Configuration)
```

### **State Management**
```
@StateObject ViewModels → @Published Properties → UI Updates
    ↓
Environment Objects → Dependency Injection
```

## 🔐 **Security & Privacy**

### **Data Protection**
- **Audio files**: Encrypted at rest using `FileProtectionType.complete`
- **API tokens**: Stored securely in iOS Keychain
- **User data**: Redacted in logs and analytics
- **Permissions**: Explicit user consent for microphone and speech

### **Privacy Features**
- **Local processing**: Fallback transcription without network
- **Data retention**: User-controlled storage cleanup
- **Export control**: User decides what data to share

## 🚦 **Error Handling & Resilience**

### **Error Recovery Strategies**
1. **Network failures**: Automatic retry with exponential backoff
2. **API errors**: Fallback to local transcription
3. **Permission denied**: Graceful degradation with user guidance
4. **Storage full**: Automatic cleanup and user notification
5. **Background limits**: Graceful task rescheduling

### **Error Propagation**
```
Service Layer → ViewModel → View → User (Toast/Alert)
    ↓
Logger (structured logging for debugging)
```

## 📊 **Performance Optimizations**

### **Memory Management**
- **Streaming audio**: Direct to file, not memory
- **Lazy loading**: UI components load on demand
- **Background contexts**: Off-main-thread data operations
- **Image caching**: Efficient asset management

### **Battery Optimization**
- **Efficient audio buffers**: Minimal CPU usage
- **Background task limits**: Respect iOS background constraints
- **Network coalescing**: Batch API requests when possible

## 🔧 **Configuration & Settings**

### **User Configurable Options**
- **Audio quality**: Sample rate, bit depth, format
- **Transcription language**: Multi-language support
- **Storage limits**: Automatic cleanup thresholds
- **Network preferences**: WiFi-only or cellular allowed

### **System Configuration**
- **Background modes**: Audio recording, background processing
- **Privacy permissions**: Microphone, speech recognition
- **Network security**: TLS, certificate pinning options

## 🔄 **Data Flow Summary**

```
User Input → UI Layer → ViewModel Layer → Service Layer → Data Layer
    ↑                                                           ↓
UI Updates ← State Changes ← Business Logic ← External APIs ← Persistence
```

This architecture ensures:
- **Separation of concerns** between layers
- **Testability** through protocol-based dependencies
- **Maintainability** with clear responsibilities
- **Scalability** for future feature additions
- **Performance** through background processing
- **Reliability** with comprehensive error handling

## 📝 **Development Notes**

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **SwiftData**: Modern persistence framework
- **AVFoundation**: Professional audio handling
- **Background Tasks**: iOS background processing support
- **Unified Logging**: Structured logging for debugging 
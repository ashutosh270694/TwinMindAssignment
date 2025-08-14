# TwinMind Assignment - Architecture Diagram

## 🏗️ **System Architecture Overview**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACE LAYER                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  RecordingView  │  SessionsListView  │  SessionDetailView  │  SettingsView  │
│       ↓         │         ↓          │         ↓           │       ↓        │
│RecordingViewModel│SessionsListViewModel│SessionDetailViewModel│  Settings     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CORE SERVICES LAYER                           │
├─────────────────────────────────────────────────────────────────────────────┤
│  AudioRecorder  │  TranscriptionOrchestrator  │  SessionManager  │  SwiftDataStack │
│       ↓         │              ↓              │        ↓         │        ↓        │
│AudioSessionManager│   TranscriptionAPIClient   │   Repositories   │  ModelContainer │
│       ↓         │              ↓              │        ↓         │        ↓        │
│ PermissionManager│  SpeechRecognitionFallback  │                  │   SQLite DB     │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EXTERNAL SERVICES                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  AVAudioSession  │  OpenAI Whisper API  │  Apple Speech  │  iOS Keychain   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🔄 **Data Flow Diagrams**

### **1. Audio Recording Flow**

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    User     │───▶│  RecordingView  │───▶│RecordingViewModel│───▶│ AudioRecorder   │
│   Taps      │    │                 │    │                 │    │                 │
│   Record    │    │                 │    │                 │    │                 │
└─────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                                      │                    │
                                                      ▼                    ▼
                                              ┌─────────────────┐    ┌─────────────────┐
                                              │PermissionManager│    │AudioSessionMgr │
                                              │                 │    │                 │
                                              └─────────────────┘    └─────────────────┘
                                                      │                    │
                                                      ▼                    ▼
                                              ┌─────────────────┐    ┌─────────────────┐
                                              │  AVAudioSession │    │  AVAudioRecorder│
                                              │                 │    │                 │
                                              └─────────────────┘    └─────────────────┘
```

### **2. Transcription Flow**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ AudioRecorder   │───▶│    Segmenter    │───▶│TranscriptionOrch│───▶│TranscriptionAPI │
│                 │    │                 │    │                 │    │     Client      │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  AudioSegment   │    │  RetryBackoff   │    │ OpenAI Whisper  │
                       │                 │    │                 │    │      API        │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │SwiftDataStack  │    │SpeechRecognition│    │  Transcription  │
                       │                 │    │    Fallback     │    │     Result      │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **3. Session Management Flow**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ RecordingView   │───▶│RecordingViewModel│───▶│ SessionManager  │───▶│ SwiftDataStack  │
│                 │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  UI State      │    │RecordingSession │    │ ModelContainer  │
                       │   Updates      │    │                 │    │                 │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔌 **Protocol Dependencies**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PROTOCOL LAYER                                │
├─────────────────────────────────────────────────────────────────────────────┤
│ AudioRecorderProtocol  │  TranscriptionServiceProtocol  │  SessionManagerProtocol │
│         ↓              │              ↓                 │           ↓            │
│   AudioRecorder        │   TranscriptionOrchestrator    │    SessionManager      │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📱 **UI Component Hierarchy**

```
ContentView (TabView)
├── RecordingView
│   ├── RecordingControls
│   ├── StatusDisplay
│   └── TranscriptionPreview
├── SessionsListView
│   ├── SearchBar
│   ├── SessionRow
│   └── EmptyState
└── SettingsView
    ├── AudioSettings
    ├── TranscriptionSettings
    └── StorageSettings
```

## 🔄 **State Management Flow**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Input    │───▶│   ViewModel     │───▶│   Service       │───▶│   Data Layer    │
│                 │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  @Published     │    │  Async/Await    │    │  SwiftData      │
                       │   Properties    │    │   Operations    │    │   Updates       │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │   UI Updates   │    │   Background     │    │   Persistence   │
                       │                 │    │   Processing     │    │                 │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🌐 **Network Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│TranscriptionAPI │───▶│  URLSession     │───▶│  HTTP Request   │───▶│ OpenAI Whisper  │
│    Client       │    │                 │    │                 │    │      API        │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │RetryBackoff     │    │MultipartBody    │    │  HTTP Response  │
                       │                 │    │                 │    │                 │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  Error         │    │  Request Body   │    │  Transcription  │
                       │  Handling      │    │                 │    │     Result      │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔐 **Security & Privacy Flow**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Permission     │───▶│  AudioSession   │───▶│  AudioRecorder  │───▶│  File System    │
│  Request        │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  User Consent   │    │  Session Config │    │  Encrypted      │
                       │                 │    │                 │    │  Storage        │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┘
                       │  Keychain       │    │  Secure Audio   │    │  Privacy        │
                       │  Storage        │    │  Recording      │    │  Compliance     │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📊 **Performance & Background Processing**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│BackgroundTaskMgr│───▶│  BGTask         │───▶│TranscriptionOrch│───▶│  SwiftDataStack │
│                 │    │                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  iOS Background │    │  Background     │    │  Background     │
                       │  Task Framework │    │  Context        │    │  Processing     │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  Task           │    │  Off-Main       │    │  Performance    │
                       │  Scheduling     │    │  Thread         │    │  Optimization   │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔄 **Error Handling & Resilience**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Service Layer  │───▶│  Error Handler  │───▶│  Fallback       │───▶│  User Feedback  │
│                 │    │                 │    │  Strategy       │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
                       │  Error          │    │  Local          │    │  Toast/Alert    │
                       │  Logging        │    │  Processing     │    │  Display        │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │                    │
                                ▼                        ▼                    ▼
                       ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┘
                       │  Retry          │    │  Graceful       │    │  User           │
                       │  Logic          │    │  Degradation    │    │  Guidance       │
                       └─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📝 **Key Design Principles**

1. **Separation of Concerns**: Each layer has a specific responsibility
2. **Dependency Inversion**: High-level modules depend on abstractions
3. **Single Responsibility**: Each class has one reason to change
4. **Open/Closed**: Open for extension, closed for modification
5. **Interface Segregation**: Small, focused protocols
6. **Liskov Substitution**: Subtypes are substitutable for base types

## 🎯 **Benefits of This Architecture**

- **Testability**: Easy to mock dependencies and test components
- **Maintainability**: Clear separation makes code easier to understand
- **Scalability**: New features can be added without affecting existing code
- **Performance**: Background processing and efficient data management
- **Reliability**: Comprehensive error handling and fallback strategies
- **Security**: Proper permission handling and data protection 
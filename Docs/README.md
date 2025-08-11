# TwinMindAssignment - iOS Audio Recording & Transcription App

## 📱 Project Overview

**TwinMindAssignment** is a comprehensive iOS application built with modern Swift technologies for recording, segmenting, and transcribing audio content. The app demonstrates Clean Architecture principles, SOLID design patterns, and robust testing strategies.

### 🎯 Purpose
- **Audio Recording**: High-quality audio capture with real-time level monitoring
- **Intelligent Segmentation**: Automatic 30-second audio segment creation
- **Cloud Transcription**: API-based speech-to-text conversion with offline fallback
- **Local Fallback**: Apple SFSpeechRecognizer integration for offline transcription
- **Offline Queue**: Robust queue management for network-unavailable scenarios
- **Data Persistence**: SwiftData integration for local storage and management

### 📱 Supported iOS Version
- **Minimum**: iOS 17.0+
- **Target**: iOS 17.0+
- **Architecture**: iOS Simulator & Device (ARM64)

## 🚀 Core Features

### 🎙️ Audio Recording
- Real-time audio level monitoring
- Background audio recording support
- Device route detection and management
- High-quality PCM audio capture

### ✂️ Audio Segmentation
- Configurable segment duration (default: 30 seconds)
- Automatic segment boundary detection
- PCM to M4A conversion with file protection
- Session-based organization

### 🌐 Cloud Transcription
- RESTful API integration with multipart uploads
- Exponential backoff retry strategy
- Authentication via secure token management
- Real-time transcription status updates

### 🔄 Offline Fallback
- Local SFSpeechRecognizer integration
- Automatic fallback after 5+ API failures
- Offline queue management
- Background task processing

### 📊 Data Management
- SwiftData models for sessions and segments
- Repository pattern for data access
- Search and filtering capabilities
- Export functionality (TXT/ZIP)

### 🧪 Testing Infrastructure
- Comprehensive unit, integration, and performance tests
- Deterministic Combine testing with TestScheduler
- Fake implementations for all protocols
- CI/CD integration with GitHub Actions

## 🏗️ Architecture Highlights

- **Clean Architecture**: Clear separation of concerns across layers
- **SOLID Principles**: Protocol-oriented design with dependency injection
- **Combine Framework**: Reactive programming for async operations
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage with Core Data compatibility
- **Background Tasks**: iOS background processing capabilities

## 📋 Quick Start

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ Simulator or Device
- macOS 14.0+ (for development)

### Clone & Build
```bash
# Clone the repository
git clone https://github.com/yourusername/TwinMindAssignment.git
cd TwinMindAssignment

# Open in Xcode
open TwinMindAssignment.xcodeproj

# Build and run
# Select iOS Simulator or Device
# Press Cmd+R to build and run
```

### Configure API Token
1. Open `SettingsView` in the app
2. Enter your transcription API token
3. Test the connection
4. Start recording and transcribing

### Run Tests
```bash
# Run all tests
xcodebuild test -scheme TwinMindAssignment -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test target
xcodebuild test -scheme TwinMindAssignment -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TwinMindAssignmentTests
```

## 📚 Documentation

### 📖 Architecture & Design
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - High-level architecture, Clean Architecture layers, and data flow
- **[FEATURES.md](FEATURES.md)** - Detailed feature documentation with sequence diagrams
- **[API_CONTRACTS.md](API_CONTRACTS.md)** - Backend API specifications and error handling

### 🧪 Testing & Quality
- **[TESTING.md](TESTING.md)** - Testing strategy, coverage, and deterministic testing
- **[CI_CD.md](CI_CD.md)** - Continuous integration, deployment, and code quality

### 🔒 Security & Privacy
- **[PRIVACY_SECURITY.md](PRIVACY_SECURITY.md)** - Permissions, encryption, and compliance
- **[RUNBOOK_BGTasks.md](RUNBOOK_BGTasks.md)** - Background task testing and debugging

### 📝 Development & Maintenance
- **[KNOWN_ISSUES.md](KNOWN_ISSUES.md)** - Current limitations and known bugs
- **[ASSUMPTIONS.md](ASSUMPTIONS.md)** - Design decisions and implementation assumptions

## 🏗️ Project Structure

```
TwinMindAssignment/
├── Sources/
│   ├── Core/
│   │   ├── Segments/          # Audio segmentation logic
│   │   ├── Network/           # API client and networking
│   │   └── Orchestration/     # Workflow coordination
│   └── Features/
│       ├── Recording/         # Audio recording UI
│       ├── Sessions/          # Session management
│       └── Utilities/         # Analytics, logging, export
├── TwinMindAssignmentTests/
│   ├── Unit/                  # Unit tests
│   ├── Integration/           # Integration tests
│   ├── Performance/           # Performance tests
│   └── Support/               # Test utilities and fakes
└── Configuration/
    ├── .swiftlint.yml         # Code quality rules
    └── xcschemes/             # Build and test schemes
```

## 🔧 Development Tools

### Code Quality
- **SwiftLint**: Automated code style enforcement
- **Custom Rules**: Bans `DispatchQueue.main.asyncAfter` in favor of environment scheduler

### Testing
- **TestScheduler**: Deterministic Combine testing
- **CombineExpectations**: Publisher testing utilities
- **Fake Implementations**: Protocol-based test doubles

### CI/CD
- **CombineDeterministic Scheme**: CoreData concurrency debugging
- **GitHub Actions**: Automated testing and deployment
- **Performance Baselines**: Measurable performance requirements

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the established architecture patterns
4. Add comprehensive tests
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is proprietary software. All rights reserved.

## 🆘 Support

For technical questions or issues:
1. Check the documentation in the `Docs/` folder
2. Review existing issues in the GitHub repository
3. Create a new issue with detailed information

---

**Built with ❤️ using SwiftUI, Combine, and Clean Architecture** 
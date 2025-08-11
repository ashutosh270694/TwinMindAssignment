# Device Test Checklist

## Overview

This document provides a comprehensive checklist for testing the TwinMind Assignment app on physical iOS devices. These tests validate the device-ready features and ensure proper functionality in real-world conditions.

## Prerequisites

### Device Requirements
- **iOS Version**: iOS 17.0 or later
- **Device Type**: iPhone or iPad with microphone
- **Storage**: At least 1GB free space
- **Network**: Wi-Fi or cellular connection for API testing

### Test Environment
- **Whisper API Key**: Valid OpenAI API key for transcription testing
- **Test Audio**: Sample audio files for testing (optional)
- **Network Conditions**: Ability to toggle Airplane Mode

## Test Categories

### S3: SwiftData Persistence Tests

#### Basic Persistence
- [ ] **Launch App**: App launches without errors
- [ ] **Create Session**: Create a new recording session
- [ ] **Kill App**: Force-quit the app completely
- [ ] **Relaunch**: App relaunches and shows previous session
- [ ] **Data Integrity**: Session data is preserved correctly

#### Large Dataset Performance
- [ ] **Create Multiple Sessions**: Create 10+ recording sessions
- [ ] **Add Segments**: Add 50+ transcript segments to a session
- [ ] **Smooth Scrolling**: Sessions list scrolls smoothly
- [ ] **Memory Usage**: Check memory usage in Xcode Debug Navigator
- [ ] **Performance**: No lag when navigating between sessions

#### Data Recovery
- [ ] **Simulate Crash**: Force app crash during recording
- [ ] **Relaunch**: Verify data recovery after crash
- [ ] **Partial Data**: Check if partial recordings are preserved

### S4: Live Transcription & API Integration

#### API Key Management
- [ ] **Settings Access**: Navigate to Settings view
- [ ] **Enter API Key**: Paste valid Whisper API key
- [ ] **Save Key**: Key is saved successfully
- [ ] **Key Persistence**: Key remains after app restart
- [ ] **Invalid Key**: Test with invalid key (should show error)

#### Live Transcription
- [ ] **Start Recording**: Begin recording audio
- [ ] **Record Duration**: Record for 35+ seconds
- [ ] **Segment Creation**: Verify audio segments are created
- [ ] **API Call**: Check network requests in Console
- [ ] **Transcript Display**: Verify transcript appears in UI
- [ ] **Quality Check**: Transcript accuracy and formatting

#### Network Handling
- [ ] **Airplane Mode**: Toggle Airplane Mode during recording
- [ ] **Offline Queue**: Segments marked as offline
- [ ] **Network Restore**: Turn off Airplane Mode
- [ ] **Queue Processing**: Offline segments are processed
- [ ] **Error Handling**: Network errors are handled gracefully

### S5: Orchestrator & Background Tasks

#### Concurrency Testing
- [ ] **Multiple Segments**: Create multiple pending segments
- [ ] **Concurrent Uploads**: Verify max 3 concurrent uploads
- [ ] **Queue Management**: Check queue status updates
- [ ] **Progress Tracking**: Monitor upload progress in UI

#### Offline Functionality
- [ ] **Force Offline**: Use diagnostics to force offline mode
- [ ] **Segment Queuing**: Segments marked as offline
- [ ] **Background Task**: Schedule background processing
- [ ] **Queue Drain**: Verify offline queue is processed

#### Fallback Mechanism
- [ ] **Simulate Failures**: Use diagnostics to simulate 5 failures
- [ ] **Local Fallback**: Verify SFSpeechRecognizer is used
- [ ] **Fallback Quality**: Check fallback transcript quality
- [ ] **Status Updates**: Verify segment status changes

#### Background Tasks
- [ ] **Task Registration**: Background tasks are registered
- [ ] **Task Execution**: Background tasks execute properly
- [ ] **Task Expiration**: Handle task expiration gracefully
- [ ] **Task Scheduling**: Verify task scheduling works

### S6: UI Polish & User Experience

#### Recording Interface
- [ ] **Audio Level**: Audio level meter displays correctly
- [ ] **Route Detection**: Audio route is detected and displayed
- [ ] **Interruption Handling**: Audio interruptions are handled
- [ ] **Resume Functionality**: Recording resumes after interruption

#### Session Management
- [ ] **Session List**: Sessions are displayed correctly
- [ ] **Status Chips**: Segment status chips show correct states
- [ ] **Progress Indicators**: Upload progress is visible
- [ ] **Error Display**: Errors are shown clearly to user

#### Navigation & Accessibility
- [ ] **Navigation Flow**: App navigation is intuitive
- [ ] **VoiceOver**: VoiceOver labels are descriptive
- [ ] **Dynamic Type**: Text scales with system settings
- [ ] **Layout Stability**: No layout jumps during state changes

### S7: Security & Privacy

#### File Protection
- [ ] **Audio Files**: Check file protection attributes
- [ ] **Database**: Verify SwiftData encryption
- [ ] **Keychain**: API keys stored securely
- [ ] **Log Sanitization**: No sensitive data in logs

#### Permission Handling
- [ ] **Microphone**: Permission request appears
- [ ] **Speech Recognition**: Permission request appears
- [ ] **Permission Denial**: App handles denied permissions
- [ ] **Settings Integration**: Permissions can be changed in Settings

#### Network Security
- [ ] **HTTPS Only**: All requests use HTTPS
- [ ] **ATS Compliance**: App Transport Security is enforced
- [ ] **Certificate Validation**: SSL certificates are validated

### S8: Diagnostics & Debugging

#### Diagnostics Access
- [ ] **DEBUG Build**: Diagnostics view is accessible
- [ ] **Toggle Functionality**: All toggles work correctly
- **Force Offline**: Simulates network offline state
- **Disable BGTasks**: Disables background task processing
- **Simulate Failures**: Triggers failure simulation
- **Local Fallback Only**: Forces local transcription only

#### Debug Actions
- [ ] **Trigger BGTask**: Manually triggers background task
- [ ] **Wipe Database**: Clears all app data
- [ ] **Export Logs**: Exports diagnostic logs to Documents

#### System Monitoring
- [ ] **Permission Status**: Shows current permission states
- [ ] **Audio Route**: Displays current audio routing
- [ ] **Disk Space**: Shows available storage
- [ ] **Queue Status**: Real-time queue monitoring
- [ ] **Event Log**: Recent orchestrator events

### S9: Device Smoke Tests

#### Basic Functionality
- [ ] **App Launch**: App launches successfully
- [ ] **Permission Alerts**: Handle permission requests
- [ ] **Recording Flow**: Complete recording workflow
- [ ] **Navigation**: Navigate between main views
- [ ] **Settings Access**: Access and modify settings

#### Performance Testing
- [ ] **Launch Performance**: Measure app launch time
- [ ] **Memory Usage**: Monitor memory consumption
- [ ] **Battery Impact**: Check battery usage
- [ ] **Thermal Performance**: Monitor device temperature

### S10: Configuration Validation

#### Build Configuration
- [ ] **Deployment Target**: iOS 17.0+ requirement
- [ ] **Framework Linking**: Required frameworks are linked
- [ ] **Capabilities**: Background modes are enabled
- [ ] **Entitlements**: Proper entitlements are configured

#### Info.plist Validation
- [ ] **Usage Descriptions**: Required descriptions are present
- [ ] **Background Modes**: Audio, processing, fetch modes
- [ ] **ATS Settings**: App Transport Security configuration
- [ ] **Version Info**: App version and build number

## Test Execution

### Test Order
1. **Basic Setup**: Verify app launches and permissions
2. **Core Features**: Test recording and transcription
3. **Advanced Features**: Test offline functionality and fallbacks
4. **UI/UX**: Verify interface polish and accessibility
5. **Security**: Validate security measures
6. **Performance**: Test with large datasets
7. **Edge Cases**: Test error conditions and recovery

### Test Duration
- **Basic Tests**: 30-45 minutes
- **Full Test Suite**: 2-3 hours
- **Performance Testing**: Additional 1-2 hours
- **Edge Case Testing**: 1-2 hours

### Success Criteria
- [ ] All critical features work correctly
- [ ] No crashes or data loss
- [ ] Performance meets requirements
- [ ] Security measures are effective
- [ ] User experience is smooth and intuitive

## Troubleshooting

### Common Issues
- **Permission Denied**: Check device settings
- **Network Errors**: Verify API key and network connectivity
- **Performance Issues**: Check device storage and memory
- **Crash Issues**: Review crash logs and device logs

### Debug Information
- **Console Logs**: Use Xcode Console for detailed logging
- **Device Logs**: Check device logs in Xcode Devices window
- **Network Inspector**: Monitor network requests
- **Memory Debugger**: Check memory usage and leaks

### Support Resources
- **Documentation**: Refer to README.md and other docs
- **GitHub Issues**: Report bugs and issues
- **Development Team**: Contact for technical support

## Test Report Template

### Test Summary
- **Device**: [Device model and iOS version]
- **Test Date**: [Date of testing]
- **Test Duration**: [Total time spent]
- **Overall Result**: [Pass/Fail/Partial]

### Feature Results
- **S3 SwiftData**: [Status and notes]
- **S4 Transcription**: [Status and notes]
- **S5 Orchestrator**: [Status and notes]
- **S6 UI Polish**: [Status and notes]
- **S7 Security**: [Status and notes]
- **S8 Diagnostics**: [Status and notes]
- **S9 Smoke Tests**: [Status and notes]
- **S10 Configuration**: [Status and notes]

### Issues Found
- **Critical**: [List critical issues]
- **Major**: [List major issues]
- **Minor**: [List minor issues]
- **Cosmetic**: [List cosmetic issues]

### Recommendations
- **Immediate Actions**: [Required fixes]
- **Future Improvements**: [Enhancement suggestions]
- **Testing Improvements**: [Test process improvements]

---

**Last Updated**: December 2024
**Version**: 1.0
**Maintainer**: Development Team 
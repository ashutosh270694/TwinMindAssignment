# Privacy & Security

## Overview

This document outlines the privacy and security measures implemented in the TwinMind Assignment app to protect user data and ensure compliance with privacy regulations.

## Data Collection & Usage

### Audio Recording
- **Purpose**: Audio recording is used solely for transcription and analysis purposes
- **Storage**: Audio files are stored locally on the device with complete file protection
- **Transmission**: Audio segments are sent to OpenAI Whisper API for transcription only
- **Retention**: Audio files are retained locally until manually deleted by the user

### Transcription Data
- **Source**: Generated from audio recordings using OpenAI Whisper API
- **Storage**: Stored locally using SwiftData with encryption
- **Usage**: Used for display and search within the app
- **Sharing**: Not shared with third parties except OpenAI for transcription

### User Preferences
- **API Keys**: Stored securely in iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`
- **Settings**: Stored locally on device
- **Analytics**: No analytics or tracking data is collected

## Security Measures

### File Protection
- All audio files use `FileProtectionType.complete` encryption
- Files are only accessible when the device is unlocked
- Automatic encryption/decryption handled by iOS

### Network Security
- **HTTPS Only**: All network requests use HTTPS (TLS 1.2+)
- **API Endpoints**: Only communicates with OpenAI Whisper API
- **No HTTP**: App Transport Security (ATS) blocks all HTTP connections
- **Certificate Pinning**: Not implemented (relies on iOS system trust)

### Authentication
- **API Keys**: Stored in iOS Keychain with restricted access
- **No User Accounts**: App does not require user registration or login
- **Local Only**: All data remains on the device

### Data Encryption
- **SwiftData**: Uses iOS system encryption for database storage
- **Keychain**: Secure storage for sensitive data like API keys
- **File System**: Audio files encrypted using iOS file protection

## Privacy Features

### Permission Management
- **Microphone**: Explicit permission required for audio recording
- **Speech Recognition**: Permission required for local transcription fallback
- **Granular Control**: Users can revoke permissions at any time via iOS Settings

### Data Minimization
- **Local Processing**: Audio processing happens on-device when possible
- **Selective Upload**: Only audio segments are uploaded, not full recordings
- **No Metadata**: Minimal metadata collected (timestamps, duration)

### User Control
- **Data Export**: Users can export their transcription data
- **Data Deletion**: Users can delete individual recordings or all data
- **Settings Control**: Users control API key usage and local fallback

## Third-Party Services

### OpenAI Whisper API
- **Purpose**: Audio transcription service
- **Data Sent**: Audio segments only (no metadata)
- **Privacy Policy**: [OpenAI Privacy Policy](https://openai.com/privacy)
- **Data Retention**: Subject to OpenAI's data retention policies
- **No Training**: Audio data is not used for model training

## Compliance

### GDPR Compliance
- **Right to Access**: Users can export their data
- **Right to Erasure**: Users can delete their data
- **Data Portability**: Data export functionality provided
- **Consent**: Explicit permission required for data collection

### CCPA Compliance
- **Right to Know**: Users can see what data is collected
- **Right to Delete**: Users can delete their data
- **Right to Opt-Out**: Users can disable features that collect data

### COPPA Compliance
- **Age Verification**: App is not intended for children under 13
- **Parental Consent**: Not applicable (no child-directed content)

## Data Breach Response

### Incident Response Plan
1. **Detection**: Monitor for unusual network activity or data access
2. **Assessment**: Evaluate scope and impact of potential breach
3. **Notification**: Notify users within 72 hours if required
4. **Mitigation**: Implement additional security measures
5. **Recovery**: Restore secure state and monitor for recurrence

### User Notification
- **Timeline**: Within 72 hours of breach discovery
- **Method**: In-app notification and email if available
- **Content**: Description of breach, affected data, and mitigation steps

## Security Audits

### Regular Reviews
- **Code Review**: All code changes reviewed for security issues
- **Dependency Updates**: Regular updates of third-party dependencies
- **Penetration Testing**: Annual security assessment
- **Compliance Checks**: Regular privacy and security compliance reviews

### Vulnerability Management
- **Reporting**: Security issues can be reported via GitHub Issues
- **Response Time**: Critical issues addressed within 24 hours
- **Disclosure**: Security updates disclosed to users via app updates

## Contact Information

### Security Issues
- **GitHub Issues**: [Security Issues](https://github.com/your-repo/issues)
- **Email**: security@yourdomain.com (for sensitive reports)

### Privacy Questions
- **Email**: privacy@yourdomain.com
- **Support**: In-app support or GitHub Issues

## Updates

This privacy and security policy is reviewed and updated regularly. Users will be notified of significant changes via app updates.

**Last Updated**: December 2024
**Version**: 1.0 
import SwiftUI

/// A reusable chip component for displaying status information
struct StatusChip: View {
    
    // MARK: - Properties
    
    let title: String
    let status: ChipStatus
    let size: ChipSize
    
    // MARK: - Initialization
    
    init(
        title: String,
        status: ChipStatus = .neutral,
        size: ChipSize = .medium
    ) {
        self.title = title
        self.status = status
        self.size = size
    }
    
    // MARK: - Body
    
    var body: some View {
        Text(title)
            .font(size.font)
            .fontWeight(.medium)
            .foregroundColor(status.textColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .fill(status.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius)
                    .stroke(status.borderColor, lineWidth: status.borderWidth)
            )
    }
}

// MARK: - Chip Status

enum ChipStatus {
    case success
    case warning
    case error
    case info
    case neutral
    case offline
    case online
    
    var backgroundColor: Color {
        switch self {
        case .success:
            return Color.green.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .info:
            return Color.blue.opacity(0.1)
        case .neutral:
            return Color.gray.opacity(0.1)
        case .offline:
            return Color.gray.opacity(0.1)
        case .online:
            return Color.green.opacity(0.1)
        }
    }
    
    var textColor: Color {
        switch self {
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .info:
            return .blue
        case .neutral:
            return .primary
        case .offline:
            return .secondary
        case .online:
            return .green
        }
    }
    
    var borderColor: Color {
        switch self {
        case .success:
            return .green.opacity(0.3)
        case .warning:
            return .orange.opacity(0.3)
        case .error:
            return .red.opacity(0.3)
        case .info:
            return .blue.opacity(0.3)
        case .neutral:
            return .gray.opacity(0.3)
        case .offline:
            return .gray.opacity(0.3)
        case .online:
            return .green.opacity(0.3)
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .success, .warning, .error, .info:
            return 1.0
        case .neutral, .offline, .online:
            return 0.5
        }
    }
}

// MARK: - Chip Size

enum ChipSize {
    case small
    case medium
    case large
    
    var font: Font {
        switch self {
        case .small:
            return .caption2
        case .medium:
            return .caption
        case .large:
            return .body
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 6
        case .medium:
            return 8
        case .large:
            return 12
        }
    }
    
    var verticalPadding: CGFloat {
        switch self {
        case .small:
            return 2
        case .medium:
            return 4
        case .large:
            return 6
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 12
        case .large:
            return 16
        }
    }
}

// MARK: - Convenience Initializers

extension StatusChip {
    
    /// Creates a status chip for segment status
    /// - Parameter segmentStatus: The segment status to display
    /// - Returns: Configured StatusChip
    static func forSegmentStatus(_ segmentStatus: SegmentStatus) -> StatusChip {
        let (title, status) = segmentStatus.chipConfiguration
        return StatusChip(title: title, status: status)
    }
    
    /// Creates a network status chip
    /// - Parameter isOnline: Whether the network is online
    /// - Returns: Configured StatusChip
    static func forNetworkStatus(isOnline: Bool) -> StatusChip {
        if isOnline {
            return StatusChip(title: "Online", status: .online)
        } else {
            return StatusChip(title: "Offline", status: .offline)
        }
    }
    
    /// Creates a recording status chip
    /// - Parameter isRecording: Whether recording is active
    /// - Returns: Configured StatusChip
    static func forRecordingStatus(isRecording: Bool) -> StatusChip {
        if isRecording {
            return StatusChip(title: "Recording", status: .error)
        } else {
            return StatusChip(title: "Stopped", status: .neutral)
        }
    }
}

// MARK: - SegmentStatus Extension

extension SegmentStatus {
    
    /// Returns the chip configuration for this segment status
    var chipConfiguration: (title: String, status: ChipStatus) {
        switch self {
        case .pending:
            return ("Pending", .info)
        case .uploading:
            return ("Uploading", .warning)
        case .transcribed:
            return ("Transcribed", .success)
        case .failed:
            return ("Failed", .error)
        case .queuedOffline:
            return ("Offline", .neutral)
        }
    }
}

// MARK: - Preview

struct StatusChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                StatusChip(title: "Success", status: .success)
                StatusChip(title: "Warning", status: .warning)
                StatusChip(title: "Error", status: .error)
            }
            
            HStack(spacing: 10) {
                StatusChip(title: "Info", status: .info)
                StatusChip(title: "Neutral", status: .neutral)
                StatusChip(title: "Online", status: .online)
            }
            
            HStack(spacing: 10) {
                StatusChip(title: "Small", status: .info, size: .small)
                StatusChip(title: "Medium", status: .info, size: .medium)
                StatusChip(title: "Large", status: .info, size: .large)
            }
            
            HStack(spacing: 10) {
                StatusChip.forSegmentStatus(.pending)
                StatusChip.forSegmentStatus(.transcribed)
                StatusChip.forSegmentStatus(.failed)
            }
            
            HStack(spacing: 10) {
                StatusChip.forNetworkStatus(isOnline: true)
                StatusChip.forNetworkStatus(isOnline: false)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 
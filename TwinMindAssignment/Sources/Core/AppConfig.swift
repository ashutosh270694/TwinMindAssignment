import Foundation

struct AppConfig {
    static var debugSegmentDuration: TimeInterval? = {
        #if DEBUG
        return 10
        #else
        return nil
        #endif
    }()
} 
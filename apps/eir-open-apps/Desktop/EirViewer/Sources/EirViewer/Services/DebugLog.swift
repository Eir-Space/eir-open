import Foundation
import os

/// File + os.Logger based debug logging for diagnosing agent loop issues
enum DebugLog {
    private static let logger = Logger(subsystem: "com.eir.viewer", category: "AgentLoop")
    private static let logFileURL: URL = {
        let url = URL(fileURLWithPath: "/tmp/eirviewer-debug.log")
        // Clear on launch
        try? "".write(to: url, atomically: true, encoding: .utf8)
        return url
    }()

    static func log(_ message: String) {
        let timestamped = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)"
        logger.info("\(timestamped)")
        // Also append to file for easy terminal access
        if let data = (timestamped + "\n").data(using: .utf8),
           let handle = try? FileHandle(forWritingTo: logFileURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    }
}

import Foundation
import os

/// Logs all network activity from the 1177 health data browser to a file for analysis.
/// Log file: /tmp/eirviewer-network.log
actor NetworkLogger {
    static let shared = NetworkLogger()

    private let logger = Logger(subsystem: "com.eir.viewer", category: "Network")
    private let logFileURL: URL = URL(fileURLWithPath: "/tmp/eirviewer-network.log")
    private var entries: [LogEntry] = []

    struct LogEntry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let type: String        // "NAV", "XHR", "FETCH", "COOKIE", "REDIRECT", "RESPONSE", "PAGE"
        let method: String
        let url: String
        let status: Int?
        let headers: [String: String]?
        let body: String?
        let detail: String?

        var summary: String {
            let ts = Self.timeFormatter.string(from: timestamp)
            let statusStr = status.map { " [\($0)]" } ?? ""
            return "[\(ts)] \(type) \(method) \(url)\(statusStr)"
        }

        private static let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()
    }

    func log(
        type: String,
        method: String = "GET",
        url: String,
        status: Int? = nil,
        headers: [String: String]? = nil,
        body: String? = nil,
        detail: String? = nil
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            type: type,
            method: method,
            url: url,
            status: status,
            headers: headers,
            body: body,
            detail: detail
        )
        entries.append(entry)

        // Write to file
        var line = entry.summary
        if let detail = detail { line += " | \(detail)" }
        if let headers = headers, !headers.isEmpty {
            let headerStr = headers.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
            line += "\n  Headers:\n\(headerStr)"
        }
        if let body = body, !body.isEmpty {
            let preview = body.prefix(2000)
            line += "\n  Body: \(preview)"
            if body.count > 2000 { line += "... (\(body.count) chars total)" }
        }
        line += "\n"

        writeToFile(line)
        logger.info("\(entry.summary)")
    }

    func getEntries() -> [LogEntry] {
        return entries
    }

    func clear() {
        entries.removeAll()
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    func getRecentEntries(last n: Int = 50) -> [LogEntry] {
        return Array(entries.suffix(n))
    }

    /// Get all entries matching a URL pattern
    func search(urlContaining pattern: String) -> [LogEntry] {
        return entries.filter { $0.url.localizedCaseInsensitiveContains(pattern) }
    }

    /// Get summary statistics
    func stats() -> String {
        let byType = Dictionary(grouping: entries, by: { $0.type })
        var lines: [String] = ["=== Network Log Stats ===", "Total requests: \(entries.count)"]
        for (type, entries) in byType.sorted(by: { $0.key < $1.key }) {
            lines.append("  \(type): \(entries.count)")
        }

        // Unique domains
        let domains = Set(entries.compactMap { URL(string: $0.url)?.host })
        lines.append("Unique domains: \(domains.count)")
        for domain in domains.sorted() {
            let count = entries.filter { $0.url.contains(domain) }.count
            lines.append("  \(domain): \(count)")
        }

        return lines.joined(separator: "\n")
    }

    private func writeToFile(_ text: String) {
        let data = text.data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logFileURL)
        }
    }
}

import Foundation
import Yams

enum EirParserError: LocalizedError {
    case fileNotFound(String)
    case invalidYAML(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidYAML(let detail):
            return "Invalid YAML: \(detail)"
        case .decodingFailed(let detail):
            return "Failed to decode EIR document: \(detail)"
        }
    }
}

struct EirParser {
    static func parse(url: URL) throws -> EirDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw EirParserError.fileNotFound(url.path)
        }

        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw EirParserError.invalidYAML("Could not read file as UTF-8")
        }

        return try parse(yaml: yamlString)
    }

    static func parse(yaml: String) throws -> EirDocument {
        let fixed = fixMalformedYAML(yaml)
        let decoder = YAMLDecoder()
        do {
            return try decoder.decode(EirDocument.self, from: fixed)
        } catch {
            throw EirParserError.decodingFailed(error.localizedDescription)
        }
    }

    /// Fixes malformed YAML produced by the chrome extension's convertToYAML().
    ///
    /// Known issues in exported files:
    ///
    /// **Pattern A** — dash at indent 0, fields at indent 2:
    /// ```
    /// entries:
    /// -     id: "..."
    ///   date: "..."
    ///   provider:
    ///     name: "..."
    /// ```
    ///
    /// **Pattern B** — dash at indent 2 with extra spaces, fields at indent 4:
    /// ```
    /// entries:
    ///   -     id: "..."
    ///     date: "..."
    ///     attachments:
    /// []
    /// ```
    ///
    /// Both are rewritten to valid YAML with `  - id:` at indent 2 and fields at indent 4.
    static func fixMalformedYAML(_ yaml: String) -> String {
        var lines = yaml.components(separatedBy: "\n")

        // Fix unescaped quotes inside double-quoted strings (e.g. notes with embedded "word")
        lines = lines.map { escapeEmbeddedQuotes(in: $0) }

        // Quick check: well-formed entries have "  - id:" pattern
        let hasWellFormedEntries = lines.contains { $0.hasPrefix("  - id:") }
        let hasStandaloneBrackets = lines.contains { $0.trimmingCharacters(in: .whitespaces) == "[]" }

        // If well-formed and no standalone [], nothing to fix
        if hasWellFormedEntries && !hasStandaloneBrackets {
            return lines.joined(separator: "\n")
        }

        // Detect malformed entry starts (dash with extra spaces before id)
        let firstEntryLine = lines.first {
            let s = $0.trimmingCharacters(in: .whitespaces)
            return s.hasPrefix("-") && s.contains("id:")
        }
        guard hasStandaloneBrackets || firstEntryLine != nil else {
            return lines.joined(separator: "\n")
        }

        // Determine the pattern by checking the dash's indent level
        let dashIndent = firstEntryLine.map { $0.prefix(while: { $0 == " " }).count } ?? 2
        let isPatternA = dashIndent == 0 // dash at indent 0, needs full re-indent

        var result: [String] = []
        var inEntries = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "entries:" {
                inEntries = true
                result.append(line)
                continue
            }

            guard inEntries else {
                result.append(line)
                continue
            }

            let stripped = line.trimmingCharacters(in: .whitespaces)

            // If we hit a top-level key (no leading spaces, has colon, not [] or -), we left entries
            if !line.hasPrefix(" ") && !line.hasPrefix("-") && stripped.contains(":") && !stripped.isEmpty {
                inEntries = false
                result.append(line)
                continue
            }

            // Fix standalone [] → merge with previous line as empty array
            if stripped == "[]" && !result.isEmpty {
                let prevLine = result[result.count - 1]
                if prevLine.trimmingCharacters(in: .whitespaces).hasSuffix(":") {
                    result[result.count - 1] = "\(prevLine) []"
                    continue
                }
            }

            let leadingSpaces = line.prefix(while: { $0 == " " }).count

            // Entry start: fix extra spaces after dash
            if stripped.hasPrefix("-") && !stripped.hasPrefix("- \"") && !stripped.hasPrefix("- '") {
                let afterDash = String(stripped.dropFirst()).trimmingCharacters(in: .whitespaces)
                if afterDash.contains(":") && !afterDash.hasPrefix("\"") {
                    result.append("  - \(afterDash)")
                    continue
                }
            }

            if isPatternA {
                // Pattern A: shift everything by +2 to put fields under the list item

                // Array items under entry fields (e.g. tags or notes)
                if leadingSpaces >= 4 && stripped.hasPrefix("- ") {
                    result.append("        \(stripped)")
                    continue
                }

                // Entry-level fields at indent 2
                if leadingSpaces == 2 && !stripped.hasPrefix("-") && !stripped.isEmpty {
                    result.append("    \(stripped)")
                    continue
                }

                // Sub-fields at indent 4
                if leadingSpaces == 4 && !stripped.hasPrefix("-") && !stripped.isEmpty {
                    result.append("      \(stripped)")
                    continue
                }

                // Sub-sub-fields at indent 6
                if leadingSpaces == 6 && !stripped.hasPrefix("-") && !stripped.isEmpty {
                    result.append("        \(stripped)")
                    continue
                }
            }

            // Pattern B: indentation is already correct, pass through
            result.append(line)
        }

        return result.joined(separator: "\n")
    }

    /// Fixes unescaped double quotes inside double-quoted YAML strings.
    /// Example: `- "text with "word" inside"` → `- "text with \"word\" inside"`
    /// Skips lines where quotes are already properly escaped (contain `\"`).
    private static func escapeEmbeddedQuotes(in line: String) -> String {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        let leading = String(line.prefix(while: { $0 == " " }))

        // Array item: `- "content with "embedded" quotes"`
        if stripped.hasPrefix("- \"") && stripped.hasSuffix("\"") && stripped.count > 4 {
            let content = String(stripped.dropFirst(3).dropLast(1))
            // Skip if quotes are already escaped (content contains \")
            if content.contains("\\\"") { return line }
            if content.contains("\"") {
                let escaped = content.replacingOccurrences(of: "\"", with: "\\\"")
                return "\(leading)- \"\(escaped)\""
            }
        }

        // Scalar value: `key: "content with "embedded" quotes"`
        if let range = stripped.range(of: ": \""), stripped.hasSuffix("\"") {
            let key = String(stripped[stripped.startIndex..<range.lowerBound])
            // Only fix if key looks like a simple YAML key (no quotes, no special chars)
            guard !key.contains("\"") else { return line }
            let valueStart = stripped.index(range.upperBound, offsetBy: 0)
            let valueEnd = stripped.index(before: stripped.endIndex)
            guard valueStart < valueEnd else { return line }
            let content = String(stripped[valueStart..<valueEnd])
            // Skip if quotes are already escaped (content contains \")
            if content.contains("\\\"") { return line }
            if content.contains("\"") {
                let escaped = content.replacingOccurrences(of: "\"", with: "\\\"")
                return "\(leading)\(key): \"\(escaped)\""
            }
        }

        return line
    }
}

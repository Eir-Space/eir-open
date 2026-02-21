import XCTest
import Yams
@testable import EirViewer

final class EirParserTests: XCTestCase {

    // MARK: - Real file tests

    private let testFiles: [(name: String, path: String, minEntries: Int)] = [
        ("birk_journal", "/Users/birger/Journal_content/birk_journal.eir", 100),
        ("hedda_journal", "/Users/birger/Journal_content/hedda_journal.eir", 50),
        ("journal-content", "/Users/birger/Journal_content/journal-content.eir", 20),
        ("journal-content (1)", "/Users/birger/Journal_content/journal-content (1).eir", 1),
    ]

    func testParseRealFiles() throws {
        for file in testFiles {
            let url = URL(fileURLWithPath: file.path)
            guard FileManager.default.fileExists(atPath: file.path) else {
                print("⚠ Skipping \(file.name): file not found at \(file.path)")
                continue
            }

            // Write fixed YAML for debugging on failure
            let rawYaml = try String(contentsOf: url, encoding: .utf8)
            let fixedYaml = EirParser.fixMalformedYAML(rawYaml)

            let doc: EirDocument
            do {
                doc = try EirParser.parse(url: url)
            } catch {
                // Write fixed YAML to temp for inspection
                let debugPath = "/tmp/eirtest_\(file.name)_fixed.yaml"
                try? fixedYaml.write(toFile: debugPath, atomically: true, encoding: .utf8)

                // Try to get the underlying Yams error
                let rawError: String
                do {
                    let decoder = YAMLDecoder()
                    _ = try decoder.decode(EirDocument.self, from: fixedYaml)
                    rawError = "unknown"
                } catch let yamsError {
                    rawError = "\(yamsError)"
                }
                XCTFail("\(file.name): parse failed — \(rawError)\nFixed YAML written to \(debugPath)")
                continue
            }

            XCTAssertGreaterThanOrEqual(
                doc.entries.count, file.minEntries,
                "\(file.name): expected at least \(file.minEntries) entries, got \(doc.entries.count)"
            )
            XCTAssertNotNil(doc.metadata.patient?.name, "\(file.name): missing patient name")
            XCTAssertNotNil(doc.metadata.patient?.personalNumber, "\(file.name): missing personal number")

            print("✓ \(file.name): \(doc.entries.count) entries, patient=\(doc.metadata.patient?.name ?? "nil")")
        }
    }

    // MARK: - YAML fixer unit tests

    func testFixStandaloneBrackets() {
        let yaml = """
        metadata:
          format_version: "1.0"
          patient:
            name: "Test"
        entries:
          -     id: "e1"
            date: "2025-01-01"
            category: "Test"
            content:
              summary: "Hello"
            attachments:
        []
            tags:
              - "tag1"
        """

        let fixed = EirParser.fixMalformedYAML(yaml)
        XCTAssertFalse(fixed.contains("\n[]"), "Standalone [] should be merged with previous line")
        XCTAssertTrue(fixed.contains("attachments: []"), "attachments should have inline empty array")
    }

    func testFixExtraSpacesAfterDash() {
        let yaml = """
        metadata:
          format_version: "1.0"
          patient:
            name: "Test"
        entries:
          -     id: "e1"
            date: "2025-01-01"
        """

        let fixed = EirParser.fixMalformedYAML(yaml)
        XCTAssertTrue(fixed.contains("  - id: \"e1\""), "Extra spaces after dash should be compacted")
        XCTAssertFalse(fixed.contains("-     id:"), "Original malformed dash should be gone")
    }

    func testWellFormedYAMLPassesThrough() {
        let yaml = """
        metadata:
          format_version: "1.0"
          patient:
            name: "Test"
        entries:
          - id: "e1"
            date: "2025-01-01"
            attachments: []
        """

        let fixed = EirParser.fixMalformedYAML(yaml)
        XCTAssertEqual(fixed, yaml, "Well-formed YAML should not be modified")
    }

    func testPatternAIndentShift() {
        // Pattern A: dash at indent 0, fields at indent 2
        let yaml = """
        metadata:
          format_version: "1.0"
          patient:
            name: "Test"
        entries:
        -     id: "e1"
          date: "2025-01-01"
          provider:
            name: "Hospital"
          tags:
            - "tag1"
        """

        let fixed = EirParser.fixMalformedYAML(yaml)
        XCTAssertTrue(fixed.contains("  - id: \"e1\""), "Entry start should be at indent 2")
        XCTAssertTrue(fixed.contains("    date:"), "Entry fields should be at indent 4")
        XCTAssertTrue(fixed.contains("      name: \"Hospital\""), "Sub-fields should be at indent 6")
    }

    func testFixEmbeddedQuotes() {
        // Simulate the raw YAML line with unescaped embedded quotes
        let yaml = "  notes:\n    - \"Text with \"embedded\" quotes inside\""
        let fixed = EirParser.fixMalformedYAML(yaml)
        // The embedded quotes should now be escaped with backslash
        XCTAssertTrue(fixed.contains(#"\""#), "Embedded quotes should be escaped")
        XCTAssertFalse(fixed.contains("\"embedded\""), "Unescaped embedded quotes should be gone")
    }

    func testFixEmbeddedQuotesInScalar() {
        let yaml = "details: \"The doctor said \"hello\" to the patient\""
        let fixed = EirParser.fixMalformedYAML(yaml)
        XCTAssertTrue(fixed.contains(#"\"hello\""#), "Embedded quotes in scalar should be escaped")
    }

    func testParsePatternBWithBrackets() throws {
        let yaml = """
        metadata:
          format_version: "1.0"
          created_at: "2026-01-01T00:00:00Z"
          source: "1177.se Journal"
          patient:
            name: "Test Person"
            birth_date: "1990-01-01"
            personal_number: "19900101-1234"
          export_info:
            total_entries: 2
            date_range:
              start: "2025-01-01"
              end: "2025-12-31"
        entries:
          -     id: "entry_001"
            date: "2025-06-15"
            time: "10:00"
            category: "Anteckningar"
            type: "Besöksanteckning"
            provider:
              name: "Test Hospital"
              region: "Region Test"
              location: "Test City"
            status: "Nytt"
            responsible_person:
              name: "Dr. Test"
              role: "Läkare"
            content:
              summary: "Test summary"
              details: "Test details"
              notes:
                - "Test note 1"
            attachments:
        []
            tags:
              - "test"
          -     id: "entry_002"
            date: "2025-07-20"
            category: "Laboratorium"
            content:
              summary: "Lab test"
            attachments:
        []
            tags:
              - "lab"
        """

        let doc = try EirParser.parse(yaml: yaml)
        XCTAssertEqual(doc.entries.count, 2)
        XCTAssertEqual(doc.entries[0].id, "entry_001")
        XCTAssertEqual(doc.entries[0].category, "Anteckningar")
        XCTAssertEqual(doc.entries[0].provider?.name, "Test Hospital")
        XCTAssertEqual(doc.entries[0].content?.notes?.count, 1)
        XCTAssertEqual(doc.entries[0].tags, ["test"])
        XCTAssertEqual(doc.entries[1].id, "entry_002")
        XCTAssertEqual(doc.metadata.patient?.name, "Test Person")
        XCTAssertEqual(doc.metadata.patient?.personalNumber, "19900101-1234")
    }
}

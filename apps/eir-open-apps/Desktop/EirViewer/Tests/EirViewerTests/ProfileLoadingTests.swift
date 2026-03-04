import XCTest
@testable import Eir_Viewer

@MainActor
final class ProfileLoadingTests: XCTestCase {

    // MARK: - Real file parsing

    /// Verify that each real journal file parses successfully and returns expected entry counts
    func testRealFilesParseCorrectly() throws {
        let files: [(path: String, expectedName: String, minEntries: Int)] = [
            ("/Users/birger/Journal_content/journal-content.eir", "Birger Moell", 35),
            ("/Users/birger/Journal_content/birk_journal.eir", "", 131),
            ("/Users/birger/Journal_content/hedda_journal.eir", "", 73),
        ]

        for file in files {
            let url = URL(fileURLWithPath: file.path)
            guard FileManager.default.fileExists(atPath: file.path) else {
                XCTFail("File not found: \(file.path)")
                continue
            }

            do {
                let doc = try EirParser.parse(url: url)
                XCTAssertGreaterThanOrEqual(doc.entries.count, file.minEntries,
                    "Expected >= \(file.minEntries) entries for \(file.path), got \(doc.entries.count)")
                if !file.expectedName.isEmpty {
                    XCTAssertEqual(doc.metadata.patient?.name, file.expectedName)
                }
                print("OK: \(url.lastPathComponent) — \(doc.entries.count) entries")
            } catch {
                XCTFail("Failed to parse \(file.path): \(error)")
            }
        }
    }

    // MARK: - DocumentViewModel loading

    /// Verify DocumentViewModel.loadFile correctly populates entries from real files
    func testDocumentViewModelLoadsRealFiles() throws {
        let vm = DocumentViewModel()

        let url = URL(fileURLWithPath: "/Users/birger/Journal_content/journal-content.eir")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Test file not available")
        }

        vm.loadFile(url: url)

        XCTAssertNil(vm.errorMessage, "loadFile should not produce an error: \(vm.errorMessage ?? "")")
        XCTAssertNotNil(vm.document, "document should be set after loadFile")
        XCTAssertGreaterThanOrEqual(vm.document?.entries.count ?? 0, 35, "Should have >= 35 entries")
        XCTAssertFalse(vm.filteredEntries.isEmpty, "filteredEntries should not be empty")
        XCTAssertFalse(vm.groupedEntries.isEmpty, "groupedEntries should not be empty")
    }

    /// Verify switching documents clears old state and loads new
    func testDocumentViewModelSwitchesFiles() throws {
        let vm = DocumentViewModel()

        let file1 = URL(fileURLWithPath: "/Users/birger/Journal_content/journal-content.eir")
        let file2 = URL(fileURLWithPath: "/Users/birger/Journal_content/birk_journal.eir")
        guard FileManager.default.fileExists(atPath: file1.path),
              FileManager.default.fileExists(atPath: file2.path) else {
            throw XCTSkip("Test files not available")
        }

        vm.loadFile(url: file1)
        let count1 = vm.document?.entries.count ?? 0
        XCTAssertGreaterThan(count1, 0)

        vm.loadFile(url: file2)
        let count2 = vm.document?.entries.count ?? 0
        XCTAssertGreaterThan(count2, 0)
        XCTAssertNotEqual(count1, count2, "Different files should have different entry counts")
        XCTAssertNil(vm.selectedEntryID, "selectedEntryID should be cleared on file switch")
    }

    // MARK: - ProfileStore

    /// Verify ProfileStore can add, select, and retrieve profiles
    func testProfileStoreBasicFlow() throws {
        let url = URL(fileURLWithPath: "/Users/birger/Journal_content/journal-content.eir")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Test file not available")
        }

        let store = ProfileStore()
        // Clear existing for clean test
        let existingCount = store.profiles.count

        let profile = store.addProfile(displayName: "Test Person", fileURL: url)
        XCTAssertNotNil(profile, "addProfile should succeed")
        XCTAssertEqual(store.profiles.count, existingCount + 1)

        if let p = profile {
            store.selectProfile(p.id)
            XCTAssertEqual(store.selectedProfileID, p.id)
            XCTAssertNotNil(store.selectedProfile)
            XCTAssertEqual(store.selectedProfile?.displayName, "Test Person")
            XCTAssertEqual(store.selectedProfile?.fileURL, url)

            // Clean up
            store.removeProfile(p.id)
        }
    }

    // MARK: - Full integration: Profile → Document

    /// Simulate the full flow: select profile → load document → verify entries
    func testProfileToDocumentIntegration() throws {
        let url = URL(fileURLWithPath: "/Users/birger/Journal_content/journal-content.eir")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Test file not available")
        }

        let profileStore = ProfileStore()
        let documentVM = DocumentViewModel()

        // Add and select profile
        guard let profile = profileStore.addProfile(displayName: "Integration Test", fileURL: url) else {
            XCTFail("Failed to add profile")
            return
        }
        profileStore.selectProfile(profile.id)

        // Simulate what ContentView.loadSelectedProfile does
        guard let selected = profileStore.selectedProfile else {
            XCTFail("selectedProfile is nil after selectProfile")
            return
        }
        documentVM.loadFile(url: selected.fileURL)

        // Verify
        XCTAssertNil(documentVM.errorMessage, "Should have no error: \(documentVM.errorMessage ?? "")")
        XCTAssertNotNil(documentVM.document)
        XCTAssertGreaterThanOrEqual(documentVM.filteredEntries.count, 35)

        print("Integration test: \(documentVM.filteredEntries.count) entries loaded for \(selected.displayName)")

        // Clean up
        profileStore.removeProfile(profile.id)
    }

    // MARK: - YAML fixer on real files

    /// Verify the YAML fixer produces valid YAML for all real files
    func testYAMLFixerOnRealFiles() throws {
        let paths = [
            "/Users/birger/Journal_content/journal-content.eir",
            "/Users/birger/Journal_content/birk_journal.eir",
            "/Users/birger/Journal_content/hedda_journal.eir",
        ]

        for path in paths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let raw = try String(contentsOfFile: path, encoding: .utf8)
            let fixed = EirParser.fixMalformedYAML(raw)

            // The fixed YAML should be parseable
            do {
                let doc = try EirParser.parse(yaml: fixed)
                XCTAssertGreaterThan(doc.entries.count, 0, "\(path): should have entries after fixing")
                print("YAML fix OK: \(URL(fileURLWithPath: path).lastPathComponent) — \(doc.entries.count) entries")
            } catch {
                // Write fixed YAML for inspection
                let debugPath = "/tmp/eirtest_\(URL(fileURLWithPath: path).lastPathComponent)_fixed.yaml"
                try? fixed.write(toFile: debugPath, atomically: true, encoding: .utf8)
                XCTFail("\(path): fixed YAML still fails to parse: \(error). Written to \(debugPath)")
            }
        }
    }
}

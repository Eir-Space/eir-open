import XCTest
@testable import EirViewer

/// Tests that simulate the QR code transfer flow end-to-end.
/// This covers: file download → profile creation → document loading → state transitions.
@MainActor
final class QRTransferFlowTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EirViewerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        // Clean up EncryptedStore test data
        EncryptedStore.remove(forKey: "eir_person_profiles")
        EncryptedStore.remove(forKey: "eir_selected_profile_id")
        super.tearDown()
    }

    // MARK: - Sample YAML

    private let sampleYAML = """
    metadata:
      format_version: "1.0"
      created_at: "2025-01-16T17:17:03Z"
      source: "1177.se Journal"
      patient:
        name: "Test Person"
        birth_date: "1990-01-01"
        personal_number: "19900101-1234"
      export_info:
        total_entries: 3
    entries:
      - id: "entry_001"
        date: "2025-03-17"
        category: "Vårdkontakter"
        provider:
          name: "Test Clinic"
          region: "Region Test"
        content:
          summary: "Test visit 1"
          details: "Details for visit 1"
          notes: []
        attachments: []
        tags: []
      - id: "entry_002"
        date: "2025-02-10"
        category: "Provsvar"
        provider:
          name: "Test Lab"
          region: "Region Test"
        content:
          summary: "Test lab result"
          details: "Details for lab"
          notes: []
        attachments: []
        tags: []
      - id: "entry_003"
        date: "2024-12-01"
        category: "Vårdkontakter"
        provider:
          name: "Test Clinic"
          region: "Region Test"
        content:
          summary: "Earlier visit"
          details: "Details for earlier visit"
          notes: []
        attachments: []
        tags: []
    """

    private func writeSampleFile(named name: String = "test-data.eir") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! sampleYAML.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Write sample file directly into the app's Documents directory (simulates QR download)
    private func writeSampleToDocuments(named name: String = "transferred.eir") -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(name)
        try! sampleYAML.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func cleanupDocumentsFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Step 1: EirParser can parse the YAML

    func testParserParsesYAML() throws {
        let doc = try EirParser.parse(yaml: sampleYAML)
        XCTAssertEqual(doc.entries.count, 3, "Should parse 3 entries")
        XCTAssertEqual(doc.metadata.patient?.name, "Test Person")
        XCTAssertEqual(doc.metadata.patient?.personalNumber, "19900101-1234")
        XCTAssertEqual(doc.entries[0].id, "entry_001")
        XCTAssertEqual(doc.entries[0].content?.summary, "Test visit 1")
    }

    func testParserParsesFromFile() throws {
        let fileURL = writeSampleFile()
        let doc = try EirParser.parse(url: fileURL)
        XCTAssertEqual(doc.entries.count, 3, "Should parse 3 entries from file")
        XCTAssertEqual(doc.metadata.patient?.name, "Test Person")
    }

    // MARK: - Step 2: ProfileStore.addProfile creates profile with correct fileName

    func testAddProfileFromDocuments() throws {
        // Simulate: QR transfer downloads file to Documents
        let docsFile = writeSampleToDocuments(named: "qr-transfer-test.eir")
        defer { cleanupDocumentsFile(docsFile) }

        let store = ProfileStore()
        // Clear any existing state
        store.profiles = []

        let profile = store.addProfile(displayName: "", fileURL: docsFile)
        XCTAssertNotNil(profile, "addProfile should return a profile")
        XCTAssertEqual(profile?.fileName, "qr-transfer-test.eir",
                       "fileName should be just the filename, not full path")
        XCTAssertEqual(profile?.displayName, "Test Person",
                       "Should use patient name when displayName is empty")
        XCTAssertEqual(profile?.totalEntries, 3)
        XCTAssertEqual(profile?.patientName, "Test Person")
        XCTAssertEqual(profile?.personalNumber, "19900101-1234")
        XCTAssertNil(store.errorMessage, "Should have no error: \(store.errorMessage ?? "")")
    }

    func testAddProfileFromOutsideDocuments() throws {
        // Simulate: file picked from outside Documents (e.g. fileImporter)
        let externalFile = writeSampleFile(named: "external-file.eir")

        let store = ProfileStore()
        store.profiles = []

        let profile = store.addProfile(displayName: "Custom Name", fileURL: externalFile)
        XCTAssertNotNil(profile, "addProfile should return a profile")
        XCTAssertEqual(profile?.displayName, "Custom Name")

        // File should have been COPIED to Documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let copiedFile = docs.appendingPathComponent(profile!.fileName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedFile.path),
                      "File should exist in Documents at: \(copiedFile.path)")

        // Clean up
        cleanupDocumentsFile(copiedFile)
    }

    // MARK: - Step 3: Profile.fileURL resolves correctly

    func testProfileFileURLResolvesToDocuments() {
        let profile = PersonProfile(
            id: UUID(),
            displayName: "Test",
            fileName: "my-records.eir",
            patientName: nil,
            personalNumber: nil,
            birthDate: nil,
            totalEntries: nil,
            addedAt: Date()
        )

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let expected = docs.appendingPathComponent("my-records.eir")
        XCTAssertEqual(profile.fileURL, expected,
                       "fileURL should resolve to current Documents directory")
    }

    // MARK: - Step 4: Profile encoding/decoding preserves fileName

    func testProfileEncodingDecoding() throws {
        let original = PersonProfile(
            id: UUID(),
            displayName: "Test Person",
            fileName: "test.eir",
            patientName: "Test Person",
            personalNumber: "19900101-1234",
            birthDate: "1990-01-01",
            totalEntries: 25,
            addedAt: Date()
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersonProfile.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.fileName, original.fileName, "fileName should survive encode/decode")
        XCTAssertEqual(decoded.totalEntries, original.totalEntries)
    }

    func testProfileDecodesFromOldFormatWithFileURL() throws {
        // Simulate the OLD format where fileURL was stored as a full path
        let oldJSON = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "displayName": "Old Person",
            "fileURL": "file:///var/mobile/Containers/Data/Application/OLD-UUID/Documents/old-data.eir",
            "patientName": "Old Person",
            "personalNumber": "19800101-0000",
            "birthDate": "1980-01-01",
            "totalEntries": 10,
            "addedAt": 0
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(PersonProfile.self, from: oldJSON)
        XCTAssertEqual(decoded.fileName, "old-data.eir",
                       "Should extract fileName from old fileURL format")
        XCTAssertEqual(decoded.displayName, "Old Person")

        // fileURL should resolve to CURRENT Documents, not old path
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        XCTAssertEqual(decoded.fileURL, docs.appendingPathComponent("old-data.eir"),
                       "fileURL should point to current Documents dir, not old stale path")
    }

    // MARK: - Step 5: DocumentViewModel loads from profile.fileURL

    func testDocumentViewModelLoadsFile() throws {
        let docsFile = writeSampleToDocuments(named: "docvm-test.eir")
        defer { cleanupDocumentsFile(docsFile) }

        let vm = DocumentViewModel()
        XCTAssertNil(vm.document, "Should start with nil document")

        vm.loadFile(url: docsFile)
        XCTAssertNotNil(vm.document, "Document should be loaded")
        XCTAssertEqual(vm.document?.entries.count, 3, "Should have 3 entries")
        XCTAssertNil(vm.errorMessage, "Should have no error")
    }

    func testDocumentViewModelReportsError() {
        let vm = DocumentViewModel()
        let fakeURL = tempDir.appendingPathComponent("nonexistent.eir")

        vm.loadFile(url: fakeURL)
        XCTAssertNil(vm.document, "Document should be nil for missing file")
        XCTAssertNotNil(vm.errorMessage, "Should report an error")
    }

    // MARK: - Step 6: selectProfile posts notification

    func testSelectProfilePostsNotification() throws {
        let docsFile = writeSampleToDocuments(named: "notify-test.eir")
        defer { cleanupDocumentsFile(docsFile) }

        let store = ProfileStore()
        store.profiles = []

        let profile = store.addProfile(displayName: "", fileURL: docsFile)!

        let expectation = XCTestExpectation(description: "profileDidLoad notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .profileDidLoad,
            object: nil,
            queue: .main
        ) { notification in
            let notifiedID = notification.object as? UUID
            XCTAssertEqual(notifiedID, profile.id, "Notification should carry the profile ID")
            expectation.fulfill()
        }

        store.selectProfile(profile.id)
        wait(for: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
        XCTAssertEqual(store.selectedProfileID, profile.id)
    }

    // MARK: - Step 7: Full QR flow simulation

    func testFullQRTransferFlow() throws {
        // === STEP A: Simulate LocalTransferClient downloading file to Documents ===
        let downloadedFile = writeSampleToDocuments(named: "qr-flow-test.eir")
        defer { cleanupDocumentsFile(downloadedFile) }

        // === STEP B: Simulate QRScannerView's "Open Records" button ===
        let profileStore = ProfileStore()
        profileStore.profiles = []

        // This is what QRScannerView does:
        let profile = profileStore.addProfile(displayName: "", fileURL: downloadedFile)
        XCTAssertNotNil(profile, "Step B: addProfile should succeed")
        XCTAssertNil(profileStore.errorMessage, "Step B: no error: \(profileStore.errorMessage ?? "")")
        XCTAssertEqual(profileStore.profiles.count, 1, "Step B: should have 1 profile")

        // === STEP C: selectProfile - this triggers the notification chain ===
        profileStore.selectProfile(profile!.id)
        XCTAssertEqual(profileStore.selectedProfileID, profile!.id)
        XCTAssertNotNil(profileStore.selectedProfile, "Step C: selectedProfile should not be nil")

        // === STEP D: ContentView.loadSelectedProfile loads the document ===
        let documentVM = DocumentViewModel()
        let selectedProfile = profileStore.selectedProfile!
        documentVM.loadFile(url: selectedProfile.fileURL)

        XCTAssertNotNil(documentVM.document,
                        "Step D: Document should be loaded. Error: \(documentVM.errorMessage ?? "none")")
        XCTAssertEqual(documentVM.document?.entries.count, 3,
                       "Step D: Should have 3 entries")
        XCTAssertEqual(documentVM.document?.metadata.patient?.name, "Test Person")

        // === STEP E: Verify journal would show entries ===
        XCTAssertFalse(documentVM.groupedEntries.isEmpty,
                       "Step E: groupedEntries should not be empty")
        XCTAssertFalse(documentVM.filteredEntries.isEmpty,
                       "Step E: filteredEntries should not be empty")

        print("✅ Full QR flow test passed:")
        print("   - File in Documents: \(selectedProfile.fileURL.path)")
        print("   - File exists: \(FileManager.default.fileExists(atPath: selectedProfile.fileURL.path))")
        print("   - Profile: \(selectedProfile.displayName) (\(selectedProfile.fileName))")
        print("   - Entries: \(documentVM.document?.entries.count ?? 0)")
        print("   - Grouped: \(documentVM.groupedEntries.count) groups")
    }

    // MARK: - Step 8: Adding a SECOND person (existing person already loaded)

    func testAddSecondPersonViaQR() throws {
        // Setup: first person already loaded
        let file1 = writeSampleToDocuments(named: "person1.eir")
        defer { cleanupDocumentsFile(file1) }

        let profileStore = ProfileStore()
        profileStore.profiles = []

        let profile1 = profileStore.addProfile(displayName: "Person One", fileURL: file1)!
        profileStore.selectProfile(profile1.id)

        let documentVM = DocumentViewModel()
        documentVM.loadFile(url: profileStore.selectedProfile!.fileURL)
        XCTAssertNotNil(documentVM.document, "Person 1 document should be loaded")

        // === Now simulate adding second person via QR ===
        let secondYAML = """
        metadata:
          format_version: "1.0"
          patient:
            name: "Second Person"
            personal_number: "19950505-5678"
        entries:
          - id: "second_001"
            date: "2025-01-15"
            category: "Provsvar"
            provider:
              name: "Other Clinic"
            content:
              summary: "Second person's visit"
              notes: []
            attachments: []
            tags: []
          - id: "second_002"
            date: "2025-01-10"
            category: "Vårdkontakter"
            provider:
              name: "Other Clinic"
            content:
              summary: "Second person's other visit"
              notes: []
            attachments: []
            tags: []
        """
        let file2 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("person2.eir")
        try secondYAML.write(to: file2, atomically: true, encoding: .utf8)
        defer { cleanupDocumentsFile(file2) }

        let profile2 = profileStore.addProfile(displayName: "", fileURL: file2)
        XCTAssertNotNil(profile2, "Second profile should be created")
        XCTAssertEqual(profileStore.profiles.count, 2, "Should have 2 profiles")
        XCTAssertNil(profileStore.errorMessage, "No error: \(profileStore.errorMessage ?? "")")

        // Select second person (what QRScannerView does)
        profileStore.selectProfile(profile2!.id)

        // ContentView.loadSelectedProfile would do this:
        let selectedProfile = profileStore.selectedProfile!
        XCTAssertEqual(selectedProfile.displayName, "Second Person")
        documentVM.loadFile(url: selectedProfile.fileURL)

        XCTAssertNotNil(documentVM.document, "Second person's document should load")
        XCTAssertEqual(documentVM.document?.entries.count, 2, "Second person has 2 entries")
        XCTAssertEqual(documentVM.document?.metadata.patient?.name, "Second Person")

        // === Switch back to first person ===
        profileStore.selectProfile(profile1.id)
        let firstProfile = profileStore.selectedProfile!
        documentVM.loadFile(url: firstProfile.fileURL)

        XCTAssertEqual(documentVM.document?.entries.count, 3, "Back to person 1 with 3 entries")
        XCTAssertEqual(documentVM.document?.metadata.patient?.name, "Test Person")

        print("✅ Second person flow test passed")
        print("   - Person 1: \(profile1.displayName) (\(profile1.fileName)) - 3 entries")
        print("   - Person 2: \(profile2!.displayName) (\(profile2!.fileName)) - 2 entries")
    }

    // MARK: - Step 9: Persistence across restarts (simulated)

    func testProfilePersistsAcrossRestart() throws {
        let docsFile = writeSampleToDocuments(named: "persist-test.eir")
        defer { cleanupDocumentsFile(docsFile) }

        // First "session": create and select profile
        let store1 = ProfileStore()
        store1.profiles = []
        let profile = store1.addProfile(displayName: "Persistent", fileURL: docsFile)!
        store1.selectProfile(profile.id)

        // Second "session": create a new ProfileStore (simulates restart)
        let store2 = ProfileStore()

        XCTAssertFalse(store2.profiles.isEmpty,
                       "Profiles should persist across store re-creation")
        XCTAssertEqual(store2.selectedProfileID, profile.id,
                       "Selected profile ID should persist")
        XCTAssertNotNil(store2.selectedProfile,
                        "selectedProfile computed property should work")
        XCTAssertEqual(store2.selectedProfile?.fileName, "persist-test.eir")

        // Load the document from the persisted profile
        let documentVM = DocumentViewModel()
        documentVM.loadFile(url: store2.selectedProfile!.fileURL)
        XCTAssertNotNil(documentVM.document,
                        "Document should load after restart. Error: \(documentVM.errorMessage ?? "none")")
        XCTAssertEqual(documentVM.document?.entries.count, 3)

        print("✅ Persistence test passed")
        print("   - Profile survived restart: \(store2.selectedProfile!.displayName)")
        print("   - File resolves to: \(store2.selectedProfile!.fileURL.path)")
        print("   - File exists: \(FileManager.default.fileExists(atPath: store2.selectedProfile!.fileURL.path))")
    }

    // MARK: - Step 10: EncryptedStore round-trip

    func testEncryptedStoreRoundTrip() {
        let testKey = "test_roundtrip_\(UUID().uuidString)"
        defer { EncryptedStore.remove(forKey: testKey) }

        let profiles = [
            PersonProfile(id: UUID(), displayName: "A", fileName: "a.eir",
                         patientName: nil, personalNumber: nil, birthDate: nil,
                         totalEntries: 5, addedAt: Date()),
            PersonProfile(id: UUID(), displayName: "B", fileName: "b.eir",
                         patientName: nil, personalNumber: nil, birthDate: nil,
                         totalEntries: 10, addedAt: Date()),
        ]

        EncryptedStore.save(profiles, forKey: testKey)
        let loaded = EncryptedStore.load([PersonProfile].self, forKey: testKey)

        XCTAssertNotNil(loaded, "Should load encrypted data back")
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?[0].displayName, "A")
        XCTAssertEqual(loaded?[1].fileName, "b.eir")
    }
}

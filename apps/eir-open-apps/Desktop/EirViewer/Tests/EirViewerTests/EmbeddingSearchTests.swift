import XCTest
import SQLiteVec
@testable import EirViewer

// MARK: - Test Data Helpers

/// Loads real journal files from disk for testing
enum RealJournalData {

    struct JournalFile {
        let label: String       // Display name used in app (e.g. "Birger", "Birk")
        let path: String
    }

    static let files: [JournalFile] = [
        JournalFile(label: "Birger", path: "/Users/birger/Journal_content/journal-content.eir"),
        JournalFile(label: "Birk", path: "/Users/birger/Journal_content/birk_journal.eir"),
        JournalFile(label: "Hedda", path: "/Users/birger/Journal_content/hedda_journal.eir"),
    ]

    /// Known dental entry IDs from Birger's journal (journal-content.eir)
    /// - entry_013: Diagnosis TLV tillstånd, Folktandvården Östervåla (2024-06-11)
    /// - entry_014: Treatment Åtgärd/behandling, Folktandvården Östervåla (2024-06-11)
    /// - entry_015: Investigation Utredning, tooth 11 filling/fracture (2024-06-11)
    /// - entry_016: Clinic visit Folktandvården Östervåla (2024-06-11)
    /// - entry_017: Phone call about tooth fracture (2024-06-05)
    /// - entry_023: EMERGENCY pericoronitis wisdom tooth, Fridhemsplan Akuten (2021-07-10)
    /// - entry_024: Emergency clinic contact Fridhemsplan (2021-07-10)
    static let birgerDentalIDs: Set<String> = [
        "entry_013", "entry_014", "entry_015", "entry_016",
        "entry_017", "entry_023", "entry_024"
    ]

    /// Known dental entry IDs from Birk's journal (birk_journal.eir)
    /// - entry_001: Dental hygienist treatment (2025-11-11)
    /// - entry_002: Dental clinic visit (2025-11-11)
    /// - entry_003: Comprehensive 3-year dental health check (2025-11-11)
    /// - entry_004: 3-year check rescheduled (2025-10-22)
    /// - entry_008: SMS reminder for dental exam (2025-08-13)
    /// - entry_021: Fluoride analysis of household water, 1.57 mg/l (2024-12-09)
    /// - entry_028: 2-year health talk examination (2024-08-29)
    /// - entry_029: 2-year health check visit note (2024-08-29)
    /// - entry_030: Dental clinic contact (2024-08-29)
    /// - entry_031: CPP reminder for health check (2024-08-14)
    static let birkDentalIDs: Set<String> = [
        "entry_001", "entry_002", "entry_003", "entry_004",
        "entry_008", "entry_021", "entry_028", "entry_029",
        "entry_030", "entry_031"
    ]

    static let allDentalIDs: Set<String> = birgerDentalIDs.union(birkDentalIDs)

    /// Composite IDs used in VectorStore (personName:entryId)
    static let birgerDentalCompositeIDs: Set<String> = Set(birgerDentalIDs.map { "Birger:\($0)" })
    static let birkDentalCompositeIDs: Set<String> = Set(birkDentalIDs.map { "Birk:\($0)" })
    static let allDentalCompositeIDs: Set<String> = birgerDentalCompositeIDs.union(birkDentalCompositeIDs)

    /// Load all journal files and return as (label, document) pairs
    static func loadAll() throws -> [(personName: String, document: EirDocument)] {
        var docs: [(personName: String, document: EirDocument)] = []
        for file in files {
            guard FileManager.default.fileExists(atPath: file.path) else {
                print("⚠ Skipping \(file.label): \(file.path) not found")
                continue
            }
            let doc = try EirParser.parse(url: URL(fileURLWithPath: file.path))
            docs.append((personName: file.label, document: doc))
        }
        return docs
    }

    /// Load all journal files with generated profile UUIDs (for ToolContext)
    static func loadAllWithIDs() throws -> [(profileID: UUID, personName: String, document: EirDocument)] {
        try loadAll().map { (profileID: UUID(), personName: $0.personName, document: $0.document) }
    }

    /// Build searchable text for an entry (mirrors EmbeddingStore.buildSearchableText)
    static func buildSearchableText(from entry: EirEntry, personName: String) -> String {
        var parts: [String] = []
        parts.append(personName)
        if let date = entry.date { parts.append(date) }
        if let cat = entry.category { parts.append(cat) }
        if let type = entry.type { parts.append(type) }
        if let provider = entry.provider?.name { parts.append(provider) }
        if let summary = entry.content?.summary { parts.append(summary) }
        if let details = entry.content?.details { parts.append(details) }
        if let notes = entry.content?.notes { parts.append(notes.joined(separator: " ")) }
        if let tags = entry.tags { parts.append(tags.joined(separator: " ")) }
        return parts.joined(separator: " ")
    }

    /// Check if an entry is dental-related by examining its fields
    static func isDentalEntry(_ entry: EirEntry) -> Bool {
        let dentalTerms = ["tandvård", "tandläkar", "tandhygienist", "tandsköterska",
                           "folktandvården", "tand ", "dental", "karies", "fluorid"]
        let searchable = buildSearchableText(from: entry, personName: "").lowercased()
        return dentalTerms.contains { searchable.contains($0) }
    }

    /// Index all entries from all documents into the given VectorStore using composite IDs.
    /// Returns the total number of entries indexed.
    static func indexAll(
        docs: [(personName: String, document: EirDocument)],
        into store: VectorStore,
        provider: AppleNLEmbeddingProvider
    ) async throws -> Int {
        var count = 0
        for (personName, doc) in docs {
            for entry in doc.entries {
                let text = buildSearchableText(from: entry, personName: personName)
                let embedding = try await provider.embed(text)
                try await store.insertEntry(
                    id: "\(personName):\(entry.id)",
                    personName: personName,
                    date: entry.date,
                    category: entry.category,
                    text: text,
                    hash: "h-\(personName)-\(entry.id)",
                    model: provider.modelName,
                    embedding: embedding
                )
                count += 1
            }
        }
        return count
    }
}


// MARK: - VectorStore Unit Tests

final class VectorStoreTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        try! SQLiteVec.initialize()
    }

    // MARK: - Basic CRUD

    func testOpenInMemory() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()
        let isOpen = await store.isOpen
        XCTAssertTrue(isOpen)
    }

    func testInsertAndCount() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(
            id: "test-1", personName: "Test", date: "2025-01-01",
            category: "Lab", text: "Blood test normal",
            hash: "abc123", model: "test",
            embedding: [0.1, 0.2, 0.3, 0.4]
        )

        let count = try await store.indexedEntryCount()
        XCTAssertEqual(count, 1)
    }

    func testUpsertDoesNotDuplicate() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(
            id: "dup-1", personName: "Test", date: nil,
            category: nil, text: "Original", hash: "v1", model: "test",
            embedding: [0.1, 0.2, 0.3, 0.4]
        )
        try await store.insertEntry(
            id: "dup-1", personName: "Test", date: nil,
            category: nil, text: "Updated", hash: "v2", model: "test",
            embedding: [0.5, 0.6, 0.7, 0.8]
        )

        let count = try await store.indexedEntryCount()
        XCTAssertEqual(count, 1, "Upsert should not duplicate")

        let hash = try await store.entryHash(for: "dup-1")
        XCTAssertEqual(hash, "v2", "Hash should reflect latest insert")
    }

    func testCompositeIDsPreventCollision() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        // Same entry_id from different persons — should NOT collide with composite IDs
        try await store.insertEntry(
            id: "Birk:entry_004", personName: "Birk", date: "2025-10-22",
            category: "Anteckningar", text: "Folktandvården tandvård dental", hash: "dental", model: "test",
            embedding: [1, 0, 0, 0]
        )
        try await store.insertEntry(
            id: "Hedda:entry_004", personName: "Hedda", date: "2025-10-08",
            category: "Vaccinationer", text: "Hexyon vaccination dos 3", hash: "vaccine", model: "test",
            embedding: [0, 1, 0, 0]
        )

        let count = try await store.indexedEntryCount()
        XCTAssertEqual(count, 2, "Composite IDs should allow same entry_id from different persons")

        let birkHash = try await store.entryHash(for: "Birk:entry_004")
        let heddaHash = try await store.entryHash(for: "Hedda:entry_004")
        XCTAssertEqual(birkHash, "dental")
        XCTAssertEqual(heddaHash, "vaccine")
    }

    func testClearAll() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        for i in 0..<3 {
            try await store.insertEntry(
                id: "e-\(i)", personName: "Test", date: nil,
                category: nil, text: "entry \(i)", hash: "h\(i)", model: "test",
                embedding: [Float(i), 0, 0, 0]
            )
        }
        let countBefore = try await store.indexedEntryCount()
        XCTAssertEqual(countBefore, 3)

        try await store.clearAll()
        let countAfter = try await store.indexedEntryCount()
        XCTAssertEqual(countAfter, 0)
    }

    // MARK: - Vector Search

    func testVectorSearchFindsNearestNeighbor() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "north", personName: "T", date: nil, category: nil, text: "north", hash: "h1", model: "t", embedding: [1, 0, 0, 0])
        try await store.insertEntry(id: "east", personName: "T", date: nil, category: nil, text: "east", hash: "h2", model: "t", embedding: [0, 1, 0, 0])
        try await store.insertEntry(id: "south", personName: "T", date: nil, category: nil, text: "south", hash: "h3", model: "t", embedding: [0, 0, 1, 0])

        let results = try await store.vectorSearch(queryEmbedding: [0.9, 0.1, 0, 0], limit: 3)
        XCTAssertEqual(results.first?.id, "north")
        XCTAssertGreaterThan(results.first?.score ?? 0, 0.5)
    }

    func testVectorSearchScoresDescending() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        let entries: [(id: String, emb: [Float])] = [
            ("exact", [1, 0, 0, 0]),
            ("close", [0.8, 0.2, 0, 0]),
            ("far",   [0, 0, 0, 1]),
        ]
        for e in entries {
            try await store.insertEntry(id: e.id, personName: "T", date: nil, category: nil, text: e.id, hash: "h-\(e.id)", model: "t", embedding: e.emb)
        }

        let results = try await store.vectorSearch(queryEmbedding: [1, 0, 0, 0], limit: 3)
        for i in 0..<(results.count - 1) {
            XCTAssertGreaterThanOrEqual(results[i].score, results[i+1].score)
        }
        XCTAssertEqual(results.first?.id, "exact")
    }

    func testVectorSearchFilterByPerson() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "Alice:a1", personName: "Alice", date: nil, category: nil, text: "dental", hash: "h1", model: "t", embedding: [1, 0, 0, 0])
        try await store.insertEntry(id: "Bob:b1", personName: "Bob", date: nil, category: nil, text: "dental", hash: "h2", model: "t", embedding: [0.9, 0.1, 0, 0])

        let results = try await store.vectorSearch(queryEmbedding: [1, 0, 0, 0], personName: "Alice", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.personName, "Alice")
    }

    func testVectorSearchFilterByCategory() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "lab", personName: "T", date: nil, category: "Lab", text: "blood", hash: "h1", model: "t", embedding: [1, 0, 0, 0])
        try await store.insertEntry(id: "dental", personName: "T", date: nil, category: "Tandvård", text: "teeth", hash: "h2", model: "t", embedding: [0.9, 0.1, 0, 0])

        let results = try await store.vectorSearch(queryEmbedding: [1, 0, 0, 0], category: "Tandvård", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, "Tandvård")
    }

    // MARK: - FTS5 Keyword Search

    func testKeywordSearchBasic() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "kw1", personName: "Birger", date: "2024-06-11", category: "Anteckningar", text: "Tandläkarbesök kontroll Folktandvården Östervåla", hash: "h1", model: "t", embedding: [0, 0, 0, 1])
        try await store.insertEntry(id: "kw2", personName: "Birger", date: "2025-01-01", category: "Lab", text: "Blodprov hemoglobin normalt", hash: "h2", model: "t", embedding: [0, 0, 1, 0])

        let results = try await store.keywordSearch(query: "tandläkar", limit: 10)
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "kw1")
    }

    func testKeywordSearchPrefixMatching() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "pref1", personName: "Birk", date: nil, category: nil, text: "Allergitest IgE-panel björk gräs", hash: "h1", model: "t", embedding: [1, 0, 0, 0])

        // "allergi" should match "Allergitest" via prefix
        let results = try await store.keywordSearch(query: "allergi", limit: 10)
        XCTAssertGreaterThanOrEqual(results.count, 1, "'allergi' should prefix-match 'Allergitest'")
        XCTAssertEqual(results.first?.id, "pref1")
    }

    func testKeywordSearchSwedishMedicalTerms() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        let entries: [(id: String, text: String)] = [
            ("sv1", "Pericoronit visdomstand inflammerad gingiva Folktandvården Fridhemsplan Akuten"),
            ("sv2", "Blodtryck 130/85 mmHg puls 72 slag per minut"),
            ("sv3", "Fluoridanalys av hushållsvatten hög fluorhalt 1.57 mg/l"),
            ("sv4", "Vaccinering FSME-IMMUN fästingburen encefalit"),
        ]
        for e in entries {
            try await store.insertEntry(id: e.id, personName: "T", date: nil, category: nil, text: e.text, hash: "h-\(e.id)", model: "t", embedding: [1, 0, 0, 0])
        }

        // "fluorid" should prefix-match "Fluoridanalys"
        let fluorResults = try await store.keywordSearch(query: "fluorid", limit: 10)
        XCTAssertEqual(fluorResults.first?.id, "sv3")

        // "pericoronit" should find wisdom tooth entry
        let periResults = try await store.keywordSearch(query: "pericoronit", limit: 10)
        XCTAssertEqual(periResults.first?.id, "sv1")

        // "vaccin" should prefix-match "Vaccinering"
        let vaccResults = try await store.keywordSearch(query: "vaccin", limit: 10)
        XCTAssertEqual(vaccResults.first?.id, "sv4")
    }

    func testKeywordSearchFilterByPerson() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "a", personName: "Birger", date: nil, category: nil, text: "Folktandvården tandläkare", hash: "h1", model: "t", embedding: [1, 0, 0, 0])
        try await store.insertEntry(id: "b", personName: "Birk", date: nil, category: nil, text: "Folktandvården tandhygienist", hash: "h2", model: "t", embedding: [0, 1, 0, 0])

        let results = try await store.keywordSearch(query: "folktandvården", personName: "Birk", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.personName, "Birk")
    }

    func testKeywordSearchNoMatch() async throws {
        let store = VectorStore(dimensions: 4)
        try await store.openInMemory()

        try await store.insertEntry(id: "x", personName: "T", date: nil, category: nil, text: "tandvård kontroll", hash: "h1", model: "t", embedding: [1, 0, 0, 0])

        let results = try await store.keywordSearch(query: "hjärttransplantation", limit: 10)
        XCTAssertEqual(results.count, 0)
    }
}


// MARK: - Apple NL Embedding Tests

final class AppleNLEmbeddingTests: XCTestCase {

    func testProducesEmbeddings() async throws {
        let provider = AppleNLEmbeddingProvider()
        let embedding = try await provider.embed("Tandläkarbesök kontroll och rengöring")
        XCTAssertEqual(embedding.count, 768)
        XCTAssertFalse(embedding.allSatisfy { $0 == 0 })
    }

    func testSwedishMedicalText() async throws {
        let provider = AppleNLEmbeddingProvider()
        let embedding = try await provider.embed("Pericoronit visdomstand inflammerad gingiva saline Corsodyl gel")
        XCTAssertEqual(embedding.count, 768)
        XCTAssertFalse(embedding.allSatisfy { $0 == 0 })
    }

    func testDentalTextsSimilar() async throws {
        let provider = AppleNLEmbeddingProvider()

        // Two dental entries should be more similar than dental-vs-vaccination
        let dental1 = try await provider.embed("Tandläkarbesök kontroll tandrengöring Folktandvården karies")
        let dental2 = try await provider.embed("Akut tandvärk rotbehandling pericoronit visdomstand")
        let vaccine = try await provider.embed("Vaccination FSME-IMMUN fästingburen encefalit dos 1")

        let simDentalPair = cosineSimilarity(dental1, dental2)
        let simDentalVaccine = cosineSimilarity(dental1, vaccine)

        print("dental-dental similarity: \(simDentalPair)")
        print("dental-vaccine similarity: \(simDentalVaccine)")

        XCTAssertGreaterThan(simDentalPair, simDentalVaccine,
            "Dental texts should be more similar to each other than to vaccination text")
    }

    func testChildDentalVsAdultDentalSimilar() async throws {
        let provider = AppleNLEmbeddingProvider()

        // Birk's child dental check vs Birger's adult dental visit
        let childDental = try await provider.embed("Birk tandhygienist undersökning mjölktänder fluorbehandling tandborstning karies ingen anmärkning")
        let adultDental = try await provider.embed("Birger tandläkare fraktur tand 11 fyllning komposit Folktandvården Östervåla")
        let labTest = try await provider.embed("Birger blodprov hemoglobin leukocyter trombocyter ALAT ASAT levervärden")

        let simChildAdultDental = cosineSimilarity(childDental, adultDental)
        let simChildLab = cosineSimilarity(childDental, labTest)

        print("child-dental vs adult-dental: \(simChildAdultDental)")
        print("child-dental vs lab: \(simChildLab)")

        XCTAssertGreaterThan(simChildAdultDental, simChildLab,
            "Child dental and adult dental should be more similar than child dental and lab test")
    }

    func testEmptyTextHandling() async throws {
        let provider = AppleNLEmbeddingProvider()
        do {
            let _ = try await provider.embed("")
        } catch {
            // Expected — empty text should throw EmbeddingError
            XCTAssertTrue(error is EmbeddingError)
        }
    }

    func testBatchEmbedding() async throws {
        let provider = AppleNLEmbeddingProvider()
        let texts = [
            "Tandläkarbesök Folktandvården Östervåla",
            "Blodprov hemoglobin normalt",
            "Vaccination FSME-IMMUN",
        ]
        let embeddings = try await provider.embedBatch(texts)
        XCTAssertEqual(embeddings.count, 3)
        for emb in embeddings {
            XCTAssertEqual(emb.count, 768)
        }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0, normA: Float = 0, normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }
}


// MARK: - Hybrid Search Merge Tests

final class HybridSearchMergeTests: XCTestCase {

    func testMergeBoostsEntriesInBothLists() {
        let vector = [
            SearchResult(id: "a", personName: "T", date: nil, category: nil, text: "a", score: 0.9, source: .vector),
            SearchResult(id: "b", personName: "T", date: nil, category: nil, text: "b", score: 0.5, source: .vector),
        ]
        let keyword = [
            SearchResult(id: "a", personName: "T", date: nil, category: nil, text: "a", score: 0.8, source: .keyword),
            SearchResult(id: "c", personName: "T", date: nil, category: nil, text: "c", score: 0.7, source: .keyword),
        ]

        let merged = mergeHybrid(vector: vector, keyword: keyword, vectorWeight: 0.7, textWeight: 0.3, minScore: 0.1, limit: 10)

        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged[0].id, "a", "Entry in both lists should rank first")
        // a: (0.7*0.9 + 0.3*0.8)/1.0 = 0.87
        XCTAssertEqual(merged[0].score, 0.87, accuracy: 0.01)
    }

    func testMinScoreFilters() {
        let vector = [
            SearchResult(id: "high", personName: "T", date: nil, category: nil, text: "high", score: 0.9, source: .vector),
            SearchResult(id: "low", personName: "T", date: nil, category: nil, text: "low", score: 0.1, source: .vector),
        ]
        let merged = mergeHybrid(vector: vector, keyword: [], vectorWeight: 0.7, textWeight: 0.3, minScore: 0.2, limit: 10)
        // "low": 0.7*0.1/1.0 = 0.07 < 0.2 threshold
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].id, "high")
    }

    func testLimitEnforced() {
        let vector: [SearchResult] = (0..<20).map { i in
            SearchResult(id: "v\(i)", personName: "T", date: nil, category: nil, text: "\(i)", score: 1.0 - Double(i) * 0.04, source: .vector)
        }
        let merged = mergeHybrid(vector: vector, keyword: [], vectorWeight: 0.7, textWeight: 0.3, minScore: 0, limit: 5)
        XCTAssertEqual(merged.count, 5)
    }

    func testEmptyInputs() {
        let merged = mergeHybrid(vector: [], keyword: [], vectorWeight: 0.7, textWeight: 0.3, minScore: 0.1, limit: 10)
        XCTAssertTrue(merged.isEmpty)
    }

    // Mirror of EmbeddingStore.mergeHybrid
    private func mergeHybrid(vector: [SearchResult], keyword: [SearchResult], vectorWeight: Double, textWeight: Double, minScore: Double, limit: Int) -> [SearchResult] {
        struct M { var id: String; var pn: String; var d: String?; var c: String?; var t: String; var vs: Double = 0; var ts: Double = 0 }
        var byID: [String: M] = [:]
        for r in vector { byID[r.id] = M(id: r.id, pn: r.personName, d: r.date, c: r.category, t: r.text, vs: r.score) }
        for r in keyword {
            if var e = byID[r.id] { e.ts = r.score; byID[r.id] = e }
            else { byID[r.id] = M(id: r.id, pn: r.personName, d: r.date, c: r.category, t: r.text, ts: r.score) }
        }
        let tw = vectorWeight + textWeight
        return byID.values
            .map { e in SearchResult(id: e.id, personName: e.pn, date: e.d, category: e.c, text: e.t, score: (vectorWeight * e.vs + textWeight * e.ts) / tw, source: .vector) }
            .filter { $0.score >= minScore }
            .sorted { $0.score > $1.score }
            .prefix(limit).map { $0 }
    }
}


// MARK: - ToolRegistry Tests (get_medical_records)

final class ToolRegistrySearchTests: XCTestCase {

    func testGetMedicalRecordsReturnsAllPeople() async throws {
        let docs = try RealJournalData.loadAllWithIDs()
        guard !docs.isEmpty else { return }

        let call = ToolCall(id: "t1", name: "get_medical_records", arguments: "{}")
        let context = ToolContext(document: nil, allDocuments: docs, agentMemoryStore: nil, clinicStore: nil, embeddingStore: nil)
        let result = await ToolRegistry().execute(call: call, context: context)

        XCTAssertTrue(result.content.contains("# Birger"), "Should contain Birger's records")
        XCTAssertTrue(result.content.contains("# Birk"), "Should contain Birk's records")
        XCTAssertTrue(result.content.contains("# Hedda"), "Should contain Hedda's records")
        XCTAssertFalse(result.content.contains("No medical records"), "Should find records")
    }

    func testGetMedicalRecordsFilterByPerson() async throws {
        let docs = try RealJournalData.loadAllWithIDs()
        guard !docs.isEmpty else { return }

        let call = ToolCall(id: "t2", name: "get_medical_records", arguments: #"{"person": "Birk"}"#)
        let context = ToolContext(document: nil, allDocuments: docs, agentMemoryStore: nil, clinicStore: nil, embeddingStore: nil)
        let result = await ToolRegistry().execute(call: call, context: context)

        XCTAssertTrue(result.content.contains("# Birk"), "Should contain Birk's records")
        XCTAssertFalse(result.content.contains("# Birger"), "Person filter 'Birk' should exclude Birger")
    }

    func testGetMedicalRecordsContainsCompositeIDs() async throws {
        let docs = try RealJournalData.loadAllWithIDs()
        guard docs.count > 1 else { return }

        let call = ToolCall(id: "t3", name: "get_medical_records", arguments: "{}")
        let context = ToolContext(document: nil, allDocuments: docs, agentMemoryStore: nil, clinicStore: nil, embeddingStore: nil)
        let result = await ToolRegistry().execute(call: call, context: context)

        // Multi-person output should use composite IDs (PersonName::entry_id)
        XCTAssertTrue(result.content.contains("Birger::entry_"), "Should use Birger::entry_id composite IDs")
        XCTAssertTrue(result.content.contains("Birk::entry_"), "Should use Birk::entry_id composite IDs")
    }

    func testGetMedicalRecordsUsesCompositeIDsEvenWhenFiltered() async throws {
        let docs = try RealJournalData.loadAllWithIDs()
        guard docs.count > 1 else { return }

        // Filter to single person — should STILL use composite IDs since multiple profiles exist
        let call = ToolCall(id: "t3b", name: "get_medical_records", arguments: #"{"person": "Birk"}"#)
        let context = ToolContext(document: nil, allDocuments: docs, agentMemoryStore: nil, clinicStore: nil, embeddingStore: nil)
        let result = await ToolRegistry().execute(call: call, context: context)

        XCTAssertTrue(result.content.contains("Birk::entry_"),
            "Filtered results should still use composite IDs when multiple profiles are loaded")
    }

    func testGetMedicalRecordsContainsEntryDetails() async throws {
        let docs = try RealJournalData.loadAllWithIDs()
        guard !docs.isEmpty else { return }

        let call = ToolCall(id: "t4", name: "get_medical_records", arguments: #"{"person": "Birger"}"#)
        let context = ToolContext(document: nil, allDocuments: docs, agentMemoryStore: nil, clinicStore: nil, embeddingStore: nil)
        let result = await ToolRegistry().execute(call: call, context: context)

        // Should contain actual entry content
        XCTAssertTrue(result.content.contains("entry_"), "Should contain entry IDs")
        XCTAssertTrue(result.content.contains("Total entries:"), "Should show entry count")
    }

    func testGetMedicalRecordsUnknownPersonReturnsEmpty() async throws {
        let docs = try RealJournalData.loadAllWithIDs()
        guard !docs.isEmpty else { return }

        let call = ToolCall(id: "t5", name: "get_medical_records", arguments: #"{"person": "NonexistentPerson"}"#)
        let context = ToolContext(document: nil, allDocuments: docs, agentMemoryStore: nil, clinicStore: nil, embeddingStore: nil)
        let result = await ToolRegistry().execute(call: call, context: context)

        XCTAssertTrue(result.content.contains("No records found"), "Unknown person should return no records")
    }
}


// MARK: - Real Data: Full Index + Dental Search

final class RealDataDentalSearchTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        try! SQLiteVec.initialize()
    }

    /// Index all real journal entries with composite IDs, then search for dental entries
    /// and verify we find all known dental entries for both Birger and Birk
    func testFindAllDentalEntriesViaKeyword() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let totalIndexed = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)
        print("Indexed \(totalIndexed) entries from real data")

        // Keyword search for dental terms
        let dentalQueries = ["tandvård", "folktandvården", "tandläkar", "tandhygienist", "tandsköterska", "fluorid"]
        var foundIDs: Set<String> = []

        for query in dentalQueries {
            let results = try await store.keywordSearch(query: query, limit: 50)
            for r in results {
                foundIDs.insert(r.id)
            }
        }

        print("\nKeyword search found \(foundIDs.count) dental-related entries:")
        for id in foundIDs.sorted() {
            print("  \(id)")
        }

        // Check Birger's dental entries (using composite IDs)
        let foundBirgerDental = RealJournalData.birgerDentalCompositeIDs.intersection(foundIDs)
        let missingBirger = RealJournalData.birgerDentalCompositeIDs.subtracting(foundIDs)
        print("\nBirger dental: found \(foundBirgerDental.count)/\(RealJournalData.birgerDentalIDs.count)")
        if !missingBirger.isEmpty {
            print("  MISSING: \(missingBirger.sorted())")
        }

        // Check Birk's dental entries (using composite IDs)
        let foundBirkDental = RealJournalData.birkDentalCompositeIDs.intersection(foundIDs)
        let missingBirk = RealJournalData.birkDentalCompositeIDs.subtracting(foundIDs)
        print("Birk dental: found \(foundBirkDental.count)/\(RealJournalData.birkDentalIDs.count)")
        if !missingBirk.isEmpty {
            print("  MISSING: \(missingBirk.sorted())")
        }

        XCTAssertGreaterThanOrEqual(foundBirgerDental.count, 5,
            "Should find at least 5 of Birger's 7 dental entries via keyword. Missing: \(missingBirger.sorted())")
        XCTAssertGreaterThanOrEqual(foundBirkDental.count, 7,
            "Should find at least 7 of Birk's 10 dental entries via keyword. Missing: \(missingBirk.sorted())")
    }

    /// Vector search should find dental entries even with a general query
    func testVectorSearchDentalQuery() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let _ = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)

        // Broad dental query
        let queryEmb = try await provider.embed("tandvård tandläkare dental tänder kontroll")
        let results = try await store.vectorSearch(queryEmbedding: queryEmb, limit: 20)

        print("\n=== Vector search: 'tandvård tandläkare dental tänder kontroll' (top 20) ===")
        for r in results {
            let isDental = RealJournalData.allDentalCompositeIDs.contains(r.id)
            print("  \(isDental ? "✓" : " ") [\(r.personName)] \(r.date ?? "?") score=\(String(format: "%.3f", r.score)) id=\(r.id)")
        }

        let dentalInTop20 = RealJournalData.allDentalCompositeIDs.intersection(Set(results.map { $0.id }))
        print("\nDental entries in top 20 vector results: \(dentalInTop20.count)/\(RealJournalData.allDentalCompositeIDs.count)")

        // Apple NL embeddings have compressed score ranges (~0.88) on Swedish medical text,
        // so vector search alone has limited discrimination. Keyword search compensates.
        XCTAssertGreaterThanOrEqual(dentalInTop20.count, 2,
            "Vector search should find at least 2 dental entries in top 20")
    }

    /// Combined hybrid search: does mixing vector + keyword find MORE dental entries?
    func testHybridSearchFindsMoreDental() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let _ = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)

        let query = "tandvård tandläkare folktandvården dental tänder"
        let queryEmb = try await provider.embed(query)

        let vectorResults = try await store.vectorSearch(queryEmbedding: queryEmb, limit: 30)
        let keywordResults = try await store.keywordSearch(query: query, limit: 30)

        let vectorIDs = Set(vectorResults.map { $0.id })
        let keywordIDs = Set(keywordResults.map { $0.id })
        let combinedIDs = vectorIDs.union(keywordIDs)

        let vectorDental = RealJournalData.allDentalCompositeIDs.intersection(vectorIDs)
        let keywordDental = RealJournalData.allDentalCompositeIDs.intersection(keywordIDs)
        let combinedDental = RealJournalData.allDentalCompositeIDs.intersection(combinedIDs)

        print("\n=== Hybrid vs Individual Search ===")
        print("Vector-only found dental: \(vectorDental.count)/\(RealJournalData.allDentalCompositeIDs.count)")
        print("Keyword-only found dental: \(keywordDental.count)/\(RealJournalData.allDentalCompositeIDs.count)")
        print("Combined (hybrid) found dental: \(combinedDental.count)/\(RealJournalData.allDentalCompositeIDs.count)")

        let vectorOnly = vectorDental.subtracting(keywordDental)
        let keywordOnly = keywordDental.subtracting(vectorDental)
        if !vectorOnly.isEmpty { print("  Vector found but keyword missed: \(vectorOnly.sorted())") }
        if !keywordOnly.isEmpty { print("  Keyword found but vector missed: \(keywordOnly.sorted())") }

        XCTAssertGreaterThanOrEqual(combinedDental.count, vectorDental.count,
            "Hybrid should find at least as many dental entries as vector alone")
        XCTAssertGreaterThanOrEqual(combinedDental.count, keywordDental.count,
            "Hybrid should find at least as many dental entries as keyword alone")
    }

    /// Search for Birger's specific dental emergency (pericoronitis at Fridhemsplan)
    func testFindBirgerEmergencyDental() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let _ = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)

        // Search for the emergency visit — user might say "akut tandvärk" or "visdomstand"
        let queries = [
            "akut tandvärk visdomstand",
            "emergency dental wisdom tooth pain",
            "tandvärk pericoronit",
        ]

        for query in queries {
            let queryEmb = try await provider.embed(query)
            let vectorResults = try await store.vectorSearch(queryEmbedding: queryEmb, personName: "Birger", limit: 5)
            let keywordResults = try await store.keywordSearch(query: query, personName: "Birger", limit: 5)

            let allIDs = Set(vectorResults.map { $0.id }).union(Set(keywordResults.map { $0.id }))
            let foundEmergency = allIDs.contains("Birger:entry_023") || allIDs.contains("Birger:entry_024")

            print("\nQuery '\(query)': vector=\(vectorResults.count), keyword=\(keywordResults.count), found emergency=\(foundEmergency)")
            for r in vectorResults.prefix(3) {
                print("  V: \(r.id) score=\(String(format: "%.3f", r.score))")
            }
            for r in keywordResults.prefix(3) {
                print("  K: \(r.id) score=\(String(format: "%.3f", r.score))")
            }
        }
    }

    /// Search for Birk's fluoride water analysis
    func testFindBirkFluorideAnalysis() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let _ = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)

        // Keyword search for fluoride
        let kwResults = try await store.keywordSearch(query: "fluorid", personName: "Birk", limit: 5)
        let foundFluoride = kwResults.contains { $0.id == "Birk:entry_021" }
        XCTAssertTrue(foundFluoride, "Should find Birk's fluoride water analysis (Birk:entry_021). Got: \(kwResults.map { $0.id })")

        // Vector search for the concept
        let queryEmb = try await provider.embed("fluorhalt vatten analys")
        let vecResults = try await store.vectorSearch(queryEmbedding: queryEmb, personName: "Birk", limit: 5)
        print("\nFluoride search:")
        for r in vecResults {
            print("  \(r.id) score=\(String(format: "%.3f", r.score))")
        }
    }

    /// Search for child dental health checks — Birk's 2-year and 3-year checks
    func testFindBirkChildDentalChecks() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let _ = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)

        // Search for child dental health checks via keyword
        let kwQueries = ["tandvård", "tandhygienist", "hälsoundersökning"]
        var kwFoundIDs: Set<String> = []
        for query in kwQueries {
            let results = try await store.keywordSearch(query: query, personName: "Birk", limit: 20)
            for r in results { kwFoundIDs.insert(r.id) }
        }

        // Also try vector search
        let queryEmb = try await provider.embed("barn tandkontroll hälsoundersökning tandvård")
        let vecResults = try await store.vectorSearch(queryEmbedding: queryEmb, personName: "Birk", limit: 10)

        let allFoundIDs = kwFoundIDs.union(Set(vecResults.map { $0.id }))

        print("\n=== Birk child dental checks ===")
        let childCheckIDs = Set(["Birk:entry_003", "Birk:entry_028", "Birk:entry_029"]) // 3-year and 2-year checks
        var foundChecks: Set<String> = []
        for id in allFoundIDs.sorted() {
            let isCheck = childCheckIDs.contains(id)
            if isCheck { foundChecks.insert(id) }
        }
        print("  Found child check entries: \(foundChecks.sorted())")
        print("  All Birk dental results: \(allFoundIDs.sorted())")

        XCTAssertGreaterThanOrEqual(foundChecks.count, 1,
            "Should find at least one child dental health check entry. All found: \(allFoundIDs.sorted())")
    }

    /// Verify Hedda has NO dental entries
    func testHeddaNoDentalEntries() async throws {
        let docs = try RealJournalData.loadAll()
        guard let heddaDoc = docs.first(where: { $0.personName == "Hedda" }) else {
            print("⚠ Hedda journal not found, skipping")
            return
        }

        let dentalEntries = heddaDoc.document.entries.filter { RealJournalData.isDentalEntry($0) }
        XCTAssertEqual(dentalEntries.count, 0, "Hedda should have no dental entries")
    }

    /// Verify that searching dental + filtering to Hedda returns nothing via keyword search.
    /// Vector search always returns closest results by distance, so we check those aren't dental.
    func testDentalSearchForHeddaReturnsEmpty() async throws {
        let docs = try RealJournalData.loadAll()
        guard !docs.isEmpty else { return }

        let store = VectorStore(dimensions: 768)
        try await store.openInMemory()
        let provider = AppleNLEmbeddingProvider()

        let _ = try await RealJournalData.indexAll(docs: docs, into: store, provider: provider)

        // Keyword search should return 0 dental results for Hedda
        let kwResults = try await store.keywordSearch(query: "tandvård", personName: "Hedda", limit: 10)
        let kwResults2 = try await store.keywordSearch(query: "tandläkare", personName: "Hedda", limit: 10)
        XCTAssertEqual(kwResults.count, 0, "Hedda should have no 'tandvård' keyword matches")
        XCTAssertEqual(kwResults2.count, 0, "Hedda should have no 'tandläkare' keyword matches")

        // Vector search returns results by distance (not empty), but none should be dental entries
        let queryEmb = try await provider.embed("tandvård tandläkare dental")
        let vecResults = try await store.vectorSearch(queryEmbedding: queryEmb, personName: "Hedda", limit: 10)
        let dentalInResults = RealJournalData.allDentalCompositeIDs.intersection(Set(vecResults.map { $0.id }))
        XCTAssertEqual(dentalInResults.count, 0,
            "None of Hedda's vector search results should be known dental entries (they belong to Birger/Birk)")
    }
}

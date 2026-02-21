import Foundation
import SQLiteVec

/// Persistent vector + keyword search database for medical record entries.
/// Stored per-profile in ~/Library/Application Support/EirViewer/embeddings/{profileID}.sqlite
actor VectorStore {

    private var db: Database?
    private let dimensions: Int

    init(dimensions: Int = 1024) {
        self.dimensions = dimensions
    }

    // MARK: - Lifecycle

    func open(profileID: UUID) async throws {
        let dir = Self.embeddingsDirectory(for: profileID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("vectors.sqlite").path
        db = try Database(.uri(path))
        try await createSchema()
    }

    /// Open with an in-memory database (for testing)
    func openInMemory() async throws {
        db = try Database(.inMemory)
        try await createSchema()
    }

    func close() {
        db = nil
    }

    var isOpen: Bool { db != nil }

    // MARK: - Schema

    private func createSchema() async throws {
        guard let db else { return }

        try await db.execute("""
            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                person_name TEXT NOT NULL,
                date TEXT,
                category TEXT,
                text TEXT NOT NULL,
                hash TEXT NOT NULL,
                model TEXT NOT NULL,
                embedded_at INTEGER NOT NULL
            )
        """)

        try await db.execute("""
            CREATE TABLE IF NOT EXISTS files (
                path TEXT PRIMARY KEY,
                hash TEXT NOT NULL,
                entry_count INTEGER NOT NULL,
                embedded_at INTEGER NOT NULL
            )
        """)

        // sqlite-vec virtual table for vector search
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_vec USING vec0(
                id TEXT PRIMARY KEY,
                embedding float[\(dimensions)]
            )
        """)

        // FTS5 virtual table for keyword search
        try await db.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
                text,
                id UNINDEXED,
                person_name UNINDEXED,
                category UNINDEXED,
                date UNINDEXED
            )
        """)
    }

    // MARK: - File Tracking

    func fileHash(for path: String) async throws -> String? {
        guard let db else { return nil }
        let rows = try await db.query(
            "SELECT hash FROM files WHERE path = ?",
            params: [path]
        )
        return rows.first?["hash"] as? String
    }

    func updateFileRecord(path: String, hash: String, entryCount: Int) async throws {
        guard let db else { return }
        try await db.execute(
            "INSERT OR REPLACE INTO files (path, hash, entry_count, embedded_at) VALUES (?, ?, ?, ?)",
            params: [path, hash, entryCount, Int(Date().timeIntervalSince1970)]
        )
    }

    // MARK: - Entry Management

    func entryHash(for id: String) async throws -> String? {
        guard let db else { return nil }
        let rows = try await db.query(
            "SELECT hash FROM entries WHERE id = ?",
            params: [id]
        )
        return rows.first?["hash"] as? String
    }

    func insertEntry(
        id: String,
        personName: String,
        date: String?,
        category: String?,
        text: String,
        hash: String,
        model: String,
        embedding: [Float]
    ) async throws {
        guard let db else { return }

        // Upsert metadata
        try await db.execute(
            "INSERT OR REPLACE INTO entries (id, person_name, date, category, text, hash, model, embedded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            params: [id, personName, date ?? "", category ?? "", text, hash, model, Int(Date().timeIntervalSince1970)]
        )

        // Delete old vector if exists, then insert new
        try await db.execute("DELETE FROM entries_vec WHERE id = ?", params: [id])
        try await db.execute(
            "INSERT INTO entries_vec (id, embedding) VALUES (?, ?)",
            params: [id, embedding]
        )

        // Update FTS index
        try await db.execute("DELETE FROM entries_fts WHERE id = ?", params: [id])
        try await db.execute(
            "INSERT INTO entries_fts (id, text, person_name, category, date) VALUES (?, ?, ?, ?, ?)",
            params: [id, text, personName, category ?? "", date ?? ""]
        )
    }

    func clearAll() async throws {
        guard let db else { return }
        try await db.execute("DELETE FROM entries")
        try await db.execute("DELETE FROM entries_vec")
        try await db.execute("DELETE FROM entries_fts")
        try await db.execute("DELETE FROM files")
    }

    // MARK: - Vector Search

    func vectorSearch(queryEmbedding: [Float], personName: String? = nil, category: String? = nil, limit: Int = 24) async throws -> [SearchResult] {
        guard let db else { return [] }

        let rows = try await db.query(
            """
            SELECT e.id, e.person_name, e.date, e.category, e.text,
                   vec_distance_cosine(v.embedding, ?) AS distance
            FROM entries_vec v
            JOIN entries e ON e.id = v.id
            ORDER BY distance ASC
            LIMIT ?
            """,
            params: [queryEmbedding, limit * 2]
        )

        var results: [SearchResult] = []
        for row in rows {
            guard let id = row["id"] as? String,
                  let person = row["person_name"] as? String,
                  let text = row["text"] as? String else { continue }

            if let personName, !person.localizedCaseInsensitiveContains(personName) { continue }
            if let category, let cat = row["category"] as? String, !cat.localizedCaseInsensitiveContains(category) { continue }

            let distance = (row["distance"] as? Double) ?? 2.0
            let score = max(0, 1.0 - distance)

            results.append(SearchResult(
                id: id, personName: person,
                date: row["date"] as? String, category: row["category"] as? String,
                text: text, score: score, source: .vector
            ))

            if results.count >= limit { break }
        }
        return results
    }

    // MARK: - Keyword Search (FTS5)

    func keywordSearch(query: String, personName: String? = nil, category: String? = nil, limit: Int = 24) async throws -> [SearchResult] {
        guard let db else { return [] }

        let ftsQuery = buildFtsQuery(query)
        guard !ftsQuery.isEmpty else { return [] }

        let rows = try await db.query(
            """
            SELECT id, person_name, date, category, text,
                   bm25(entries_fts) AS rank
            FROM entries_fts
            WHERE entries_fts MATCH ?
            ORDER BY rank ASC
            LIMIT ?
            """,
            params: [ftsQuery, limit * 2]
        )

        var results: [SearchResult] = []
        for row in rows {
            guard let id = row["id"] as? String,
                  let person = row["person_name"] as? String,
                  let text = row["text"] as? String else { continue }

            if let personName, !person.localizedCaseInsensitiveContains(personName) { continue }
            if let category, let cat = row["category"] as? String, !cat.localizedCaseInsensitiveContains(category) { continue }

            let rank = (row["rank"] as? Double) ?? 0.0
            let score = 1.0 / (1.0 + max(0, rank))

            results.append(SearchResult(
                id: id, personName: person,
                date: row["date"] as? String, category: row["category"] as? String,
                text: text, score: score, source: .keyword
            ))

            if results.count >= limit { break }
        }
        return results
    }

    // MARK: - Stats

    func indexedEntryCount() async throws -> Int {
        guard let db else { return 0 }
        let rows = try await db.query("SELECT COUNT(*) as cnt FROM entries")
        return (rows.first?["cnt"] as? Int) ?? 0
    }

    // MARK: - Helpers

    private func buildFtsQuery(_ raw: String) -> String {
        let tokens = raw.components(separatedBy: .alphanumerics.inverted).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "" }
        // Use prefix matching (* suffix) so "allergi" matches "allergitest", "tandläkar" matches "tandläkare" etc.
        return tokens.map { "\"\($0)\"*" }.joined(separator: " OR ")
    }

    static func embeddingsDirectory(for profileID: UUID) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("EirViewer")
            .appendingPathComponent("embeddings")
            .appendingPathComponent(profileID.uuidString)
    }
}

// MARK: - Search Result

struct SearchResult {
    let id: String
    let personName: String
    let date: String?
    let category: String?
    let text: String
    let score: Double
    let source: Source

    enum Source {
        case vector
        case keyword
    }
}

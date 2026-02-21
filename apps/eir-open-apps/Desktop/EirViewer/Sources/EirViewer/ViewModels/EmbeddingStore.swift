import Foundation
import CryptoKit

/// Manages the embedding pipeline: indexing records, searching, status tracking.
/// Opt-in: only works when user has enabled embeddings and a model is available.
@MainActor
class EmbeddingStore: ObservableObject {

    @Published var isEnabled = false
    @Published var selectedModelID: String = "apple-nl"
    @Published var isIndexing = false
    @Published var indexProgress: Double = 0
    @Published var indexedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var errorMessage: String?

    let vectorStore = VectorStore(dimensions: 1024) // Will use actual model dims
    private var embeddingProvider: (any EmbeddingProvider)?
    private var indexingTask: Task<Void, Never>?
    private var currentProfileID: UUID?

    private let enabledKey = "eir_embeddings_enabled"
    private let modelKey = "eir_embeddings_model"

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        selectedModelID = UserDefaults.standard.string(forKey: modelKey) ?? "apple-nl"
    }

    // MARK: - Enable / Disable

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled {
            embeddingProvider = nil
        }
    }

    func setModel(_ modelID: String) {
        selectedModelID = modelID
        UserDefaults.standard.set(modelID, forKey: modelKey)
        embeddingProvider = nil // Force reload
    }

    // MARK: - Provider Management

    func loadProvider(modelManager: ModelManager) throws {
        switch selectedModelID {
        case "apple-nl":
            let provider = AppleNLEmbeddingProvider()
            embeddingProvider = provider
        case "qwen3-embedding-0.6b":
            let model = ModelManager.availableModels.first { $0.id == "qwen3-embedding-0.6b" }!
            let path = modelManager.modelPath(for: model)
            guard FileManager.default.fileExists(atPath: path.path) else {
                throw EmbeddingError.modelNotAvailable("Model not downloaded yet")
            }
            embeddingProvider = GGUFEmbeddingProvider(modelPath: path, modelName: model.name, dimensions: model.dimensions)
        default:
            throw EmbeddingError.modelNotAvailable("Unknown model: \(selectedModelID)")
        }
    }

    // MARK: - Open Store

    func openStore(profileID: UUID) {
        currentProfileID = profileID
        guard isEnabled else { return }
        Task {
            do {
                try await vectorStore.open(profileID: profileID)
                indexedCount = try await vectorStore.indexedEntryCount()
            } catch {
                errorMessage = "Failed to open vector store: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Indexing

    func indexDocuments(
        allDocuments: [(personName: String, document: EirDocument)],
        modelManager: ModelManager
    ) {
        guard isEnabled else { return }
        guard !isIndexing else { return }

        isIndexing = true
        indexProgress = 0
        errorMessage = nil

        // Count total entries
        totalCount = allDocuments.reduce(0) { $0 + $1.document.entries.count }

        indexingTask = Task {
            do {
                // Load provider if needed
                if embeddingProvider == nil {
                    try loadProvider(modelManager: modelManager)
                }

                guard let provider = embeddingProvider else {
                    errorMessage = "No embedding provider available"
                    isIndexing = false
                    return
                }

                var processed = 0

                for (personName, doc) in allDocuments {
                    for entry in doc.entries {
                        guard !Task.isCancelled else { break }

                        let text = buildSearchableText(from: entry, personName: personName)
                        let hash = sha256(text)
                        let compositeID = "\(personName):\(entry.id)"

                        // Check if already embedded with same hash
                        let existingHash = try await vectorStore.entryHash(for: compositeID)
                        if existingHash == hash {
                            processed += 1
                            indexProgress = Double(processed) / Double(totalCount)
                            indexedCount = processed
                            continue
                        }

                        // Generate embedding
                        let embedding = try await provider.embed(text)

                        // Pad or truncate to match store dimensions
                        let dims = await vectorStore.isOpen ? 1024 : provider.dimensions
                        let paddedEmbedding = adjustDimensions(embedding, to: dims)

                        // Store with composite ID to avoid collisions across persons
                        try await vectorStore.insertEntry(
                            id: compositeID,
                            personName: personName,
                            date: entry.date,
                            category: entry.category,
                            text: text,
                            hash: hash,
                            model: provider.modelName,
                            embedding: paddedEmbedding
                        )

                        processed += 1
                        indexProgress = Double(processed) / Double(totalCount)
                        indexedCount = processed
                    }
                }
            } catch {
                errorMessage = "Indexing failed: \(error.localizedDescription)"
            }

            isIndexing = false
        }
    }

    func cancelIndexing() {
        indexingTask?.cancel()
        isIndexing = false
    }

    func clearIndex() {
        Task {
            do {
                try await vectorStore.clearAll()
                indexedCount = 0
                indexProgress = 0
            } catch {
                errorMessage = "Failed to clear index: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Search

    /// Hybrid search: 70% vector + 30% keyword. Returns nil if embeddings not available.
    func hybridSearch(
        query: String,
        personName: String? = nil,
        category: String? = nil,
        limit: Int = 20
    ) async -> [SearchResult]? {
        guard isEnabled, let provider = embeddingProvider else { return nil }
        guard await vectorStore.isOpen else { return nil }

        do {
            // Generate query embedding
            let queryEmbedding = try await provider.embed(query)
            let paddedQuery = adjustDimensions(queryEmbedding, to: 1024)

            let candidateCount = limit * 4

            // Vector search
            let vectorResults = try await vectorStore.vectorSearch(
                queryEmbedding: paddedQuery,
                personName: personName,
                category: category,
                limit: candidateCount
            )

            // Keyword search
            let keywordResults = try await vectorStore.keywordSearch(
                query: query,
                personName: personName,
                category: category,
                limit: candidateCount
            )

            // Merge with 70/30 weighting
            return mergeHybrid(
                vector: vectorResults,
                keyword: keywordResults,
                vectorWeight: 0.7,
                textWeight: 0.3,
                minScore: 0.2,
                limit: limit
            )
        } catch {
            return nil // Fall back to keyword search in caller
        }
    }

    // MARK: - Hybrid Merge

    private func mergeHybrid(
        vector: [SearchResult],
        keyword: [SearchResult],
        vectorWeight: Double,
        textWeight: Double,
        minScore: Double,
        limit: Int
    ) -> [SearchResult] {
        struct MergedEntry {
            var id: String
            var personName: String
            var date: String?
            var category: String?
            var text: String
            var vectorScore: Double = 0
            var textScore: Double = 0
        }

        var byID: [String: MergedEntry] = [:]

        for r in vector {
            byID[r.id] = MergedEntry(
                id: r.id, personName: r.personName,
                date: r.date, category: r.category, text: r.text,
                vectorScore: r.score
            )
        }

        for r in keyword {
            if var existing = byID[r.id] {
                existing.textScore = r.score
                byID[r.id] = existing
            } else {
                byID[r.id] = MergedEntry(
                    id: r.id, personName: r.personName,
                    date: r.date, category: r.category, text: r.text,
                    textScore: r.score
                )
            }
        }

        let totalWeight = vectorWeight + textWeight

        return byID.values
            .map { entry -> SearchResult in
                let score = (vectorWeight * entry.vectorScore + textWeight * entry.textScore) / totalWeight
                return SearchResult(
                    id: entry.id, personName: entry.personName,
                    date: entry.date, category: entry.category,
                    text: entry.text, score: score, source: .vector
                )
            }
            .filter { $0.score >= minScore }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Helpers

    private func buildSearchableText(from entry: EirEntry, personName: String) -> String {
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

    private func sha256(_ text: String) -> String {
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func adjustDimensions(_ embedding: [Float], to target: Int) -> [Float] {
        if embedding.count == target { return embedding }
        if embedding.count > target { return Array(embedding.prefix(target)) }
        return embedding + [Float](repeating: 0, count: target - embedding.count)
    }
}

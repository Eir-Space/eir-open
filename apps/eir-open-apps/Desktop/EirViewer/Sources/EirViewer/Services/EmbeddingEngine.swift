import Foundation
import NaturalLanguage

/// Protocol for embedding engines — allows swapping between Apple NL and GGUF models
protocol EmbeddingProvider: Sendable {
    var modelName: String { get }
    var dimensions: Int { get }
    func embed(_ text: String) async throws -> [Float]
    func embedBatch(_ texts: [String]) async throws -> [[Float]]
}

// MARK: - Apple NaturalLanguage Embedding (zero-dependency, on-device)

/// Uses Apple's NLContextualEmbedding (BERT-based, macOS 14+).
/// Supports Swedish via the Latin script model. No download needed (assets fetched on demand by OS).
final class AppleNLEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    let modelName = "apple-nl-contextual"
    let dimensions = 768 // macOS returns 768-dim embeddings

    private var embedding: NLContextualEmbedding?

    func prepare() async throws {
        // Try Swedish first, fall back to English
        let emb = NLContextualEmbedding(language: .swedish)
            ?? NLContextualEmbedding(language: .english)

        guard let emb else {
            throw EmbeddingError.modelNotAvailable("Apple NL contextual embedding not available")
        }

        if !emb.hasAvailableAssets {
            try await emb.requestAssets()
        }
        try emb.load()
        embedding = emb
    }

    func embed(_ text: String) async throws -> [Float] {
        if embedding == nil { try await prepare() }
        guard let emb = embedding else {
            throw EmbeddingError.modelNotLoaded
        }

        let result = try emb.embeddingResult(for: text, language: .swedish)

        // Average-pool all token embeddings into a single sentence vector
        var sum = [Double](repeating: 0.0, count: dimensions)
        var count = 0

        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, range in
            for i in 0..<min(vector.count, dimensions) {
                sum[i] += vector[i]
            }
            count += 1
            return true
        }

        guard count > 0 else {
            throw EmbeddingError.embeddingFailed("No tokens found in text")
        }

        return sum.map { Float($0 / Double(count)) }
    }

    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            results.append(try await embed(text))
        }
        return results
    }
}

// MARK: - GGUF Embedding Provider (placeholder for Phase 2)

/// Runs a GGUF embedding model (e.g. Qwen3-Embedding-0.6B) via llama.cpp.
/// Phase 2: requires llama.cpp SPM dependency and downloaded model file.
final class GGUFEmbeddingProvider: EmbeddingProvider, @unchecked Sendable {
    let modelName: String
    let dimensions: Int
    private let modelPath: URL

    init(modelPath: URL, modelName: String = "gguf-embedding", dimensions: Int = 1024) {
        self.modelPath = modelPath
        self.modelName = modelName
        self.dimensions = dimensions
    }

    func embed(_ text: String) async throws -> [Float] {
        // Phase 2: integrate llama.cpp here
        // For now, this is a placeholder that generates random embeddings for testing
        throw EmbeddingError.modelNotAvailable("GGUF embedding not yet implemented. Use Apple NL embedding.")
    }

    func embedBatch(_ texts: [String]) async throws -> [[Float]] {
        var results: [[Float]] = []
        for text in texts {
            results.append(try await embed(text))
        }
        return results
    }
}

// MARK: - Errors

enum EmbeddingError: LocalizedError {
    case modelNotAvailable(String)
    case modelNotLoaded
    case embeddingFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable(let msg): return "Embedding model not available: \(msg)"
        case .modelNotLoaded: return "Embedding model not loaded"
        case .embeddingFailed(let msg): return "Embedding failed: \(msg)"
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        }
    }
}

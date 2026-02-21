import Foundation

/// Manages downloading and storage of embedding models.
/// Models are stored in ~/Library/Application Support/EirViewer/models/
@MainActor
class ModelManager: ObservableObject {

    struct ModelInfo: Identifiable {
        let id: String
        let name: String
        let description: String
        let url: URL
        let fileName: String
        let sizeBytes: Int64
        let dimensions: Int
        let isBuiltIn: Bool // Apple NL doesn't need download
    }

    static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "apple-nl",
            name: "Apple Neural Engine",
            description: "Built-in macOS embeddings (768d). No download needed. Good quality, supports Swedish.",
            url: URL(string: "builtin://apple-nl")!,
            fileName: "",
            sizeBytes: 0,
            dimensions: 768,
            isBuiltIn: true
        ),
        ModelInfo(
            id: "qwen3-embedding-0.6b",
            name: "Qwen3 Embedding 0.6B",
            description: "Dedicated embedding model (1024d). 639 MB download. Excellent multilingual + Swedish.",
            url: URL(string: "https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/main/qwen3-embedding-0.6b-q8_0.gguf")!,
            fileName: "qwen3-embedding-0.6b-q8_0.gguf",
            sizeBytes: 639_000_000,
            dimensions: 1024,
            isBuiltIn: false
        ),
    ]

    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var downloadError: String?
    @Published var downloadedModels: Set<String> = []

    private var downloadTask: URLSessionDownloadTask?

    init() {
        scanDownloadedModels()
    }

    // MARK: - Model Directory

    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("EirViewer").appendingPathComponent("models")
    }

    func modelPath(for model: ModelInfo) -> URL {
        Self.modelsDirectory.appendingPathComponent(model.fileName)
    }

    func isModelAvailable(_ modelID: String) -> Bool {
        if let model = Self.availableModels.first(where: { $0.id == modelID }) {
            return model.isBuiltIn || downloadedModels.contains(modelID)
        }
        return false
    }

    // MARK: - Scan

    func scanDownloadedModels() {
        var found: Set<String> = []
        for model in Self.availableModels {
            if model.isBuiltIn {
                found.insert(model.id)
            } else if FileManager.default.fileExists(atPath: modelPath(for: model).path) {
                found.insert(model.id)
            }
        }
        downloadedModels = found
    }

    // MARK: - Download

    func downloadModel(_ model: ModelInfo) {
        guard !model.isBuiltIn else { return }
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        let destDir = Self.modelsDirectory
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destPath = destDir.appendingPathComponent(model.fileName)

        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        let task = session.downloadTask(with: model.url) { [weak self] tempURL, response, error in
            Task { @MainActor in
                guard let self else { return }
                self.isDownloading = false

                if let error {
                    self.downloadError = error.localizedDescription
                    return
                }

                guard let tempURL else {
                    self.downloadError = "Download produced no file"
                    return
                }

                do {
                    if FileManager.default.fileExists(atPath: destPath.path) {
                        try FileManager.default.removeItem(at: destPath)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destPath)
                    self.downloadedModels.insert(model.id)
                    self.downloadProgress = 1.0
                } catch {
                    self.downloadError = "Failed to save model: \(error.localizedDescription)"
                }
            }
        }

        // Track progress via KVO
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        // Store observation to keep it alive
        _progressObservation = observation

        task.resume()
        downloadTask = task
    }

    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        downloadProgress = 0
    }

    func deleteModel(_ model: ModelInfo) {
        guard !model.isBuiltIn else { return }
        let path = modelPath(for: model)
        try? FileManager.default.removeItem(at: path)
        downloadedModels.remove(model.id)
    }

    // MARK: - Helpers

    private var _progressObservation: NSKeyValueObservation?

    static func formatSize(_ bytes: Int64) -> String {
        if bytes == 0 { return "Built-in" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

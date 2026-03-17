import SwiftUI

struct LocalModel: Identifiable, Codable, Equatable {
    var id: String          // HuggingFace model ID
    var displayName: String // Short name shown in UI
}

@MainActor
class LocalModelManager: ObservableObject {
    enum ModelStatus: Equatable {
        case notDownloaded
        case downloading
        case loading
        case ready
        case error(String)

        static func == (lhs: ModelStatus, rhs: ModelStatus) -> Bool {
            switch (lhs, rhs) {
            case (.notDownloaded, .notDownloaded),
                 (.downloading, .downloading),
                 (.loading, .loading),
                 (.ready, .ready):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    static let presets: [LocalModel] = [
        LocalModel(id: "mlx-community/Qwen3.5-0.8B-4bit", displayName: "Qwen 3.5 0.8B (Fast)"),
        LocalModel(id: "mlx-community/Qwen3.5-2B-4bit", displayName: "Qwen 3.5 2B (Balanced)"),
        LocalModel(id: "mlx-community/Qwen3.5-4B-4bit", displayName: "Qwen 3.5 4B (Quality)"),
    ]

    @Published var models: [LocalModel] {
        didSet { saveModels() }
    }
    @Published var activeModelId: String?
    @Published var status: ModelStatus = .notDownloaded
    @Published var downloadingModelId: String?
    @Published var downloadProgress: Double = 0

    let service = LocalLLMService()

    private var progressObserver: Any?

    init() {
        if let data = UserDefaults.standard.data(forKey: "eir_local_models"),
           let saved = try? JSONDecoder().decode([LocalModel].self, from: data),
           !saved.isEmpty {
            // Merge in any new presets that were added since last save
            let existingIds = Set(saved.map(\.id))
            let missing = Self.presets.filter { !existingIds.contains($0.id) }
            self.models = saved + missing
        } else {
            self.models = Self.presets
        }
    }

    // MARK: - Model Management

    func addModel(id: String, displayName: String) {
        guard !models.contains(where: { $0.id == id }) else { return }
        models.append(LocalModel(id: id, displayName: displayName))
    }

    func removeModel(_ id: String) {
        if activeModelId == id {
            unloadModel()
        }
        models.removeAll { $0.id == id }
    }

    // MARK: - Loading

    func loadModel(_ id: String) async {
        guard status != .downloading && status != .loading else { return }

        // If a different model is loaded, unload it first
        if activeModelId != nil && activeModelId != id {
            await service.unload()
            activeModelId = nil
            status = .notDownloaded
        }

        downloadingModelId = id
        status = .downloading
        downloadProgress = 0

        progressObserver = NotificationCenter.default.addObserver(
            forName: .localModelDownloadProgress,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let progress = notification.object as? Double else { return }
            Task { @MainActor in
                self?.downloadProgress = progress
                if progress >= 1.0 {
                    self?.status = .loading
                }
            }
        }

        do {
            try await service.loadModel(id: id)
            activeModelId = id
            status = .ready
        } catch {
            status = .error(error.localizedDescription)
        }

        downloadingModelId = nil
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
            progressObserver = nil
        }
    }

    func unloadModel() {
        Task {
            await service.unload()
            activeModelId = nil
            status = .notDownloaded
            downloadProgress = 0
        }
    }

    // MARK: - Convenience

    var isReady: Bool { status == .ready }

    func modelStatus(_ id: String) -> String {
        if activeModelId == id && status == .ready {
            return "active"
        }
        if downloadingModelId == id {
            return "downloading"
        }
        return "idle"
    }

    // MARK: - Persistence

    private func saveModels() {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: "eir_local_models")
        }
    }
}

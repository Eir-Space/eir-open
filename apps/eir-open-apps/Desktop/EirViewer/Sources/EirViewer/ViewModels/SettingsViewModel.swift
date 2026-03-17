import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var providers: [LLMProviderConfig]
    @Published var activeProviderType: LLMProviderType

    // Prompt versioning for on-device models
    @Published var activePromptVersionId: String {
        didSet { UserDefaults.standard.set(activePromptVersionId, forKey: "eir_active_prompt_version") }
    }
    @Published var customPrompts: [PromptVersion] {
        didSet { saveCustomPrompts() }
    }

    var allPromptVersions: [PromptVersion] {
        PromptLibrary.versions + customPrompts
    }

    var activePromptVersion: PromptVersion? {
        allPromptVersions.first(where: { $0.id == activePromptVersionId })
    }

    func addCustomPrompt(name: String, description: String, systemPrompt: String) {
        let prompt = PromptVersion(
            id: "custom_\(UUID().uuidString)",
            name: name,
            description: description,
            systemPrompt: systemPrompt
        )
        customPrompts.append(prompt)
    }

    func updateCustomPrompt(_ prompt: PromptVersion) {
        if let idx = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
            customPrompts[idx] = prompt
        }
    }

    func deleteCustomPrompt(id: String) {
        customPrompts.removeAll { $0.id == id }
        if activePromptVersionId == id {
            activePromptVersionId = PromptLibrary.defaultVersionId
        }
    }

    init() {
        let saved = Self.loadProviders()
        self.providers = saved
        self.activeProviderType = Self.loadActiveProvider()
        self.activePromptVersionId = UserDefaults.standard.string(forKey: "eir_active_prompt_version") ?? PromptLibrary.defaultVersionId
        if let data = UserDefaults.standard.data(forKey: "eir_custom_prompts"),
           let prompts = try? JSONDecoder().decode([PromptVersion].self, from: data) {
            self.customPrompts = prompts
        } else {
            self.customPrompts = []
        }
    }

    var activeProvider: LLMProviderConfig? {
        providers.first(where: { $0.type == activeProviderType })
    }

    func apiKey(for type: LLMProviderType) -> String {
        KeychainService.get(key: "eir_api_key_\(type.rawValue)") ?? ""
    }

    func setApiKey(_ key: String, for type: LLMProviderType) {
        if key.isEmpty {
            KeychainService.delete(key: "eir_api_key_\(type.rawValue)")
        } else {
            KeychainService.set(key: "eir_api_key_\(type.rawValue)", value: key)
        }
        objectWillChange.send()
    }

    func updateProvider(_ config: LLMProviderConfig) {
        if let idx = providers.firstIndex(where: { $0.type == config.type }) {
            providers[idx] = config
        }
        saveProviders()
    }

    func setActiveProvider(_ type: LLMProviderType) {
        activeProviderType = type
        UserDefaults.standard.set(type.rawValue, forKey: "eir_active_provider")
    }

    private func saveProviders() {
        if let data = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(data, forKey: "eir_providers")
        }
    }

    private static func loadProviders() -> [LLMProviderConfig] {
        if let data = UserDefaults.standard.data(forKey: "eir_providers"),
           let saved = try? JSONDecoder().decode([LLMProviderConfig].self, from: data) {
            // Merge in any new provider types added since last save
            let existingTypes = Set(saved.map(\.type))
            let missing = LLMProviderType.allCases.filter { !existingTypes.contains($0) }.map { LLMProviderConfig(type: $0) }
            return saved + missing
        }
        return LLMProviderType.allCases.map { LLMProviderConfig(type: $0) }
    }

    private static func loadActiveProvider() -> LLMProviderType {
        if let raw = UserDefaults.standard.string(forKey: "eir_active_provider"),
           let type = LLMProviderType(rawValue: raw) {
            return type
        }
        return .openai
    }

    private func saveCustomPrompts() {
        if let data = try? JSONEncoder().encode(customPrompts) {
            UserDefaults.standard.set(data, forKey: "eir_custom_prompts")
        }
    }
}

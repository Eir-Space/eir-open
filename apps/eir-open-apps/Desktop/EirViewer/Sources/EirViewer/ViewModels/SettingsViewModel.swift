import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var providers: [LLMProviderConfig]
    @Published var activeProviderType: LLMProviderType

    init() {
        let saved = Self.loadProviders()
        self.providers = saved
        self.activeProviderType = Self.loadActiveProvider()
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
           let providers = try? JSONDecoder().decode([LLMProviderConfig].self, from: data) {
            return providers
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
}

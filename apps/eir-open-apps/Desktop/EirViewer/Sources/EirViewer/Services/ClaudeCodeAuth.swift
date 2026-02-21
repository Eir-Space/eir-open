import Foundation

/// Reads Anthropic API tokens from Claude Code / OpenClaw auth storage
enum ClaudeCodeAuth {

    struct AuthProfiles: Codable {
        let profiles: [String: AuthProfile]?
    }

    struct AuthProfile: Codable {
        let type: String?
        let provider: String?
        let token: String?
    }

    struct ModelsFile: Codable {
        let providers: [String: ProviderEntry]?
    }

    struct ProviderEntry: Codable {
        let apiKey: String?
    }

    /// Attempt to read Anthropic token from known locations
    static func findAnthropicToken() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser

        // 1. Try auth-profiles.json (primary)
        let authProfilesPath = home
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("agents/main/agent/auth-profiles.json")

        if let token = readTokenFromAuthProfiles(at: authProfilesPath) {
            return token
        }

        // 2. Try models.json (fallback)
        let modelsPath = home
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("agents/main/agent/models.json")

        if let token = readTokenFromModels(at: modelsPath) {
            return token
        }

        return nil
    }

    /// Whether a Claude Code installation with Anthropic token exists
    static var isAvailable: Bool {
        findAnthropicToken() != nil
    }

    // MARK: - Private

    private static func readTokenFromAuthProfiles(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let profiles = try? JSONDecoder().decode(AuthProfiles.self, from: data) else {
            return nil
        }

        // Look for any anthropic profile
        for (key, profile) in profiles.profiles ?? [:] {
            if key.hasPrefix("anthropic"), let token = profile.token, !token.isEmpty {
                return token
            }
        }
        return nil
    }

    private static func readTokenFromModels(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode(ModelsFile.self, from: data) else {
            return nil
        }

        if let apiKey = models.providers?["anthropic"]?.apiKey, !apiKey.isEmpty {
            return apiKey
        }
        return nil
    }
}

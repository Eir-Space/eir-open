import Foundation

enum LLMProviderType: String, CaseIterable, Identifiable, Codable {
    case bergetTrial = "Berget AI Trial"
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
    case custom = "Custom"
    case local = "On-Device"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bergetTrial:
            return "Free Trial for Eir"
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .groq:
            return "Groq"
        case .custom:
            return "Custom"
        case .local:
            return "On-Device"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .bergetTrial: return "https://scribe.eir.space/v1"
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .custom, .local: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .bergetTrial: return "openai/gpt-oss-120b"
        case .openai: return "gpt-4.1"
        case .anthropic: return "claude-sonnet-4-5-20250929"
        case .groq: return "llama-3.3-70b-versatile"
        case .custom: return ""
        case .local: return "mlx-community/Qwen3.5-0.8B-4bit"
        }
    }

    var usesOpenAICompat: Bool {
        switch self {
        case .bergetTrial, .openai, .groq, .custom: return true
        case .anthropic, .local: return false
        }
    }

    var isLocal: Bool { self == .local }

    var requiresUserAPIKey: Bool {
        switch self {
        case .bergetTrial, .local:
            return false
        case .openai, .anthropic, .groq, .custom:
            return true
        }
    }

    var usesManagedTrialAccess: Bool { self == .bergetTrial }

    var storageSlug: String {
        switch self {
        case .bergetTrial: return "berget_trial"
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .groq: return "groq"
        case .custom: return "custom"
        case .local: return "local"
        }
    }
}

struct LLMProviderConfig: Codable, Identifiable {
    var id: String { type.rawValue }
    var type: LLMProviderType
    var baseURL: String
    var model: String
    var isEnabled: Bool

    init(type: LLMProviderType) {
        self.type = type
        self.baseURL = type.defaultBaseURL
        self.model = type.defaultModel
        self.isEnabled = false
    }
}

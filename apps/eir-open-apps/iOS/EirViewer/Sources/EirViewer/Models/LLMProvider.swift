import Foundation

enum LLMProviderType: String, CaseIterable, Identifiable, Codable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case groq = "Groq"
    case custom = "Custom"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .anthropic: return "https://api.anthropic.com/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4.1"
        case .anthropic: return "claude-sonnet-4-5-20250929"
        case .groq: return "llama-3.3-70b-versatile"
        case .custom: return ""
        }
    }

    var usesOpenAICompat: Bool {
        switch self {
        case .openai, .groq, .custom: return true
        case .anthropic: return false
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

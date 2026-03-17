import Foundation
import MLXLMCommon
import MLXLLM
import MLX

actor LocalLLMService {
    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?
    private var currentModelId: String?
    private var currentConversationId: UUID?

    var isReady: Bool { modelContainer != nil }

    func loadModel(id: String) async throws {
        // Set GPU cache limit for iOS memory constraints
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)

        let modelConfig = ModelConfiguration(id: id)
        let container = try await LLMModelFactory.shared.loadContainer(configuration: modelConfig) { progress in
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .localModelDownloadProgress,
                    object: progress.fractionCompleted
                )
            }
        }

        modelContainer = container
        currentModelId = id
        chatSession = nil
        currentConversationId = nil
    }

    /// Stream a response for a new user message, reusing KV cache from previous turns.
    /// On first call or when conversationId changes, creates a new ChatSession with the system prompt.
    func streamResponse(
        userMessage: String,
        systemPrompt: String,
        conversationId: UUID,
        onToken: @Sendable @escaping (String) -> Void
    ) async throws -> String {
        guard let container = modelContainer else {
            throw LLMError.noProvider
        }

        // Reset session if conversation changed
        if conversationId != currentConversationId || chatSession == nil {
            chatSession = ChatSession(
                container,
                instructions: systemPrompt,
                generateParameters: GenerateParameters(
                    maxTokens: 1024,
                    temperature: 0.3,
                    topP: 0.9
                ),
                additionalContext: [
                    "enable_thinking": false
                ]
            )
            currentConversationId = conversationId
        }

        guard let session = chatSession else {
            throw LLMError.noProvider
        }

        var accumulated = ""
        var insideThink = false
        for try await chunk in session.streamResponse(to: userMessage) {
            // Filter out any <think>...</think> content that slips through
            var text = chunk
            if text.contains("<think>") {
                insideThink = true
                text = text.components(separatedBy: "<think>").first ?? ""
            }
            if insideThink {
                if text.contains("</think>") {
                    insideThink = false
                    text = text.components(separatedBy: "</think>").last ?? ""
                } else if accumulated.isEmpty || insideThink {
                    continue
                }
            }
            if !text.isEmpty {
                accumulated += text
                onToken(text)
            }
        }

        return accumulated
    }

    /// Reset the chat session (e.g. when starting a new conversation)
    func resetSession() {
        chatSession = nil
        currentConversationId = nil
    }

    func unload() {
        chatSession = nil
        modelContainer = nil
        currentModelId = nil
        currentConversationId = nil
        MLX.GPU.clearCache()
    }
}

extension Notification.Name {
    static let localModelDownloadProgress = Notification.Name("localModelDownloadProgress")
}

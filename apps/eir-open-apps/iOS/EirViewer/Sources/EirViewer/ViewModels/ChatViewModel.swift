import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isStreaming = false
    @Published var errorMessage: String?

    private var streamingTask: Task<Void, Never>?
    private let toolRegistry = ToolRegistry()
    private let maxToolIterations = 5

    func sendMessage(
        document: EirDocument?,
        settingsVM: SettingsViewModel,
        chatThreadStore: ChatThreadStore,
        profileID: UUID,
        agentMemoryStore: AgentMemoryStore,
        localModelManager: LocalModelManager? = nil
    ) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        // Auto-create thread if none selected
        if chatThreadStore.selectedThreadID == nil {
            chatThreadStore.createThread(profileID: profileID)
        }

        let userMessage = ChatMessage(role: .user, content: text)
        chatThreadStore.addMessage(userMessage)
        inputText = ""

        guard let config = settingsVM.activeProvider else {
            errorMessage = "No LLM provider selected. Configure one in Settings."
            return
        }

        // Validate provider readiness
        if config.type.isLocal {
            guard let manager = localModelManager, manager.isReady else {
                errorMessage = "On-device model not loaded. Download it in Settings first."
                return
            }
        } else {
            let apiKey = settingsVM.apiKey(for: config.type)
            guard !apiKey.isEmpty else {
                errorMessage = "No API key set for \(config.type.rawValue). Add one in Settings."
                return
            }
        }

        isStreaming = true
        errorMessage = nil

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        chatThreadStore.addMessage(assistantMessage)
        let assistantIndex = chatThreadStore.messages.count - 1

        let systemPrompt = SystemPrompt.build(
            memory: agentMemoryStore.memory,
            document: document,
            includeToolInstructions: !config.type.isLocal
        )

        // Build LLM messages from conversation history
        var llmMessages: [LLMMessage] = [.system(systemPrompt)]
        for msg in chatThreadStore.messages.dropLast() {
            switch msg.role {
            case .user:
                llmMessages.append(.user(msg.content))
            case .assistant:
                if let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                    llmMessages.append(.assistantToolCalls(msg.content, toolCalls))
                } else {
                    llmMessages.append(.assistant(msg.content))
                }
            case .tool:
                if let toolCallId = msg.toolCallId {
                    llmMessages.append(.toolResult(ToolResult(toolCallId: toolCallId, content: msg.content)))
                }
            case .system:
                break
            }
        }

        let isNewThread = chatThreadStore.messages.count == 2
        let threadID = chatThreadStore.selectedThreadID

        if config.type.isLocal {
            // Local on-device inference — use ChatSession with KV cache for fast responses
            let localService = localModelManager!.service
            let userName = document?.metadata.patient?.name
            let activeVersion = settingsVM.activePromptVersion
            let localPrompt = SystemPrompt.buildLocal(document: document, userName: userName, promptVersion: activeVersion)
            let conversationId = chatThreadStore.selectedThreadID ?? UUID()

            streamingTask = Task {
                do {
                    _ = try await localService.streamResponse(
                        userMessage: text,
                        systemPrompt: localPrompt,
                        conversationId: conversationId
                    ) { [weak chatThreadStore] token in
                        Task { @MainActor in
                            guard let store = chatThreadStore,
                                  assistantIndex < store.messages.count else { return }
                            store.messages[assistantIndex].content += token
                        }
                    }

                    chatThreadStore.persistMessages()

                    // Generate title using local model
                    if isNewThread, let threadID = threadID {
                        self.generateLocalTitle(
                            for: threadID,
                            messages: chatThreadStore.messages,
                            localService: localService,
                            chatThreadStore: chatThreadStore
                        )
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                    if assistantIndex < chatThreadStore.messages.count,
                       chatThreadStore.messages[assistantIndex].content.isEmpty {
                        chatThreadStore.messages.remove(at: assistantIndex)
                        chatThreadStore.persistMessages()
                    }
                }
                self.isStreaming = false
            }
        } else {
            // Cloud provider — full agent loop with tools
            let apiKey = settingsVM.apiKey(for: config.type)
            let service = LLMService(config: config, apiKey: apiKey)
            let tools = ToolRegistry.tools
            let toolContext = ToolContext(document: document, agentMemoryStore: agentMemoryStore)

            streamingTask = Task {
                do {
                    try await runAgentLoop(
                        service: service,
                        messages: &llmMessages,
                        tools: tools,
                        toolContext: toolContext,
                        chatThreadStore: chatThreadStore,
                        assistantIndex: assistantIndex,
                        iteration: 0
                    )

                    chatThreadStore.persistMessages()

                    if isNewThread, let threadID = threadID {
                        self.generateTitle(
                            for: threadID,
                            messages: chatThreadStore.messages,
                            settingsVM: settingsVM,
                            chatThreadStore: chatThreadStore
                        )
                    }
                } catch {
                    self.errorMessage = error.localizedDescription
                    if assistantIndex < chatThreadStore.messages.count,
                       chatThreadStore.messages[assistantIndex].content.isEmpty {
                        chatThreadStore.messages.remove(at: assistantIndex)
                        chatThreadStore.persistMessages()
                    }
                }
                self.isStreaming = false
            }
        }
    }

    // MARK: - Agent Loop

    private func runAgentLoop(
        service: LLMService,
        messages: inout [LLMMessage],
        tools: [ToolDefinition],
        toolContext: ToolContext,
        chatThreadStore: ChatThreadStore,
        assistantIndex: Int,
        iteration: Int
    ) async throws {
        guard iteration < maxToolIterations else { return }

        let result = try await service.streamChatWithTools(
            messages: messages,
            tools: tools
        ) { [weak chatThreadStore] token in
            Task { @MainActor in
                guard let store = chatThreadStore,
                      assistantIndex < store.messages.count else { return }
                store.messages[assistantIndex].content += token
            }
        }

        switch result {
        case .text:
            // Final text response — done
            return

        case .toolCalls(let calls):
            // Store the tool calls on the assistant message
            chatThreadStore.messages[assistantIndex].toolCalls = calls

            // Execute each tool and collect results
            var toolResults: [ToolResult] = []
            for call in calls {
                let toolResult = await toolRegistry.execute(call: call, context: toolContext)
                toolResults.append(toolResult)

                // Add tool result as a hidden message in the thread
                let toolMsg = ChatMessage(role: .tool, content: toolResult.content, toolCallId: toolResult.toolCallId)
                chatThreadStore.addMessage(toolMsg)
            }

            // Add tool call and results to LLM message history
            let assistantContent = chatThreadStore.messages[assistantIndex].content
            messages.append(.assistantToolCalls(assistantContent, calls))
            for tr in toolResults {
                messages.append(.toolResult(tr))
            }

            // Create a new assistant message for the follow-up response
            let followUpMessage = ChatMessage(role: .assistant, content: "")
            chatThreadStore.addMessage(followUpMessage)
            let newIndex = chatThreadStore.messages.count - 1

            // Recurse
            try await runAgentLoop(
                service: service,
                messages: &messages,
                tools: tools,
                toolContext: toolContext,
                chatThreadStore: chatThreadStore,
                assistantIndex: newIndex,
                iteration: iteration + 1
            )
        }
    }

    func stopStreaming() {
        streamingTask?.cancel()
        isStreaming = false
    }

    func newConversation(chatThreadStore: ChatThreadStore, profileID: UUID) {
        chatThreadStore.selectedThreadID = nil
        chatThreadStore.messages = []
        errorMessage = nil
    }

    // MARK: - Title Generation

    private func generateTitle(
        for threadID: UUID,
        messages: [ChatMessage],
        settingsVM: SettingsViewModel,
        chatThreadStore: ChatThreadStore
    ) {
        guard let config = settingsVM.activeProvider else { return }
        let apiKey = settingsVM.apiKey(for: config.type)
        guard !apiKey.isEmpty else { return }

        let userMsg = messages.first { $0.role == .user }?.content ?? ""
        let assistantMsg = messages.first { $0.role == .assistant }?.content ?? ""

        let titleMessages: [(role: String, content: String)] = [
            (role: "system", content: "Generate a short title (3-6 words) for this conversation. Reply with ONLY the title, no quotes."),
            (role: "user", content: userMsg),
            (role: "assistant", content: assistantMsg),
            (role: "user", content: "Generate a short title for this conversation.")
        ]

        let service = LLMService(config: config, apiKey: apiKey)

        Task {
            do {
                let title = try await service.completeChat(messages: titleMessages)
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chatThreadStore.updateThreadTitle(threadID, title: trimmed)
                }
            } catch {
                // Keep default title on failure
            }
        }
    }

    private func generateLocalTitle(
        for threadID: UUID,
        messages: [ChatMessage],
        localService: LocalLLMService,
        chatThreadStore: ChatThreadStore
    ) {
        // Use truncated first user message as title to avoid a slow second inference call
        let userMsg = messages.first { $0.role == .user }?.content ?? "New Chat"
        let words = userMsg.split(separator: " ").prefix(6).joined(separator: " ")
        let title = words.isEmpty ? "New Chat" : words
        chatThreadStore.updateThreadTitle(threadID, title: title)
    }

    // MARK: - Explain Entry

    func explainEntry(
        _ entry: EirEntry,
        document: EirDocument?,
        settingsVM: SettingsViewModel,
        chatThreadStore: ChatThreadStore,
        profileID: UUID,
        agentMemoryStore: AgentMemoryStore,
        localModelManager: LocalModelManager? = nil
    ) {
        // Build a prompt from the entry content
        var prompt = "Explain this medical record:\n\n"
        if let date = entry.date { prompt += "Date: \(date)\n" }
        if let category = entry.category { prompt += "Category: \(category)\n" }
        if let summary = entry.content?.summary { prompt += "Summary: \(summary)\n" }
        if let type = entry.type { prompt += "Type: \(type)\n" }
        if let provider = entry.provider?.name { prompt += "Provider: \(provider)\n" }
        if let details = entry.content?.details { prompt += "Details: \(details)\n" }
        if let notes = entry.content?.notes, !notes.isEmpty {
            prompt += "Notes: \(notes.joined(separator: "; "))\n"
        }

        // Start a new conversation and send the message
        newConversation(chatThreadStore: chatThreadStore, profileID: profileID)
        inputText = prompt
        sendMessage(
            document: document,
            settingsVM: settingsVM,
            chatThreadStore: chatThreadStore,
            profileID: profileID,
            agentMemoryStore: agentMemoryStore,
            localModelManager: localModelManager
        )

        // Switch to chat tab
        NotificationCenter.default.post(name: .navigateToChat, object: nil)
    }
}

extension Notification.Name {
    static let navigateToChat = Notification.Name("navigateToChat")
}

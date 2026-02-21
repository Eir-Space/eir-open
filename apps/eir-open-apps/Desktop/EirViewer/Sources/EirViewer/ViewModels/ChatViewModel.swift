import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var isStreaming = false
    @Published var isThinking = false
    @Published var thinkingTools: [String] = []
    @Published var errorMessage: String?

    private var streamingTask: Task<Void, Never>?
    private let toolRegistry = ToolRegistry()
    private let maxToolIterations = 10
    /// Incremented each agent loop iteration so stale onToken Tasks are ignored
    private var tokenGeneration = 0

    func sendMessage(
        document: EirDocument?,
        settingsVM: SettingsViewModel,
        chatThreadStore: ChatThreadStore,
        profileID: UUID,
        agentMemoryStore: AgentMemoryStore? = nil,
        clinicStore: ClinicStore? = nil,
        profileStore: ProfileStore? = nil,
        embeddingStore: EmbeddingStore? = nil
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

        let apiKey = settingsVM.apiKey(for: config.type)
        guard !apiKey.isEmpty else {
            errorMessage = "No API key set for \(config.type.rawValue). Add one in Settings."
            return
        }

        isStreaming = true
        errorMessage = nil

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        chatThreadStore.addMessage(assistantMessage)
        let assistantIndex = chatThreadStore.messages.count - 1

        // Build allDocuments from all profiles for multi-person access
        var allDocumentsWithIDs: [(profileID: UUID, personName: String, document: EirDocument)] = []
        if let profileStore {
            for profile in profileStore.profiles {
                if let doc = try? EirParser.parse(url: profile.fileURL) {
                    allDocumentsWithIDs.append((profileID: profile.id, personName: profile.displayName, document: doc))
                }
            }
        } else if let document {
            allDocumentsWithIDs.append((profileID: UUID(), personName: "Patient", document: document))
        }
        // SystemPrompt only needs name + document (no profile IDs)
        let allDocuments = allDocumentsWithIDs.map { (personName: $0.personName, document: $0.document) }

        DebugLog.log("sendMessage: provider=\(config.type.rawValue) model=\(config.model)")
        DebugLog.log("sendMessage: allDocuments=\(allDocuments.count) profiles, hasToolSupport=\(agentMemoryStore != nil)")
        DebugLog.log("sendMessage: assistantIndex=\(assistantIndex), total messages=\(chatThreadStore.messages.count)")

        // Build system prompt — use agent memory if available, else legacy
        let systemPrompt: String
        if let memoryStore = agentMemoryStore {
            systemPrompt = SystemPrompt.build(
                memory: memoryStore.memory,
                document: document,
                allDocuments: allDocuments
            )
        } else {
            systemPrompt = SystemPrompt.build(from: document)
        }

        // Build LLM messages from conversation history (excludes tool artifacts)
        var llmMessages = Self.buildLLMHistory(from: chatThreadStore.messages, systemPrompt: systemPrompt)

        let service = LLMService(config: config, apiKey: apiKey)
        let isNewThread = chatThreadStore.messages.count == 2
        let threadID = chatThreadStore.selectedThreadID
        let tools = ToolRegistry.tools
        let hasToolSupport = agentMemoryStore != nil
        let toolContext = agentMemoryStore.map { ToolContext(document: document, allDocuments: allDocumentsWithIDs, agentMemoryStore: $0, clinicStore: clinicStore, embeddingStore: embeddingStore) }

        streamingTask = Task {
            do {
                if hasToolSupport, let toolContext {
                    try await runAgentLoop(
                        service: service,
                        messages: &llmMessages,
                        tools: tools,
                        toolContext: toolContext,
                        chatThreadStore: chatThreadStore,
                        assistantIndex: assistantIndex,
                        iteration: 0
                    )
                } else {
                    // Legacy path — no tools
                    let simpleMessages = llmMessages.map { msg -> (role: String, content: String) in
                        switch msg {
                        case .system(let c): return ("system", c)
                        case .user(let c): return ("user", c)
                        case .assistant(let c): return ("assistant", c)
                        case .assistantToolCalls(let c, _): return ("assistant", c)
                        case .toolResult(let tr): return ("user", tr.content)
                        }
                    }
                    try await service.streamChat(messages: simpleMessages) { [weak chatThreadStore] token in
                        Task { @MainActor in
                            guard let store = chatThreadStore,
                                  assistantIndex < store.messages.count else { return }
                            store.messages[assistantIndex].content += token
                        }
                    }
                }

                // Persist after streaming completes
                chatThreadStore.persistMessages()

                // Generate title for new threads
                if isNewThread, let threadID = threadID {
                    self.generateTitle(
                        for: threadID,
                        messages: chatThreadStore.messages,
                        settingsVM: settingsVM,
                        chatThreadStore: chatThreadStore
                    )
                }
            } catch {
                DebugLog.log("[AgentLoop] ERROR: \(error)")
                self.errorMessage = error.localizedDescription
                self.isThinking = false
                self.thinkingTools = []
                if assistantIndex < chatThreadStore.messages.count,
                   chatThreadStore.messages[assistantIndex].content.isEmpty {
                    chatThreadStore.messages.remove(at: assistantIndex)
                    chatThreadStore.persistMessages()
                }
            }
            self.isStreaming = false
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
        guard iteration < maxToolIterations else {
            DebugLog.log("[AgentLoop] Max iterations (\(maxToolIterations)) reached — forcing final text response")
            // Force a final text-only response by calling WITHOUT tools
            // so the LLM MUST produce text instead of more tool calls
            isThinking = false
            thinkingTools = []
            messages.append(.user("Please provide your final response now based on all the information gathered. Do not make any more tool calls."))

            tokenGeneration += 1
            let currentGeneration = tokenGeneration

            let result = try await service.streamChatWithTools(
                messages: messages,
                tools: [],  // No tools = forced text
                onToken: { [weak self, weak chatThreadStore] token in
                    Task { @MainActor in
                        guard let self, self.tokenGeneration == currentGeneration,
                              let store = chatThreadStore,
                              assistantIndex < store.messages.count else { return }
                        store.messages[assistantIndex].content += token
                    }
                }
            )

            if case .text(let content) = result, assistantIndex < chatThreadStore.messages.count {
                DebugLog.log("[AgentLoop] Forced final response: \(content.count) chars")
                chatThreadStore.messages[assistantIndex].content = content
            }
            return
        }

        DebugLog.log("[AgentLoop] Iteration \(iteration), sending \(messages.count) messages to LLM")
        for (i, msg) in messages.enumerated() {
            switch msg {
            case .system(let c): DebugLog.log("  msg[\(i)] system: \(c.prefix(100))...")
            case .user(let c): DebugLog.log("  msg[\(i)] user: \(c.prefix(200))")
            case .assistant(let c): DebugLog.log("  msg[\(i)] assistant: \(c.prefix(200))")
            case .assistantToolCalls(let c, let calls): DebugLog.log("  msg[\(i)] assistantToolCalls: text=\(c.count) chars, calls=\(calls.map { $0.name })")
            case .toolResult(let tr): DebugLog.log("  msg[\(i)] toolResult[\(tr.toolCallId)]: \(tr.content.prefix(200))")
            }
        }

        // Bump generation so stale onToken Tasks from previous iterations are ignored
        tokenGeneration += 1
        let currentGeneration = tokenGeneration

        // Stream tokens to the visible assistant message (live feedback only)
        let result = try await service.streamChatWithTools(
            messages: messages,
            tools: tools
        ) { [weak self, weak chatThreadStore] token in
            Task { @MainActor in
                // Skip if generation has advanced (stale callback from previous iteration)
                guard let self, self.tokenGeneration == currentGeneration,
                      let store = chatThreadStore,
                      assistantIndex < store.messages.count else { return }
                store.messages[assistantIndex].content += token
            }
        }

        switch result {
        case .text(let fullContent):
            // Final text response — set content directly (authoritative, not from onToken Tasks)
            DebugLog.log("[AgentLoop] Final text response: \(fullContent.count) chars, content: \(fullContent.prefix(300))")
            if assistantIndex < chatThreadStore.messages.count {
                chatThreadStore.messages[assistantIndex].content = fullContent
            }
            isThinking = false
            thinkingTools = []
            return

        case .toolCalls(let accumulatedText, let calls):
            // LLM returned tool calls (possibly with some thinking text before them)
            DebugLog.log("[AgentLoop] Got \(calls.count) tool calls: \(calls.map { $0.name })")
            for call in calls {
                DebugLog.log("[AgentLoop]   tool: \(call.name) id=\(call.id) args=\(call.arguments)")
            }
            if !accumulatedText.isEmpty {
                DebugLog.log("[AgentLoop] Intermediate text before tools: \(accumulatedText.count) chars")
            }

            // Clear visible message and show thinking indicator
            chatThreadStore.messages[assistantIndex].content = ""
            chatThreadStore.messages[assistantIndex].toolCalls = calls

            isThinking = true
            thinkingTools = calls.map { $0.name }

            // Execute each tool
            var toolResults: [ToolResult] = []
            for call in calls {
                thinkingTools = [call.name]
                DebugLog.log("[AgentLoop] Executing tool: \(call.name)")
                let toolResult = await toolRegistry.execute(call: call, context: toolContext)
                DebugLog.log("[AgentLoop] Tool \(call.name) returned \(toolResult.content.count) chars: \(toolResult.content.prefix(300))")
                toolResults.append(toolResult)

                // Store tool result for persistence
                let toolMsg = ChatMessage(role: .tool, content: toolResult.content, toolCallId: toolResult.toolCallId)
                chatThreadStore.addMessage(toolMsg)
            }

            // Add to LLM message history using the authoritative text from StreamResult
            // (NOT from the UI message which depends on async Task completion)
            messages.append(.assistantToolCalls(accumulatedText, calls))
            for tr in toolResults {
                messages.append(.toolResult(tr))
            }

            // Reset the assistant message for the next iteration's response
            chatThreadStore.messages[assistantIndex].toolCalls = nil

            // Recurse with the SAME assistant message — no new bubbles
            try await runAgentLoop(
                service: service,
                messages: &messages,
                tools: tools,
                toolContext: toolContext,
                chatThreadStore: chatThreadStore,
                assistantIndex: assistantIndex,
                iteration: iteration + 1
            )
        }
    }

    /// Start conversational onboarding — sends a greeting that triggers Eir's onboarding flow
    func startOnboarding(
        document: EirDocument?,
        settingsVM: SettingsViewModel,
        chatThreadStore: ChatThreadStore,
        profileID: UUID,
        agentMemoryStore: AgentMemoryStore,
        clinicStore: ClinicStore?,
        profileStore: ProfileStore? = nil,
        embeddingStore: EmbeddingStore? = nil
    ) {
        inputText = "Hey, I'm new here."
        sendMessage(
            document: document,
            settingsVM: settingsVM,
            chatThreadStore: chatThreadStore,
            profileID: profileID,
            agentMemoryStore: agentMemoryStore,
            clinicStore: clinicStore,
            profileStore: profileStore,
            embeddingStore: embeddingStore
        )
    }

    // MARK: - History Builder (static for testability)

    /// Builds LLM message history from stored ChatMessages, excluding tool artifacts.
    /// Tool messages and toolCalls are internal to a single turn's agent loop —
    /// they must NOT be replayed or Anthropic rejects orphaned tool_result blocks.
    nonisolated static func buildLLMHistory(from messages: [ChatMessage], systemPrompt: String) -> [LLMMessage] {
        var result: [LLMMessage] = [.system(systemPrompt)]
        for msg in messages.dropLast() {
            switch msg.role {
            case .user:
                result.append(.user(msg.content))
            case .assistant:
                // Always replay as plain text — never as assistantToolCalls
                result.append(.assistant(msg.content))
            case .tool:
                // Merge tool result into the preceding assistant message so
                // records persist in context for follow-up turns
                if let lastIdx = result.indices.last,
                   case .assistant(let prev) = result[lastIdx] {
                    result[lastIdx] = .assistant(prev + "\n\n[Tool result]\n" + msg.content)
                }
            case .system:
                break // We provide our own system prompt
            }
        }
        return result
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
}

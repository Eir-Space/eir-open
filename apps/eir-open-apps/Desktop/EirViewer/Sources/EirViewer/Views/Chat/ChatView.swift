import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var chatThreadStore: ChatThreadStore
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var agentMemoryStore: AgentMemoryStore
    @EnvironmentObject var clinicStore: ClinicStore
    @EnvironmentObject var embeddingStore: EmbeddingStore

    @State private var hasTriggeredOnboarding = false
    @State private var showContextInfo = false

    private var contextBreakdown: SystemPrompt.ContextBreakdown {
        SystemPrompt.estimateContext(
            memory: agentMemoryStore.memory,
            document: documentVM.document,
            conversationMessages: chatThreadStore.messages
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(chatThreadStore.selectedThread?.title ?? "New Conversation")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)

                Spacer()

                // Context token indicator
                Button {
                    showContextInfo.toggle()
                } label: {
                    let total = contextBreakdown.total
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                            .font(.caption2)
                        Text(total > 1000 ? "\(total / 1000)k tokens" : "\(total) tokens")
                            .font(.caption)
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.divider)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Context usage")
                .popover(isPresented: $showContextInfo) {
                    ContextInfoPopover(breakdown: contextBreakdown)
                }

                if let provider = settingsVM.activeProvider {
                    Text("\(provider.type.rawValue) · \(provider.model)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.divider)
                        .cornerRadius(4)
                }

                Button {
                    if let profileID = profileStore.selectedProfileID {
                        chatVM.newConversation(
                            chatThreadStore: chatThreadStore,
                            profileID: profileID
                        )
                    }
                } label: {
                    Image(systemName: "plus.bubble")
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("New conversation")
            }
            .padding()
            .background(AppColors.card)

            Divider()

            // Messages
            if chatThreadStore.messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    Text("Ask questions about your medical records")
                        .foregroundColor(AppColors.textSecondary)
                    if documentVM.document != nil {
                        Text("Your records are loaded as context for the AI")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    }
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatThreadStore.messages.filter { msg in
                                // Hide tool messages and empty assistant messages
                                // BUT: keep empty assistant messages while streaming (they're being filled)
                                msg.role != .tool &&
                                !(msg.role == .assistant && msg.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatVM.isStreaming)
                            }) { message in
                                ChatBubbleView(
                                    message: message,
                                    userName: agentMemoryStore.userName,
                                    agentName: agentMemoryStore.agentName
                                )
                                    .id(message.id)
                            }

                            // Thinking indicator during tool execution
                            if chatVM.isThinking {
                                ThinkingBubbleView(
                                    agentName: agentMemoryStore.agentName,
                                    toolNames: chatVM.thinkingTools
                                )
                                .id("thinking-indicator")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatThreadStore.messages.count) { _, _ in
                        if chatVM.isThinking {
                            proxy.scrollTo("thinking-indicator", anchor: .bottom)
                        } else if let last = chatThreadStore.messages.last(where: { $0.role != .tool }) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: chatVM.isThinking) { _, thinking in
                        if thinking {
                            proxy.scrollTo("thinking-indicator", anchor: .bottom)
                        }
                    }
                }
            }

            // Error
            if let error = chatVM.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(AppColors.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColors.red)
                    Spacer()
                    Button("Dismiss") { chatVM.errorMessage = nil }
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(AppColors.red.opacity(0.05))
            }

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField("Type a message...", text: $chatVM.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        if !NSEvent.modifierFlags.contains(.shift) {
                            sendMessage()
                        }
                    }

                if chatVM.isStreaming {
                    Button {
                        chatVM.stopStreaming()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(
                                chatVM.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AppColors.textSecondary
                                    : AppColors.primary
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(chatVM.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(12)
            .background(AppColors.card)
        }
        .background(AppColors.background)
        .onAppear {
            triggerOnboardingIfNeeded()
        }
        .onChange(of: agentMemoryStore.isOnboardingNeeded) { _, needed in
            if needed {
                triggerOnboardingIfNeeded()
            }
        }
    }

    private func sendMessage() {
        guard let profileID = profileStore.selectedProfileID else { return }
        chatVM.sendMessage(
            document: documentVM.document,
            settingsVM: settingsVM,
            chatThreadStore: chatThreadStore,
            profileID: profileID,
            agentMemoryStore: agentMemoryStore,
            clinicStore: clinicStore,
            profileStore: profileStore,
            embeddingStore: embeddingStore
        )
    }

    private func triggerOnboardingIfNeeded() {
        guard !hasTriggeredOnboarding,
              agentMemoryStore.isOnboardingNeeded,
              !chatVM.isStreaming,
              chatThreadStore.messages.isEmpty,
              let profileID = profileStore.selectedProfileID,
              settingsVM.activeProvider != nil,
              !settingsVM.apiKey(for: settingsVM.activeProviderType).isEmpty
        else { return }

        hasTriggeredOnboarding = true
        chatVM.startOnboarding(
            document: documentVM.document,
            settingsVM: settingsVM,
            chatThreadStore: chatThreadStore,
            profileID: profileID,
            agentMemoryStore: agentMemoryStore,
            clinicStore: clinicStore,
            profileStore: profileStore,
            embeddingStore: embeddingStore
        )
    }
}

// MARK: - Context Info Popover

struct ContextInfoPopover: View {
    let breakdown: SystemPrompt.ContextBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Context Usage")
                .font(.headline)
                .foregroundColor(AppColors.text)

            VStack(spacing: 6) {
                contextRow("Identity", tokens: breakdown.identity, icon: "person.fill")
                contextRow("User Profile", tokens: breakdown.userProfile, icon: "person.text.rectangle")
                contextRow("Memory", tokens: breakdown.memory, icon: "brain.head.profile")
                contextRow("Skills", tokens: breakdown.skills, icon: "star.fill")
                contextRow("Medical Records", tokens: breakdown.records, icon: "doc.text.fill")
                contextRow("Tool Definitions", tokens: breakdown.toolDefinitions, icon: "wrench.fill")
                contextRow("Conversation", tokens: breakdown.conversation, icon: "bubble.left.fill")
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.text)
                Spacer()
                Text(formatTokens(breakdown.total))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
            }

            Text("Approximate — actual usage varies by model tokenizer")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .frame(width: 280)
    }

    private func contextRow(_ label: String, tokens: Int, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 16)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.text)
            Spacer()
            Text(formatTokens(tokens))
                .font(.caption)
                .foregroundColor(tokens > 0 ? AppColors.textSecondary : AppColors.border)
        }
    }

    private func formatTokens(_ count: Int) -> String {
        if count == 0 { return "—" }
        if count >= 1000 { return String(format: "%.1fk", Double(count) / 1000.0) }
        return "\(count)"
    }
}

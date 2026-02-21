import SwiftUI

struct ChatView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var chatThreadStore: ChatThreadStore
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var agentMemoryStore: AgentMemoryStore

    @State private var showOnboarding = false
    @State private var showConversations = false

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            if chatThreadStore.messages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    Text("Ask questions about your medical records")
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    if documentVM.document != nil {
                        Text("Your records are loaded as context for the AI")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatThreadStore.messages.filter { $0.role != .tool }) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: chatThreadStore.messages.count) { _, _ in
                        if let last = chatThreadStore.messages.last(where: { $0.role != .tool }) {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
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
                    .padding(10)
                    .background(AppColors.divider)
                    .cornerRadius(20)

                if chatVM.isStreaming {
                    Button {
                        chatVM.stopStreaming()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.red)
                    }
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
                    .disabled(chatVM.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.card)
        }
        .background(AppColors.background)
        .navigationTitle(chatThreadStore.selectedThread?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showConversations = true
                    } label: {
                        Image(systemName: "list.bullet")
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
                    }
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                if let provider = settingsVM.activeProvider {
                    Text("\(provider.type.rawValue)")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.divider)
                        .cornerRadius(4)
                }
            }
        }
        .sheet(isPresented: $showConversations) {
            ConversationListSheet()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(
                agentMemoryStore: agentMemoryStore,
                profile: profileStore.selectedProfile
            )
        }
        .onAppear {
            if agentMemoryStore.isOnboardingNeeded {
                showOnboarding = true
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
            agentMemoryStore: agentMemoryStore
        )
    }
}

import SwiftUI

struct ConversationListSheet: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var chatThreadStore: ChatThreadStore
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if chatThreadStore.threads.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start a new conversation to begin chatting")
                    )
                } else {
                    ForEach(chatThreadStore.threads) { thread in
                        Button {
                            chatThreadStore.selectThread(thread.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(thread.title)
                                        .font(.callout)
                                        .fontWeight(thread.id == chatThreadStore.selectedThreadID ? .semibold : .regular)
                                        .foregroundColor(AppColors.text)
                                        .lineLimit(1)

                                    Text(formattedDate(thread.updatedAt))
                                        .font(.caption2)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                if thread.id == chatThreadStore.selectedThreadID {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                chatThreadStore.deleteThread(thread.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let profileID = profileStore.selectedProfileID {
                            chatVM.newConversation(
                                chatThreadStore: chatThreadStore,
                                profileID: profileID
                            )
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

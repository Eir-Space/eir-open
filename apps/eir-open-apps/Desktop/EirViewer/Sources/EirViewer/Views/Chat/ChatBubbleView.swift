import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    var userName: String?
    var agentName: String?

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? (userName ?? "You") : (agentName ?? "Assistant"))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    let parts = parseJournalEntryTags(message.content)
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        switch part {
                        case .text(let text):
                            Text(markdownAttributed(text))
                                .textSelection(.enabled)
                        case .journalRef(let entryID):
                            JournalEntryLink(entryID: entryID)
                        }
                    }
                }
                .padding(12)
                .background(isUser ? AppColors.primary : AppColors.card)
                .foregroundColor(isUser ? .white : AppColors.text)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isUser ? Color.clear : AppColors.border, lineWidth: 1)
                )

                Text(formattedTime)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private func markdownAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

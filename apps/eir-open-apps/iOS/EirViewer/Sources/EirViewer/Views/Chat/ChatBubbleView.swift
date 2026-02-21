import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 6) {
                    let parts = parseJournalEntryTags(message.content)
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                        switch part {
                        case .text(let text):
                            Text(text)
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

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}

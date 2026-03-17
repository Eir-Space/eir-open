import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @EnvironmentObject var chatVM: ChatViewModel

    var isUser: Bool { message.role == .user }
    var isEmpty: Bool { message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 6) {
                    if !isUser && isEmpty && chatVM.isStreaming {
                        ThinkingIndicator()
                    } else {
                        let parts = parseJournalEntryTags(message.content)
                        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                            switch part {
                            case .text(let text):
                                MarkdownText(text)
                                    .textSelection(.enabled)
                            case .journalRef(let entryID):
                                JournalEntryLink(entryID: entryID)
                            }
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

// MARK: - Markdown Text

private struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        if let attributed = try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(source)
        }
    }
}

// MARK: - Thinking Indicator

private struct ThinkingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(AppColors.textSecondary)
                    .frame(width: 7, height: 7)
                    .opacity(dotOpacity(for: i))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let offset = Double(index) * 0.3
        let value = sin((phase + offset) * .pi)
        return 0.3 + 0.7 * max(0, value)
    }
}

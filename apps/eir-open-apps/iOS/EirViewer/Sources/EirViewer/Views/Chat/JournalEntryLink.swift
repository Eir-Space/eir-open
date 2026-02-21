import SwiftUI

// MARK: - Content Parsing

enum ChatContentPart {
    case text(String)
    case journalRef(entryID: String)
}

func parseJournalEntryTags(_ text: String) -> [ChatContentPart] {
    let pattern = #"<JOURNAL_ENTRY\s+id="([^"]+)"\s*/>"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.text(text)]
    }

    var parts: [ChatContentPart] = []
    var lastEnd = text.startIndex

    let nsRange = NSRange(text.startIndex..., in: text)
    regex.enumerateMatches(in: text, range: nsRange) { match, _, _ in
        guard let match = match,
              let fullRange = Range(match.range, in: text),
              let idRange = Range(match.range(at: 1), in: text) else { return }

        // Text before this tag
        if lastEnd < fullRange.lowerBound {
            let preceding = String(text[lastEnd..<fullRange.lowerBound])
            if !preceding.isEmpty {
                parts.append(.text(preceding))
            }
        }

        parts.append(.journalRef(entryID: String(text[idRange])))
        lastEnd = fullRange.upperBound
    }

    // Remaining text after last tag
    if lastEnd < text.endIndex {
        let remaining = String(text[lastEnd...])
        if !remaining.isEmpty {
            parts.append(.text(remaining))
        }
    }

    return parts
}

// MARK: - Journal Entry Link View

struct JournalEntryLink: View {
    let entryID: String
    @EnvironmentObject var documentVM: DocumentViewModel

    var entry: EirEntry? {
        documentVM.document?.entries.first { $0.id == entryID }
    }

    var body: some View {
        if let entry = entry {
            Button {
                NotificationCenter.default.post(
                    name: .navigateToJournalEntry,
                    object: entry.id
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppColors.primary)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.category ?? "Journal Entry")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.text)
                        Text(entry.date ?? "")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                        if let summary = entry.content?.summary {
                            Text(summary)
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(8)
                .background(AppColors.primarySoft)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            // Fallback: entry not found
            Text("[\(entryID)]")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let navigateToJournalEntry = Notification.Name("navigateToJournalEntry")
}

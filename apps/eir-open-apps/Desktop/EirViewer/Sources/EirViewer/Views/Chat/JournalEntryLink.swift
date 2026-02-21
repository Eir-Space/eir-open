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

        if lastEnd < fullRange.lowerBound {
            let preceding = String(text[lastEnd..<fullRange.lowerBound])
            if !preceding.isEmpty {
                parts.append(.text(preceding))
            }
        }

        parts.append(.journalRef(entryID: String(text[idRange])))
        lastEnd = fullRange.upperBound
    }

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
    @EnvironmentObject var profileStore: ProfileStore

    /// Parse composite ID "PersonName::entry_id", "UUID::entry_id", or plain "entry_id"
    private var parsed: (personHint: String?, rawID: String) {
        let parts = entryID.components(separatedBy: "::")
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return (nil, entryID)
    }

    /// Search profiles for the entry, using person name or UUID hint from composite ID
    var match: (entry: EirEntry, profileID: UUID)? {
        let (personHint, rawID) = parsed

        if let personHint {
            // Try UUID match first
            if let uuid = UUID(uuidString: personHint),
               let profile = profileStore.profiles.first(where: { $0.id == uuid }),
               let doc = try? EirParser.parse(url: profile.fileURL),
               let entry = doc.entries.first(where: { $0.id == rawID }) {
                return (entry, profile.id)
            }

            // Try person name match — check both directions for partial matches
            for profile in profileStore.profiles {
                let name = profile.displayName
                if name.localizedCaseInsensitiveContains(personHint)
                    || personHint.localizedCaseInsensitiveContains(name) {
                    if let doc = try? EirParser.parse(url: profile.fileURL),
                       let entry = doc.entries.first(where: { $0.id == rawID }) {
                        return (entry, profile.id)
                    }
                }
            }
        }

        // Fallback: search all profiles
        for profile in profileStore.profiles {
            if let doc = try? EirParser.parse(url: profile.fileURL),
               let entry = doc.entries.first(where: { $0.id == rawID }) {
                return (entry, profile.id)
            }
        }
        return nil
    }

    var body: some View {
        if let match = match {
            let entry = match.entry
            let isOtherProfile = match.profileID != profileStore.selectedProfileID
            Button {
                NotificationCenter.default.post(
                    name: .navigateToJournalEntry,
                    object: NavigateToEntry(entryID: entry.id, profileID: match.profileID)
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .foregroundColor(AppColors.primary)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(entry.category ?? "Journal Entry")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.text)
                            if isOtherProfile,
                               let name = profileStore.profiles.first(where: { $0.id == match.profileID })?.displayName {
                                Text("(\(name))")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.primary)
                            }
                        }
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
            Text("[\(entryID)]")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

/// Payload for journal entry navigation (includes which profile owns the entry)
struct NavigateToEntry {
    let entryID: String
    let profileID: UUID
}

// MARK: - Notification

extension Notification.Name {
    static let navigateToJournalEntry = Notification.Name("navigateToJournalEntry")
    static let explainEntryWithAI = Notification.Name("explainEntryWithAI")
}

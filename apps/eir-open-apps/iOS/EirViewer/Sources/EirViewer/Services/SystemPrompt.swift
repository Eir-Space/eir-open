import Foundation

enum SystemPrompt {

    /// Build the full system prompt from agent memory files + medical records
    static func build(
        memory: AgentMemory,
        document: EirDocument?,
        includeToolInstructions: Bool = true
    ) -> String {
        var sections: [String] = []

        // 1. Identity (SOUL.md)
        sections.append(memory.soul)

        // 2. User Profile (USER.md)
        sections.append("# User Profile\n\n\(memory.user)")

        // 3. Session Memory (MEMORY.md)
        sections.append("# Memory\n\n\(memory.memory)")

        // 4. Available Skills (AGENTS.md)
        sections.append(memory.agents)

        // 5. Tool instructions
        if includeToolInstructions {
            sections.append("""
            # Tool Usage

            You have access to tools that let you search records, retrieve details, and update your memory. \
            When a user asks about specific conditions, dates, or entries, use `search_records` to find relevant data. \
            Use `get_record_detail` when you need the full content of a specific entry. \
            Use `update_memory` to remember important facts for future conversations. \
            Use `update_user_profile` when you learn new information about the user.

            Always cite specific entries using `<JOURNAL_ENTRY id="ENTRY_ID"/>` format — this renders as a clickable link.
            """)
        }

        // 6. Medical Records Context
        if let doc = document {
            sections.append(buildRecordsContext(from: doc))
        }

        // 7. Response Guidelines
        sections.append("""
        # Response Guidelines

        - Respond in the same language the user writes in (Swedish or English)
        - Use `<JOURNAL_ENTRY id="ENTRY_ID"/>` to cite specific entries — these become clickable links
        - Be concise by default; expand when asked for details
        - Flag findings that may need professional attention
        - Never provide definitive diagnoses — explain, analyze, and recommend follow-up
        - If unsure, say so rather than guessing about medical matters
        """)

        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Legacy build method for backward compatibility (title generation etc.)
    static func build(from document: EirDocument?) -> String {
        let defaultMemory = AgentMemory(
            soul: AgentDefaults.defaultSoul,
            user: AgentDefaults.defaultUser,
            memory: AgentDefaults.defaultMemory,
            agents: AgentDefaults.defaultAgents
        )
        return build(memory: defaultMemory, document: document, includeToolInstructions: false)
    }

    // MARK: - Records Context

    private static func buildRecordsContext(from doc: EirDocument) -> String {
        var context = "# Medical Records\n\n"

        // Patient metadata
        if let patient = doc.metadata.patient {
            context += "**Patient**: \(patient.name ?? "Unknown")"
            if let dob = patient.birthDate { context += ", born \(dob)" }
            if let pnr = patient.personalNumber { context += " (\(pnr))" }
            context += "\n"
        }

        if let info = doc.metadata.exportInfo {
            if let total = info.totalEntries {
                context += "**Total entries**: \(total)\n"
            }
            if let range = info.dateRange {
                context += "**Date range**: \(range.start ?? "?") to \(range.end ?? "?")\n"
            }
            if let providers = info.healthcareProviders, !providers.isEmpty {
                context += "**Providers**: \(providers.joined(separator: ", "))\n"
            }
        }

        // Entries with tiered detail
        let entries = doc.entries
        if entries.isEmpty { return context }

        context += "\n## Journal Entries (\(entries.count) total)\n\n"

        // First 100: full details
        let fullDetailEntries = entries.prefix(100)
        for entry in fullDetailEntries {
            context += formatEntryFull(entry)
        }

        // Remaining: summary only
        if entries.count > 100 {
            context += "\n## Earlier Entries (summary)\n\n"
            let summaryEntries = entries.dropFirst(100)
            for entry in summaryEntries {
                context += formatEntrySummary(entry)
            }
        }

        return context
    }

    private static func formatEntryFull(_ entry: EirEntry) -> String {
        var text = "---\n"
        text += "ID: \(entry.id)\n"
        text += "Date: \(entry.date ?? "Unknown")"
        if let time = entry.time { text += " \(time)" }
        text += "\nCategory: \(entry.category ?? "Unknown")"
        if let type = entry.type { text += "\nType: \(type)" }
        if let provider = entry.provider?.name { text += "\nProvider: \(provider)" }
        if let person = entry.responsiblePerson {
            text += "\nResponsible: \(person.name ?? "?") (\(person.role ?? "?"))"
        }
        if let status = entry.status { text += "\nStatus: \(status)" }
        if let summary = entry.content?.summary { text += "\nSummary: \(summary)" }
        if let details = entry.content?.details { text += "\nDetails: \(details)" }
        if let notes = entry.content?.notes, !notes.isEmpty {
            text += "\nNotes: \(notes.joined(separator: "; "))"
        }
        text += "\n"
        return text
    }

    private static func formatEntrySummary(_ entry: EirEntry) -> String {
        var text = "- \(entry.date ?? "?") [\(entry.category ?? "?")] "
        if let provider = entry.provider?.name { text += "@ \(provider) " }
        if let summary = entry.content?.summary { text += "— \(summary)" }
        text += " (ID: \(entry.id))\n"
        return text
    }
}

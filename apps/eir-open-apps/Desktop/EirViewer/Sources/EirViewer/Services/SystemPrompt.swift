import Foundation

enum SystemPrompt {

    /// Build the full system prompt from agent memory files + medical records
    static func build(
        memory: AgentMemory,
        document: EirDocument?,
        allDocuments: [(personName: String, document: EirDocument)] = [],
        includeToolInstructions: Bool = true
    ) -> String {
        var sections: [String] = []

        // 1. Identity (SOUL.md) — includes tools, vibe, boundaries
        sections.append(memory.soul)

        // 2. User Profile (USER.md)
        sections.append(memory.user)

        // 3. Session Memory (MEMORY.md)
        if !memory.memory.contains("Nothing recorded yet") {
            sections.append(memory.memory)
        }

        // 4. Available Skills (AGENTS.md)
        sections.append(memory.agents)

        // 5. Current date/time in user's timezone
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.timeZone = TimeZone.current
        let tz = TimeZone.current
        let tzName = tz.localizedName(for: .standard, locale: Locale.current) ?? tz.identifier
        sections.append("# Current Date & Time\n\nToday is **\(df.string(from: Date()))** (\(tzName), UTC\(tz.secondsFromGMT() >= 0 ? "+" : "")\(tz.secondsFromGMT() / 3600))")

        // 6. Medical Records — metadata overview, use get_medical_records tool for full data
        if !allDocuments.isEmpty {
            sections.append(buildAllRecordsMetadata(from: allDocuments))
        } else if let doc = document {
            sections.append(buildRecordsMetadata(from: doc))
        }

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

    // MARK: - Records Metadata (lightweight — details via tools)

    private static func buildAllRecordsMetadata(from allDocuments: [(personName: String, document: EirDocument)]) -> String {
        var context = "# Medical Records Available\n\n"
        let totalEntries = allDocuments.reduce(0) { $0 + $1.document.entries.count }
        context += "Records are loaded for **\(allDocuments.count) \(allDocuments.count == 1 ? "person" : "people")** (\(totalEntries) total entries). "
        if totalEntries > 100 {
            context += "Use `get_medical_records` to get a summary index, then `get_entry_details` with specific entry IDs to read full content. You can also filter by `category` or `search` keyword.\n\n"
        } else {
            context += "Use `get_medical_records` to retrieve records with full details (optionally filtered by person).\n\n"
        }

        for (personName, doc) in allDocuments {
            context += "### \(personName)\n"
            if let patient = doc.metadata.patient {
                if let dob = patient.birthDate { context += "- Born: \(dob)\n" }
            }
            context += "- Entries: \(doc.entries.count)\n"
            if let info = doc.metadata.exportInfo, let range = info.dateRange {
                context += "- Date range: \(range.start ?? "?") to \(range.end ?? "?")\n"
            }
            // Category breakdown
            if !doc.entries.isEmpty {
                var categoryCounts: [String: Int] = [:]
                for entry in doc.entries {
                    categoryCounts[entry.category ?? "Other", default: 0] += 1
                }
                let topCategories = categoryCounts.sorted(by: { $0.value > $1.value }).prefix(5)
                context += "- Top categories: \(topCategories.map { "\($0.key) (\($0.value))" }.joined(separator: ", "))\n"
            }
            context += "\n"
        }

        return context
    }

    private static func buildRecordsMetadata(from doc: EirDocument) -> String {
        var context = "# Medical Records Available\n\n"
        context += "Records are loaded. Use the `get_medical_records` tool to retrieve ALL records with full details.\n\n"

        if let patient = doc.metadata.patient {
            context += "**Patient**: \(patient.name ?? "Unknown")"
            if let dob = patient.birthDate { context += ", born \(dob)" }
            context += "\n"
        }

        let entries = doc.entries
        context += "**Total entries**: \(entries.count)\n"

        if let info = doc.metadata.exportInfo {
            if let range = info.dateRange {
                context += "**Date range**: \(range.start ?? "?") to \(range.end ?? "?")\n"
            }
            if let providers = info.healthcareProviders, !providers.isEmpty {
                context += "**Providers**: \(providers.joined(separator: ", "))\n"
            }
        }

        // Category breakdown so the agent knows what's there
        if !entries.isEmpty {
            var categoryCounts: [String: Int] = [:]
            for entry in entries {
                categoryCounts[entry.category ?? "Other", default: 0] += 1
            }
            context += "\n**Categories**:\n"
            for (cat, count) in categoryCounts.sorted(by: { $0.value > $1.value }) {
                context += "- \(cat): \(count)\n"
            }
        }

        return context
    }

    // MARK: - Token Estimation

    struct ContextBreakdown {
        var identity: Int = 0
        var userProfile: Int = 0
        var memory: Int = 0
        var skills: Int = 0
        var records: Int = 0
        var toolDefinitions: Int = 0
        var conversation: Int = 0

        var total: Int { identity + userProfile + memory + skills + records + toolDefinitions + conversation }
    }

    /// Approximate token count (~4 chars per token)
    static func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    /// Break down token usage across context components
    static func estimateContext(
        memory: AgentMemory,
        document: EirDocument?,
        conversationMessages: [ChatMessage] = [],
        tools: [ToolDefinition] = ToolRegistry.tools
    ) -> ContextBreakdown {
        var b = ContextBreakdown()
        b.identity = estimateTokens(memory.soul)
        b.userProfile = estimateTokens(memory.user)
        if !memory.memory.contains("Nothing recorded yet") {
            b.memory = estimateTokens(memory.memory)
        }
        b.skills = estimateTokens(memory.agents)
        if let doc = document {
            b.records = estimateTokens(buildRecordsMetadata(from: doc))
        }
        // Tool definitions JSON ~150 tokens per tool
        b.toolDefinitions = tools.count * 150
        // Conversation history
        let convText = conversationMessages.map { $0.content }.joined()
        b.conversation = estimateTokens(convText)
        return b
    }
}

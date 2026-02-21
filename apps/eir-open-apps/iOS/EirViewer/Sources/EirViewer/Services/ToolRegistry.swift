import Foundation

struct ToolContext {
    let document: EirDocument?
    let agentMemoryStore: AgentMemoryStore
}

actor ToolRegistry {

    // MARK: - Tool Definitions

    static let tools: [ToolDefinition] = [
        ToolDefinition(
            name: "search_records",
            description: "Search medical records by keyword, date range, or category. Returns matching entries with IDs for citation.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "query": ToolProperty(type: "string", description: "Search keyword or phrase to match against summaries, details, and notes"),
                    "category": ToolProperty(type: "string", description: "Filter by category (e.g. Anteckning, Lab, Recept, Vaccinationer, Diagnoser, Remisser)"),
                    "from_date": ToolProperty(type: "string", description: "Start date filter in yyyy-MM-dd format"),
                    "to_date": ToolProperty(type: "string", description: "End date filter in yyyy-MM-dd format"),
                ],
                required: nil
            )
        ),
        ToolDefinition(
            name: "get_record_detail",
            description: "Get the full details of a specific medical record entry by its ID.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "entry_id": ToolProperty(type: "string", description: "The exact entry ID to retrieve"),
                ],
                required: ["entry_id"]
            )
        ),
        ToolDefinition(
            name: "summarize_health",
            description: "Generate a structured health summary from the medical records.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "focus": ToolProperty(
                        type: "string",
                        description: "Area to focus the summary on",
                        enum: ["medications", "recent", "labs", "diagnoses", "all"]
                    ),
                ],
                required: nil
            )
        ),
        ToolDefinition(
            name: "update_memory",
            description: "Update the agent's long-term memory with important facts to remember across conversations. Use sparingly for key health context.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "content": ToolProperty(type: "string", description: "The full updated memory content in markdown format"),
                ],
                required: ["content"]
            )
        ),
        ToolDefinition(
            name: "update_user_profile",
            description: "Update a section of the user's health profile with new information learned during conversation.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "section": ToolProperty(
                        type: "string",
                        description: "Which section to update",
                        enum: ["basic_info", "health_goals", "conditions", "preferences"]
                    ),
                    "content": ToolProperty(type: "string", description: "The updated content for this section"),
                ],
                required: ["section", "content"]
            )
        ),
    ]

    // MARK: - Execution

    func execute(call: ToolCall, context: ToolContext) async -> ToolResult {
        guard let args = parseArguments(call.arguments) else {
            return ToolResult(toolCallId: call.id, content: "Error: Could not parse tool arguments")
        }

        switch call.name {
        case "search_records":
            return await searchRecords(args: args, document: context.document, callId: call.id)
        case "get_record_detail":
            return getRecordDetail(args: args, document: context.document, callId: call.id)
        case "summarize_health":
            return summarizeHealth(args: args, document: context.document, callId: call.id)
        case "update_memory":
            return await updateMemory(args: args, store: context.agentMemoryStore, callId: call.id)
        case "update_user_profile":
            return await updateUserProfile(args: args, store: context.agentMemoryStore, callId: call.id)
        default:
            return ToolResult(toolCallId: call.id, content: "Error: Unknown tool '\(call.name)'")
        }
    }

    // MARK: - Tool Implementations

    private func searchRecords(args: [String: Any], document: EirDocument?, callId: String) async -> ToolResult {
        guard let doc = document else {
            return ToolResult(toolCallId: callId, content: "No medical records loaded.")
        }

        let query = (args["query"] as? String)?.lowercased()
        let category = args["category"] as? String
        let fromDate = args["from_date"] as? String
        let toDate = args["to_date"] as? String

        var results = doc.entries

        // Filter by category
        if let category {
            results = results.filter { ($0.category ?? "").localizedCaseInsensitiveContains(category) }
        }

        // Filter by date range
        if let fromDate {
            results = results.filter { ($0.date ?? "") >= fromDate }
        }
        if let toDate {
            results = results.filter { ($0.date ?? "") <= toDate }
        }

        // Filter by keyword
        if let query, !query.isEmpty {
            results = results.filter { entry in
                let searchable = [
                    entry.content?.summary,
                    entry.content?.details,
                    entry.content?.notes?.joined(separator: " "),
                    entry.type,
                    entry.provider?.name,
                    entry.responsiblePerson?.name,
                    entry.tags?.joined(separator: " "),
                ].compactMap { $0 }.joined(separator: " ").lowercased()
                return searchable.contains(query)
            }
        }

        // Limit results
        let limited = results.prefix(20)

        if limited.isEmpty {
            return ToolResult(toolCallId: callId, content: "No matching records found.")
        }

        var output = "Found \(results.count) matching records"
        if results.count > 20 { output += " (showing first 20)" }
        output += ":\n\n"

        for entry in limited {
            output += "- **\(entry.date ?? "?")** [\(entry.category ?? "?")]"
            if let summary = entry.content?.summary {
                output += " — \(summary)"
            }
            output += " `<JOURNAL_ENTRY id=\"\(entry.id)\"/>`\n"
        }

        return ToolResult(toolCallId: callId, content: output)
    }

    private func getRecordDetail(args: [String: Any], document: EirDocument?, callId: String) -> ToolResult {
        guard let doc = document else {
            return ToolResult(toolCallId: callId, content: "No medical records loaded.")
        }

        guard let entryId = args["entry_id"] as? String else {
            return ToolResult(toolCallId: callId, content: "Error: entry_id is required")
        }

        guard let entry = doc.entries.first(where: { $0.id == entryId }) else {
            return ToolResult(toolCallId: callId, content: "No entry found with ID: \(entryId)")
        }

        var output = "## Record Detail\n\n"
        output += "- **ID**: \(entry.id)\n"
        output += "- **Date**: \(entry.date ?? "Unknown")"
        if let time = entry.time { output += " \(time)" }
        output += "\n"
        output += "- **Category**: \(entry.category ?? "Unknown")\n"
        if let type = entry.type { output += "- **Type**: \(type)\n" }
        if let status = entry.status { output += "- **Status**: \(status)\n" }
        if let provider = entry.provider {
            output += "- **Provider**: \(provider.name ?? "?")"
            if let region = provider.region { output += " (\(region))" }
            output += "\n"
        }
        if let person = entry.responsiblePerson {
            output += "- **Responsible**: \(person.name ?? "?") (\(person.role ?? "?"))\n"
        }
        if let summary = entry.content?.summary {
            output += "\n### Summary\n\(summary)\n"
        }
        if let details = entry.content?.details {
            output += "\n### Details\n\(details)\n"
        }
        if let notes = entry.content?.notes, !notes.isEmpty {
            output += "\n### Notes\n"
            for note in notes { output += "- \(note)\n" }
        }
        if let tags = entry.tags, !tags.isEmpty {
            output += "\n**Tags**: \(tags.joined(separator: ", "))\n"
        }

        return ToolResult(toolCallId: callId, content: output)
    }

    private func summarizeHealth(args: [String: Any], document: EirDocument?, callId: String) -> ToolResult {
        guard let doc = document else {
            return ToolResult(toolCallId: callId, content: "No medical records loaded.")
        }

        let focus = args["focus"] as? String ?? "all"
        var output = "## Health Summary"
        if focus != "all" { output += " (\(focus))" }
        output += "\n\n"

        // Patient info
        if let patient = doc.metadata.patient {
            output += "**Patient**: \(patient.name ?? "Unknown")\n"
            if let dob = patient.birthDate { output += "**Born**: \(dob)\n" }
        }
        output += "**Total entries**: \(doc.entries.count)\n\n"

        switch focus {
        case "medications", "recept":
            let meds = doc.entries.filter { ($0.category ?? "").localizedCaseInsensitiveContains("recept")
                || ($0.category ?? "").localizedCaseInsensitiveContains("läkemedel") }
            output += "### Medications (\(meds.count) entries)\n"
            for entry in meds.prefix(30) {
                output += "- \(entry.date ?? "?") — \(entry.content?.summary ?? "No summary") `<JOURNAL_ENTRY id=\"\(entry.id)\"/>`\n"
            }

        case "recent":
            output += "### Recent Entries (last 20)\n"
            for entry in doc.entries.prefix(20) {
                output += "- \(entry.date ?? "?") [\(entry.category ?? "?")] — \(entry.content?.summary ?? "No summary") `<JOURNAL_ENTRY id=\"\(entry.id)\"/>`\n"
            }

        case "labs", "lab":
            let labs = doc.entries.filter { ($0.category ?? "").localizedCaseInsensitiveContains("lab") }
            output += "### Lab Results (\(labs.count) entries)\n"
            for entry in labs.prefix(30) {
                output += "- \(entry.date ?? "?") — \(entry.content?.summary ?? "No summary") `<JOURNAL_ENTRY id=\"\(entry.id)\"/>`\n"
            }

        case "diagnoses", "diagnoser":
            let diags = doc.entries.filter { ($0.category ?? "").localizedCaseInsensitiveContains("diagnos") }
            output += "### Diagnoses (\(diags.count) entries)\n"
            for entry in diags.prefix(30) {
                output += "- \(entry.date ?? "?") — \(entry.content?.summary ?? "No summary") `<JOURNAL_ENTRY id=\"\(entry.id)\"/>`\n"
            }

        default: // "all"
            // Category breakdown
            var categoryCounts: [String: Int] = [:]
            for entry in doc.entries {
                let cat = entry.category ?? "Unknown"
                categoryCounts[cat, default: 0] += 1
            }
            output += "### Category Breakdown\n"
            for (cat, count) in categoryCounts.sorted(by: { $0.value > $1.value }) {
                output += "- \(cat): \(count)\n"
            }

            // Date range
            if let info = doc.metadata.exportInfo, let range = info.dateRange {
                output += "\n**Date range**: \(range.start ?? "?") to \(range.end ?? "?")\n"
            }

            // Providers
            if let providers = doc.metadata.exportInfo?.healthcareProviders, !providers.isEmpty {
                output += "\n### Healthcare Providers\n"
                for p in providers { output += "- \(p)\n" }
            }
        }

        return ToolResult(toolCallId: callId, content: output)
    }

    private func updateMemory(args: [String: Any], store: AgentMemoryStore, callId: String) async -> ToolResult {
        guard let content = args["content"] as? String else {
            return ToolResult(toolCallId: callId, content: "Error: content is required")
        }
        await MainActor.run {
            store.updateMemory(content)
        }
        return ToolResult(toolCallId: callId, content: "Memory updated successfully.")
    }

    private func updateUserProfile(args: [String: Any], store: AgentMemoryStore, callId: String) async -> ToolResult {
        guard let section = args["section"] as? String,
              let content = args["content"] as? String else {
            return ToolResult(toolCallId: callId, content: "Error: section and content are required")
        }

        await MainActor.run {
            var current = store.memory.user

            // Replace the section content
            let sectionHeaders: [String: String] = [
                "basic_info": "## Basic Info",
                "health_goals": "## Health Goals",
                "conditions": "## Conditions & Medications",
                "preferences": "## Preferences",
            ]

            guard let header = sectionHeaders[section] else {
                return
            }

            // Find the section and replace its content up to the next ## or end
            if let headerRange = current.range(of: header) {
                let afterHeader = current[headerRange.upperBound...]
                if let nextSection = afterHeader.range(of: "\n## ") {
                    current = String(current[..<headerRange.upperBound]) + "\n" + content + "\n" + String(current[nextSection.lowerBound...])
                } else {
                    current = String(current[..<headerRange.upperBound]) + "\n" + content + "\n"
                }
            } else {
                current += "\n\(header)\n\(content)\n"
            }

            store.updateUser(current)
        }

        return ToolResult(toolCallId: callId, content: "User profile section '\(section)' updated successfully.")
    }

    // MARK: - Helpers

    private func parseArguments(_ json: String) -> [String: Any]? {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Empty args is valid
            if json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || json == "{}" {
                return [:]
            }
            return nil
        }
        return obj
    }
}

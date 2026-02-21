import Foundation

struct ToolContext {
    let document: EirDocument?
    let allDocuments: [(profileID: UUID, personName: String, document: EirDocument)]
    let agentMemoryStore: AgentMemoryStore?
    let clinicStore: ClinicStore?
    let embeddingStore: EmbeddingStore?
}

actor ToolRegistry {

    // MARK: - Tool Definitions

    static let tools: [ToolDefinition] = [
        ToolDefinition(
            name: "get_medical_records",
            description: "Retrieve medical records. Call this whenever the user asks about their health records, journal entries, treatments, medications, lab results, diagnoses, or any medical history. For small record sets (<100 entries), returns full details. For large record sets, returns a summary index (ID, date, category, provider, summary) — use get_entry_details to drill into specific entries. You can also filter by category or search by keyword.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "person": ToolProperty(type: "string", description: "Filter by person name. Omit to get records for ALL family members."),
                    "category": ToolProperty(type: "string", description: "Filter by category (e.g. 'Anteckning', 'Lab', 'Recept', 'Diagnos')"),
                    "search": ToolProperty(type: "string", description: "Search keyword to filter entries by content (matches summary, details, notes)"),
                ],
                required: nil
            )
        ),
        ToolDefinition(
            name: "get_entry_details",
            description: "Get full details for specific journal entries by their IDs. Use this after get_medical_records to read the complete content (details, notes, tags) of entries that look relevant. You can request up to 20 entries at a time.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "entry_ids": ToolProperty(type: "string", description: "Comma-separated list of entry IDs to retrieve full details for (e.g. '123,456,789' or 'Birger::123,Hedda::456')"),
                ],
                required: ["entry_ids"]
            )
        ),
        ToolDefinition(
            name: "find_clinics",
            description: "Search for nearby healthcare clinics in Sweden by name or type.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "query": ToolProperty(type: "string", description: "Search term for clinic name or address"),
                    "type": ToolProperty(
                        type: "string",
                        description: "Clinic type to filter by",
                        enum: ["Vårdcentral", "Tandvård", "Psykiatri", "Barn/BVC", "Rehab/Fysio", "Ögon", "Hud", "Ortoped", "Kirurgi", "Gynekolog", "Akut/Jour", "Labb/Röntgen", "Vaccination", "Ungdom"]
                    ),
                    "limit": ToolProperty(type: "integer", description: "Max number of results to return (default 10)"),
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
            name: "name_agent",
            description: "Set your name. Call this when the user chooses a name for you during onboarding.",
            parameters: ToolParameters(
                type: "object",
                properties: [
                    "name": ToolProperty(type: "string", description: "The name the user chose for you"),
                ],
                required: ["name"]
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
        case "get_medical_records":
            return getMedicalRecords(args: args, allDocuments: context.allDocuments, callId: call.id)
        case "get_entry_details":
            return getEntryDetails(args: args, allDocuments: context.allDocuments, callId: call.id)
        case "find_clinics":
            return await findClinics(args: args, clinicStore: context.clinicStore, callId: call.id)
        case "name_agent":
            guard let store = context.agentMemoryStore else {
                return ToolResult(toolCallId: call.id, content: "Error: Agent memory not available")
            }
            return await nameAgent(args: args, store: store, callId: call.id)
        case "update_memory":
            guard let store = context.agentMemoryStore else {
                return ToolResult(toolCallId: call.id, content: "Error: Agent memory not available")
            }
            return await updateMemory(args: args, store: store, callId: call.id)
        case "update_user_profile":
            guard let store = context.agentMemoryStore else {
                return ToolResult(toolCallId: call.id, content: "Error: Agent memory not available")
            }
            return await updateUserProfile(args: args, store: store, callId: call.id)
        default:
            return ToolResult(toolCallId: call.id, content: "Error: Unknown tool '\(call.name)'")
        }
    }

    // MARK: - Tool Implementations

    /// Threshold: above this many total entries, return summaries only (no details/notes)
    private let summaryThreshold = 100

    private func getMedicalRecords(args: [String: Any], allDocuments: [(profileID: UUID, personName: String, document: EirDocument)], callId: String) -> ToolResult {
        guard !allDocuments.isEmpty else {
            return ToolResult(toolCallId: callId, content: "No medical records loaded.")
        }

        let personFilter = args["person"] as? String
        let categoryFilter = args["category"] as? String
        let searchFilter = args["search"] as? String
        let useCompositeIDs = allDocuments.count > 1

        let docs: [(profileID: UUID, personName: String, document: EirDocument)]
        if let personFilter {
            docs = allDocuments.filter { $0.personName.localizedCaseInsensitiveContains(personFilter) }
        } else {
            docs = allDocuments
        }

        guard !docs.isEmpty else {
            return ToolResult(toolCallId: callId, content: "No records found for '\(personFilter ?? "")'.")
        }

        // Collect matching entries
        var allEntries: [(personName: String, entry: EirEntry)] = []
        for (_, personName, doc) in docs {
            for entry in doc.entries {
                // Category filter
                if let categoryFilter, !(entry.category ?? "").localizedCaseInsensitiveContains(categoryFilter) {
                    continue
                }
                // Search filter — match against summary, details, notes
                if let searchFilter {
                    let haystack = [
                        entry.content?.summary,
                        entry.content?.details,
                        entry.content?.notes?.joined(separator: " "),
                        entry.type,
                        entry.provider?.name,
                    ].compactMap { $0 }.joined(separator: " ")
                    if !haystack.localizedCaseInsensitiveContains(searchFilter) {
                        continue
                    }
                }
                allEntries.append((personName, entry))
            }
        }

        // Use full details when the matched set is small, or when searching/filtering narrowed it down
        let useSummaryMode = allEntries.count > summaryThreshold && searchFilter == nil && categoryFilter == nil

        var output = ""

        if useSummaryMode {
            output += "# Medical Records Index (summary mode — \(allEntries.count) entries)\n"
            output += "Use `get_entry_details` with entry IDs to read full content of specific entries.\n\n"
        }

        // Group by person
        var currentPerson = ""
        for (personName, entry) in allEntries {
            if personName != currentPerson {
                currentPerson = personName
                let personDoc = docs.first(where: { $0.personName == personName })
                output += "# \(personName)\n"
                if let patient = personDoc?.document.metadata.patient {
                    if let dob = patient.birthDate { output += "Born: \(dob)\n" }
                }
                let personCount = allEntries.filter { $0.personName == personName }.count
                output += "Entries: \(personCount)\n\n"
            }

            let refID = useCompositeIDs ? "\(personName)::\(entry.id)" : entry.id
            output += "## [\(refID)] \(entry.date ?? "?")"
            if let time = entry.time { output += " \(time)" }
            output += " — \(entry.category ?? "?")"
            if let type = entry.type { output += " / \(type)" }
            output += "\n"

            if let provider = entry.provider?.name { output += "Provider: \(provider)\n" }
            if let person = entry.responsiblePerson {
                output += "Responsible: \(person.name ?? "?") (\(person.role ?? "?"))\n"
            }
            if let summary = entry.content?.summary {
                output += "\(summary)\n"
            }

            // Full details only in non-summary mode
            if !useSummaryMode {
                if let details = entry.content?.details, !details.isEmpty {
                    output += "\(details)\n"
                }
                if let notes = entry.content?.notes, !notes.isEmpty {
                    for note in notes { output += "- \(note)\n" }
                }
                if let tags = entry.tags, !tags.isEmpty {
                    output += "Tags: \(tags.joined(separator: ", "))\n"
                }
            }
            output += "\n"
        }

        return ToolResult(toolCallId: callId, content: output)
    }

    private func getEntryDetails(args: [String: Any], allDocuments: [(profileID: UUID, personName: String, document: EirDocument)], callId: String) -> ToolResult {
        guard let idsString = args["entry_ids"] as? String else {
            return ToolResult(toolCallId: callId, content: "Error: entry_ids is required (comma-separated list of IDs)")
        }

        let requestedIDs = idsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !requestedIDs.isEmpty else {
            return ToolResult(toolCallId: callId, content: "Error: No entry IDs provided")
        }
        guard requestedIDs.count <= 20 else {
            return ToolResult(toolCallId: callId, content: "Error: Maximum 20 entries per request. You requested \(requestedIDs.count).")
        }

        let useCompositeIDs = allDocuments.count > 1
        var output = ""
        var found = 0

        for requestedID in requestedIDs {
            // Parse composite ID: "PersonName::entryID" or plain "entryID"
            let personFilter: String?
            let entryID: String
            if requestedID.contains("::") {
                let parts = requestedID.components(separatedBy: "::")
                personFilter = parts[0]
                entryID = parts.dropFirst().joined(separator: "::")
            } else {
                personFilter = nil
                entryID = requestedID
            }

            // Find matching entry
            var matchedEntry: EirEntry?
            var matchedPerson: String?

            for (_, personName, doc) in allDocuments {
                if let pf = personFilter, !personName.localizedCaseInsensitiveContains(pf) {
                    continue
                }
                if let entry = doc.entries.first(where: { $0.id == entryID }) {
                    matchedEntry = entry
                    matchedPerson = personName
                    break
                }
            }

            guard let entry = matchedEntry, let personName = matchedPerson else {
                output += "## [\(requestedID)] — NOT FOUND\n\n"
                continue
            }

            found += 1
            let refID = useCompositeIDs ? "\(personName)::\(entry.id)" : entry.id
            output += "## [\(refID)] \(entry.date ?? "?")"
            if let time = entry.time { output += " \(time)" }
            output += " — \(entry.category ?? "?")"
            if let type = entry.type { output += " / \(type)" }
            output += "\n"

            if let provider = entry.provider?.name { output += "Provider: \(provider)\n" }
            if let region = entry.provider?.region { output += "Region: \(region)\n" }
            if let location = entry.provider?.location { output += "Location: \(location)\n" }
            if let person = entry.responsiblePerson {
                output += "Responsible: \(person.name ?? "?") (\(person.role ?? "?"))\n"
            }
            if let summary = entry.content?.summary {
                output += "Summary: \(summary)\n"
            }
            if let details = entry.content?.details, !details.isEmpty {
                output += "\nDetails:\n\(details)\n"
            }
            if let notes = entry.content?.notes, !notes.isEmpty {
                output += "\nNotes:\n"
                for note in notes { output += "- \(note)\n" }
            }
            if let tags = entry.tags, !tags.isEmpty {
                output += "Tags: \(tags.joined(separator: ", "))\n"
            }
            if let status = entry.status {
                output += "Status: \(status)\n"
            }
            output += "\n"
        }

        output = "Found \(found)/\(requestedIDs.count) entries.\n\n" + output
        return ToolResult(toolCallId: callId, content: output)
    }

    private func findClinics(args: [String: Any], clinicStore: ClinicStore?, callId: String) async -> ToolResult {
        guard let store = clinicStore else {
            return ToolResult(toolCallId: callId, content: "Clinic search is not available.")
        }

        let query = args["query"] as? String
        let typeFilter = args["type"] as? String
        let limit = (args["limit"] as? Int) ?? 10

        let clinics = await MainActor.run { store.allClinics }

        var results = clinics

        if let typeFilter {
            results = results.filter { clinic in
                let type = ClinicType.categorize(clinic.name)
                return type?.rawValue == typeFilter
            }
        }

        if let query, !query.isEmpty {
            let lowered = query.lowercased()
            results = results.filter { clinic in
                clinic.name.localizedCaseInsensitiveContains(lowered)
                    || (clinic.address?.localizedCaseInsensitiveContains(lowered) ?? false)
            }
        }

        let limited = results.prefix(limit)

        if limited.isEmpty {
            return ToolResult(toolCallId: callId, content: "No clinics found matching your search.")
        }

        var output = "Found \(results.count) clinics"
        if results.count > limit { output += " (showing first \(limit))" }
        output += ":\n\n"

        for clinic in limited {
            output += "### \(clinic.name)\n"
            if let address = clinic.address { output += "- Address: \(address)\n" }
            if let phone = clinic.phone { output += "- Phone: \(phone)\n" }
            if let url = clinic.url { output += "- Website: \(url)\n" }
            if clinic.hasMvkServices { output += "- Has 1177 e-services\n" }
            if clinic.videoOrChat { output += "- Offers video/chat consultations\n" }
            output += "\n"
        }

        return ToolResult(toolCallId: callId, content: output)
    }

    private func nameAgent(args: [String: Any], store: AgentMemoryStore, callId: String) async -> ToolResult {
        guard let name = args["name"] as? String, !name.isEmpty else {
            return ToolResult(toolCallId: callId, content: "Error: name is required")
        }
        await MainActor.run {
            store.setAgentName(name)
        }
        return ToolResult(toolCallId: callId, content: "Agent name set to '\(name)'.")
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

            let sectionHeaders: [String: String] = [
                "basic_info": "## Basic Info",
                "health_goals": "## Health Goals",
                "conditions": "## Conditions & Medications",
                "preferences": "## Preferences",
            ]

            guard let header = sectionHeaders[section] else {
                return
            }

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
            if json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || json == "{}" {
                return [:]
            }
            return nil
        }
        return obj
    }
}

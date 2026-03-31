import Foundation

@MainActor
final class ForYouViewModel: ObservableObject {
    @Published private(set) var cards: [ForYouCard] = []
    @Published private(set) var favoriteIDs: Set<String> = []
    @Published private(set) var reflectionDrafts: [String: String] = [:]
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreError: String?
    @Published var pendingCloudConsent: LLMProviderType?

    private var currentProfileID: UUID?
    private var currentSignature: String?
    private var currentDocument: EirDocument?
    private var currentActions: [HealthAction] = []

    func sync(profileID: UUID?, document: EirDocument?, actions: [HealthAction]) {
        let signature = feedSignature(document: document, actions: actions)
        currentDocument = document
        currentActions = actions
        if currentProfileID != profileID {
            currentProfileID = profileID
            loadState()
            currentSignature = nil
        }

        if currentSignature == signature, !cards.isEmpty {
            return
        }

        currentSignature = signature
        cards = ForYouCardGenerator.generate(document: document, actions: actions)
        loadMoreError = nil
        sortCards()
    }

    func loadMoreIfNeeded(
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async {
        guard !cards.isEmpty, !isLoadingMore else { return }
        await loadMore(settingsVM: settingsVM, localModelManager: localModelManager)
    }

    func retryLoadMore(
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async {
        guard !isLoadingMore else { return }
        await loadMore(settingsVM: settingsVM, localModelManager: localModelManager)
    }

    func consentGrantedAndLoadMore(
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async {
        guard let provider = pendingCloudConsent else { return }
        ChatViewModel.grantCloudConsent(for: provider)
        pendingCloudConsent = nil
        await loadMore(settingsVM: settingsVM, localModelManager: localModelManager)
    }

    func consentDenied() {
        pendingCloudConsent = nil
    }

    func isFavorite(_ card: ForYouCard) -> Bool {
        favoriteIDs.contains(card.id)
    }

    func toggleFavorite(_ card: ForYouCard) {
        if favoriteIDs.contains(card.id) {
            favoriteIDs.remove(card.id)
        } else {
            favoriteIDs.insert(card.id)
        }
        saveState()
        sortCards()
    }

    func reflectionText(for cardID: String) -> String {
        reflectionDrafts[cardID] ?? ""
    }

    func saveReflection(_ text: String, for cardID: String) {
        reflectionDrafts[cardID] = text
        saveState()
    }

    private func sortCards() {
        cards.sort { lhs, rhs in
            let leftFavorite = favoriteIDs.contains(lhs.id)
            let rightFavorite = favoriteIDs.contains(rhs.id)

            if leftFavorite != rightFavorite {
                return leftFavorite && !rightFavorite
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private func saveState() {
        let payload = ForYouStoredState(
            favoriteIDs: Array(favoriteIDs),
            reflectionDrafts: reflectionDrafts
        )
        EncryptedStore.save(payload, forKey: storageKey)
    }

    private func loadState() {
        let payload = EncryptedStore.load(ForYouStoredState.self, forKey: storageKey)
        favoriteIDs = Set(payload?.favoriteIDs ?? [])
        reflectionDrafts = payload?.reflectionDrafts ?? [:]
    }

    private func loadMore(
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async {
        guard let config = settingsVM.activeProvider else {
            loadMoreError = readableLoadMoreError(for: LLMError.noProvider)
            return
        }

        if !config.type.isLocal && !ChatViewModel.hasCloudConsent(for: config.type) {
            pendingCloudConsent = config.type
            loadMoreError = nil
            return
        }

        isLoadingMore = true
        loadMoreError = nil
        defer { isLoadingMore = false }

        do {
            let appended = try await generateAdditionalCards(
                count: 5,
                settingsVM: settingsVM,
                localModelManager: localModelManager
            )
            cards.append(contentsOf: appended)
            sortCards()
        } catch {
            loadMoreError = readableLoadMoreError(for: error)
        }
    }

    private func generateAdditionalCards(
        count: Int,
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async throws -> [ForYouCard] {
        guard settingsVM.activeProvider != nil else {
            throw LLMError.noProvider
        }

        var accepted: [ForYouCard] = []
        var seenTitles = Set(cards.map { normalizedTitle($0.title) })
        let existingDisplayTitles = cards.map(\.title)
        var nextSortOrder = (cards.map(\.sortOrder).max() ?? -1) + 1
        var attempts = 0

        while accepted.count < count && attempts < 3 {
            let requestedCount = min(max(count - accepted.count + 2, 5), 7)
            let rawResponse = try await requestGeneratedBatch(
                count: requestedCount,
                existingTitles: Array(Set(existingDisplayTitles + accepted.map(\.title))).sorted(),
                settingsVM: settingsVM,
                localModelManager: localModelManager
            )
            let specs = try decodeBatch(from: rawResponse).cards

            for spec in specs {
                let normalized = normalizedTitle(spec.title)
                guard !normalized.isEmpty, !seenTitles.contains(normalized) else { continue }
                guard let card = buildCard(from: spec, sortOrder: nextSortOrder, offset: accepted.count) else { continue }
                accepted.append(card)
                seenTitles.insert(normalized)
                nextSortOrder += 1
                if accepted.count == count {
                    break
                }
            }

            attempts += 1
        }

        guard accepted.count == count else {
            throw LLMError.requestFailed("Fresh cards were almost ready, but the generator returned too few unique ideas.")
        }

        return accepted
    }

    private func requestGeneratedBatch(
        count: Int,
        existingTitles: [String],
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async throws -> String {
        guard let config = settingsVM.activeProvider else {
            throw LLMError.noProvider
        }

        let systemPrompt = """
        You create premium short-form health feed cards for an iOS app called Eir.
        Return only valid JSON with this exact shape:
        {
          "cards": [
            {
              "kind": "action|meditation|quiz|reading|reflection",
              "title": "short unique title",
              "eyebrow": "2-4 words",
              "summary": "one short sentence",
              "durationMinutes": 1-10,
              "actionCategory": "movement|breath|recovery|hydration|focus|sleep|planning|nutrition",
              "insight": "short rationale",
              "benefits": ["benefit", "benefit"],
              "steps": ["step", "step", "step"],
              "quizQuestion": "question",
              "quizOptions": [
                { "title": "option", "feedback": "feedback", "isCorrect": true }
              ],
              "quizSuccessTitle": "short title",
              "readingKicker": "one line",
              "readingParagraphs": ["paragraph", "paragraph"],
              "reflectionPrompt": "prompt",
              "reflectionPlaceholder": "placeholder",
              "breathing": { "inhaleSeconds": 4, "exhaleSeconds": 6, "rounds": 6 }
            }
          ]
        }

        Rules:
        - Generate exactly \(count) cards.
        - Every card must be doable or consumable in 10 minutes or less.
        - Titles must be clearly distinct from the excluded titles.
        - Avoid diagnosis, alarmist language, and generic wellness filler.
        - Keep the language calm, specific, elegant, and useful.
        - Make the batch varied. Prefer a mix of action, meditation, quiz, reading, and reflection.
        - For action cards include 2-3 benefits and 2-4 steps.
        - For quiz cards include exactly 3 options and exactly 1 correct answer.
        - For reading cards include 2-3 short paragraphs.
        - For meditation cards use inhale 3-5 seconds, exhale 4-7 seconds, rounds 4-8.
        - JSON only. No markdown fences.
        """

        let userPrompt = """
        Existing card titles to avoid:
        \(existingTitles.map { "- \($0)" }.joined(separator: "\n"))

        Recent health context:
        \(healthContextSummary())
        """

        if config.type.isLocal {
            guard localModelManager.isReady else {
                throw LLMError.requestFailed("Load an on-device model or choose a cloud provider to generate more cards.")
            }

            nonisolated(unsafe) var response = ""
            _ = try await localModelManager.service.streamResponse(
                userMessage: userPrompt,
                systemPrompt: systemPrompt,
                conversationId: UUID()
            ) { token in
                response += token
            }
            return response
        }

        let credential = try await settingsVM.resolvedCredential(for: config)
        let service = LLMService(config: config, apiKey: credential)
        return try await service.completeChat(
            messages: [
                (role: "system", content: systemPrompt),
                (role: "user", content: userPrompt)
            ]
        )
    }

    private func decodeBatch(from rawResponse: String) throws -> ForYouGeneratedBatch {
        for candidate in jsonCandidates(from: rawResponse) {
            if let data = candidate.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(ForYouGeneratedBatch.self, from: data) {
                return decoded
            }

            if let data = candidate.data(using: .utf8),
               let normalized = decodeNormalizedBatch(from: data) {
                return normalized
            }
        }

        if let fallback = fallbackBatch(from: rawResponse) {
            return fallback
        }

        throw LLMError.requestFailed("The feed generator returned a format the app could not use.")
    }

    private func buildCard(
        from spec: ForYouGeneratedCardSpec,
        sortOrder: Int,
        offset: Int
    ) -> ForYouCard? {
        let kind = ForYouCardKind(rawValue: spec.kind.lowercased()) ?? .action
        let theme = ForYouCardTheme.generatedTheme(for: kind, offset: offset + sortOrder)
        let cleanTitle = spec.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSummary = spec.summary.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty, !cleanSummary.isEmpty else { return nil }

        let durationMinutes = min(max(spec.durationMinutes ?? 3, 1), 10)
        let eyebrow = (spec.eyebrow?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? spec.eyebrow!.trimmingCharacters(in: .whitespacesAndNewlines)
            : defaultEyebrow(for: kind)
        let symbolName = symbolName(for: kind, actionCategory: spec.actionCategory)
        let durationLabel = "\(durationMinutes) min"
        let id = "llm-\(sortOrder)-\(slug(cleanTitle))"

        switch kind {
        case .action:
            guard let category = HealthActionCategory(rawValue: spec.actionCategory?.lowercased() ?? ""),
                  let insight = spec.insight.nonEmptyTrimmed,
                  let benefits = cleanedList(spec.benefits),
                  let steps = cleanedList(spec.steps) else {
                return nil
            }

            let action = HealthAction(
                id: id,
                title: cleanTitle,
                summary: cleanSummary,
                insight: insight,
                category: category,
                durationMinutes: durationMinutes,
                benefits: Array(benefits.prefix(3)),
                steps: Array(steps.prefix(4)),
                source: currentDocument == nil ? .starter : .records,
                linkedEntryIDs: []
            )

            return ForYouCard(
                id: id,
                sortOrder: sortOrder,
                kind: kind,
                theme: theme,
                eyebrow: eyebrow,
                title: cleanTitle,
                summary: cleanSummary,
                durationLabel: durationLabel,
                symbolName: symbolName,
                action: action,
                quiz: nil,
                reading: nil,
                reflection: nil,
                breathing: nil
            )

        case .meditation:
            let breathing = ForYouBreathing(
                inhaleSeconds: min(max(spec.breathing?.inhaleSeconds ?? 4, 3), 5),
                exhaleSeconds: min(max(spec.breathing?.exhaleSeconds ?? 6, 4), 7),
                rounds: min(max(spec.breathing?.rounds ?? 6, 4), 8)
            )
            return ForYouCard(
                id: id,
                sortOrder: sortOrder,
                kind: kind,
                theme: theme,
                eyebrow: eyebrow,
                title: cleanTitle,
                summary: cleanSummary,
                durationLabel: durationLabel,
                symbolName: symbolName,
                action: nil,
                quiz: nil,
                reading: nil,
                reflection: nil,
                breathing: breathing
            )

        case .quiz:
            guard let question = spec.quizQuestion.nonEmptyTrimmed,
                  let options = spec.quizOptions?.compactMap({ $0.asOption }),
                  options.count == 3,
                  options.filter(\.isCorrect).count == 1 else {
                return nil
            }

            return ForYouCard(
                id: id,
                sortOrder: sortOrder,
                kind: kind,
                theme: theme,
                eyebrow: eyebrow,
                title: cleanTitle,
                summary: cleanSummary,
                durationLabel: durationLabel,
                symbolName: symbolName,
                action: nil,
                quiz: ForYouQuiz(
                    question: question,
                    options: options,
                    successTitle: spec.quizSuccessTitle.nonEmptyTrimmed ?? "Nice"
                ),
                reading: nil,
                reflection: nil,
                breathing: nil
            )

        case .reading:
            guard let kicker = spec.readingKicker.nonEmptyTrimmed,
                  let paragraphs = cleanedList(spec.readingParagraphs) else {
                return nil
            }

            return ForYouCard(
                id: id,
                sortOrder: sortOrder,
                kind: kind,
                theme: theme,
                eyebrow: eyebrow,
                title: cleanTitle,
                summary: cleanSummary,
                durationLabel: durationLabel,
                symbolName: symbolName,
                action: nil,
                quiz: nil,
                reading: ForYouReading(
                    kicker: kicker,
                    paragraphs: Array(paragraphs.prefix(3))
                ),
                reflection: nil,
                breathing: nil
            )

        case .reflection:
            guard let prompt = spec.reflectionPrompt.nonEmptyTrimmed else { return nil }
            return ForYouCard(
                id: id,
                sortOrder: sortOrder,
                kind: kind,
                theme: theme,
                eyebrow: eyebrow,
                title: cleanTitle,
                summary: cleanSummary,
                durationLabel: durationLabel,
                symbolName: symbolName,
                action: nil,
                quiz: nil,
                reading: nil,
                reflection: ForYouReflection(
                    prompt: prompt,
                    placeholder: spec.reflectionPlaceholder.nonEmptyTrimmed ?? "Write one line..."
                ),
                breathing: nil
            )

        case .soundscape:
            return nil
        }
    }

    private func readableLoadMoreError(for error: Error) -> String {
        if let llmError = error as? LLMError, let description = llmError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func cleanedList(_ values: [String]?) -> [String]? {
        let filtered = (values ?? []).map(\.trimmedNonEmpty).filter { !$0.isEmpty }
        return filtered.isEmpty ? nil : filtered
    }

    private func healthContextSummary() -> String {
        let actionLines = currentActions.prefix(5).map {
            "- Action: \($0.title) (\($0.durationLabel)) — \($0.summary)"
        }
        let entryLines: [String] = currentDocument?.entries.prefix(6).compactMap { entry in
            let summary = [
                entry.category,
                entry.type,
                entry.content?.summary,
                entry.content?.details
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            return summary.isEmpty ? nil : "- Record: \(summary.prefix(180))"
        } ?? []

        let combined = Array((actionLines + entryLines).prefix(10))
        if combined.isEmpty {
            return "- No personal health records are available. Generate universally useful cards."
        }
        return combined.joined(separator: "\n")
    }

    private func symbolName(for kind: ForYouCardKind, actionCategory: String?) -> String {
        switch kind {
        case .action:
            if let rawValue = actionCategory?.lowercased(),
               let category = HealthActionCategory(rawValue: rawValue) {
                return category.systemImage
            }
            return "sparkles"
        case .meditation:
            return "wind"
        case .quiz:
            return "sparkles"
        case .reading:
            return "book.pages.fill"
        case .reflection:
            return "square.and.pencil"
        case .soundscape:
            return "waveform"
        }
    }

    private func defaultEyebrow(for kind: ForYouCardKind) -> String {
        switch kind {
        case .action: return "Try now"
        case .meditation: return "Reset"
        case .quiz: return "Tiny quiz"
        case .reading: return "Short read"
        case .reflection: return "Writing prompt"
        case .soundscape: return "Soundscape"
        }
    }

    private func extractJSONObject(from rawResponse: String) -> String? {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}") else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private func extractJSONArray(from rawResponse: String) -> String? {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "["),
              let end = trimmed.lastIndex(of: "]") else {
            return nil
        }
        return String(trimmed[start...end])
    }

    private func jsonCandidates(from rawResponse: String) -> [String] {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let unwrapped = stripMarkdownFences(from: trimmed)
        return Array(Set([
            trimmed,
            unwrapped,
            extractJSONObject(from: trimmed),
            extractJSONObject(from: unwrapped),
            extractJSONArray(from: trimmed),
            extractJSONArray(from: unwrapped)
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
    }

    private func stripMarkdownFences(from rawResponse: String) -> String {
        var text = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: #"^```[a-zA-Z0-9_-]*\s*"#, with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeNormalizedBatch(from data: Data) -> ForYouGeneratedBatch? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        if let object = json as? [String: Any] {
            if let cards = object["cards"] as? [[String: Any]] {
                return normalizeBatch(cards)
            }
            if let cards = object["items"] as? [[String: Any]] {
                return normalizeBatch(cards)
            }
        }

        if let cards = json as? [[String: Any]] {
            return normalizeBatch(cards)
        }

        return nil
    }

    private func normalizeBatch(_ rawCards: [[String: Any]]) -> ForYouGeneratedBatch? {
        let cards = rawCards.compactMap(normalizeCardSpec)
        guard !cards.isEmpty else { return nil }
        return ForYouGeneratedBatch(cards: cards)
    }

    private func normalizeCardSpec(_ raw: [String: Any]) -> ForYouGeneratedCardSpec? {
        let kind = stringValue(raw["kind"]) ?? stringValue(raw["type"]) ?? "action"
        let title = stringValue(raw["title"]) ?? stringValue(raw["name"]) ?? ""
        let summary = stringValue(raw["summary"]) ?? stringValue(raw["description"]) ?? stringValue(raw["subtitle"]) ?? ""

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let breathingSource = (raw["breathing"] as? [String: Any]) ?? raw["meditation"] as? [String: Any]

        return ForYouGeneratedCardSpec(
            kind: kind,
            title: title,
            eyebrow: stringValue(raw["eyebrow"]) ?? stringValue(raw["tag"]) ?? stringValue(raw["label"]),
            summary: summary,
            durationMinutes: intValue(raw["durationMinutes"]) ?? intValue(raw["duration"]) ?? intValue(raw["minutes"]),
            actionCategory: stringValue(raw["actionCategory"]) ?? stringValue(raw["category"]),
            insight: stringValue(raw["insight"]) ?? stringValue(raw["why"]),
            benefits: stringList(raw["benefits"]) ?? stringList(raw["outcomes"]),
            steps: stringList(raw["steps"]) ?? stringList(raw["instructions"]),
            quizQuestion: stringValue(raw["quizQuestion"]) ?? stringValue(raw["question"]),
            quizOptions: quizOptions(raw["quizOptions"]) ?? quizOptions(raw["options"]),
            quizSuccessTitle: stringValue(raw["quizSuccessTitle"]) ?? stringValue(raw["successTitle"]),
            readingKicker: stringValue(raw["readingKicker"]) ?? stringValue(raw["kicker"]),
            readingParagraphs: stringList(raw["readingParagraphs"]) ?? stringList(raw["paragraphs"]) ?? stringList(raw["content"]),
            reflectionPrompt: stringValue(raw["reflectionPrompt"]) ?? stringValue(raw["prompt"]),
            reflectionPlaceholder: stringValue(raw["reflectionPlaceholder"]) ?? stringValue(raw["placeholder"]),
            breathing: breathingSpec(breathingSource)
        )
    }

    private func fallbackBatch(from rawResponse: String) -> ForYouGeneratedBatch? {
        let lines = stripMarkdownFences(from: rawResponse)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let titles = lines
            .map { $0.replacingOccurrences(of: #"^[-*\d\.\)\s]+"#, with: "", options: .regularExpression) }
            .filter { $0.count > 6 }

        guard !titles.isEmpty else { return nil }

        let cards = Array(titles.prefix(5)).map { title in
            ForYouGeneratedCardSpec(
                kind: "action",
                title: title,
                eyebrow: "Try now",
                summary: "A short health action to help you reset, reflect, or feel a little better today.",
                durationMinutes: 3,
                actionCategory: "recovery",
                insight: "Small actions are easier to follow through on when the next step is clear.",
                benefits: ["Reduces friction", "Supports consistency"],
                steps: ["Pause for a moment.", "Do this one small step now.", "Notice how you feel after."],
                quizQuestion: nil,
                quizOptions: nil,
                quizSuccessTitle: nil,
                readingKicker: nil,
                readingParagraphs: nil,
                reflectionPrompt: nil,
                reflectionPlaceholder: nil,
                breathing: nil
            )
        }

        return cards.isEmpty ? nil : ForYouGeneratedBatch(cards: cards)
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String {
            let digits = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(digits)
        }
        return nil
    }

    private func stringList(_ value: Any?) -> [String]? {
        if let strings = value as? [String] {
            let cleaned = strings.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return cleaned.isEmpty ? nil : cleaned
        }
        if let string = value as? String {
            let cleaned = string
                .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: "•-")))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return cleaned.isEmpty ? nil : cleaned
        }
        return nil
    }

    private func quizOptions(_ value: Any?) -> [ForYouGeneratedQuizOption]? {
        guard let rawOptions = value as? [[String: Any]] else { return nil }
        let options = rawOptions.compactMap { option -> ForYouGeneratedQuizOption? in
            guard let title = stringValue(option["title"]) ?? stringValue(option["text"]),
                  let feedback = stringValue(option["feedback"]) ?? stringValue(option["explanation"]) ?? stringValue(option["reason"]) else {
                return nil
            }

            let isCorrect: Bool
            if let bool = option["isCorrect"] as? Bool {
                isCorrect = bool
            } else if let bool = option["correct"] as? Bool {
                isCorrect = bool
            } else {
                isCorrect = false
            }

            return ForYouGeneratedQuizOption(title: title, feedback: feedback, isCorrect: isCorrect)
        }
        return options.isEmpty ? nil : options
    }

    private func breathingSpec(_ value: Any?) -> ForYouGeneratedBreathing? {
        guard let raw = value as? [String: Any],
              let inhale = intValue(raw["inhaleSeconds"]) ?? intValue(raw["inhale"]),
              let exhale = intValue(raw["exhaleSeconds"]) ?? intValue(raw["exhale"]),
              let rounds = intValue(raw["rounds"]) ?? intValue(raw["cycles"]) else {
            return nil
        }
        return ForYouGeneratedBreathing(inhaleSeconds: inhale, exhaleSeconds: exhale, rounds: rounds)
    }

    private func normalizedTitle(_ title: String) -> String {
        title
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func slug(_ title: String) -> String {
        let slug = title
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }

    private var storageKey: String {
        if let currentProfileID {
            return "eir_for_you_state_\(currentProfileID.uuidString)"
        }
        return "eir_for_you_state_global"
    }

    private func feedSignature(document: EirDocument?, actions: [HealthAction]) -> String {
        let actionIDs = actions.map(\.id).joined(separator: "|")
        let entryHead = document?.entries.prefix(6).map(\.id).joined(separator: "|") ?? "none"
        return "\(document?.entries.count ?? 0)|\(entryHead)|\(actionIDs)"
    }
}

private struct ForYouStoredState: Codable {
    let favoriteIDs: [String]
    let reflectionDrafts: [String: String]
}

private struct ForYouGeneratedBatch: Codable {
    let cards: [ForYouGeneratedCardSpec]
}

private struct ForYouGeneratedCardSpec: Codable {
    let kind: String
    let title: String
    let eyebrow: String?
    let summary: String
    let durationMinutes: Int?
    let actionCategory: String?
    let insight: String?
    let benefits: [String]?
    let steps: [String]?
    let quizQuestion: String?
    let quizOptions: [ForYouGeneratedQuizOption]?
    let quizSuccessTitle: String?
    let readingKicker: String?
    let readingParagraphs: [String]?
    let reflectionPrompt: String?
    let reflectionPlaceholder: String?
    let breathing: ForYouGeneratedBreathing?
}

private struct ForYouGeneratedQuizOption: Codable {
    let title: String
    let feedback: String
    let isCorrect: Bool

    var asOption: ForYouQuizOption? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanFeedback.isEmpty else { return nil }
        return ForYouQuizOption(
            id: UUID().uuidString,
            title: cleanTitle,
            feedback: cleanFeedback,
            isCorrect: isCorrect
        )
    }
}

private struct ForYouGeneratedBreathing: Codable {
    let inhaleSeconds: Int
    let exhaleSeconds: Int
    let rounds: Int
}

private extension Optional where Wrapped == String {
    var nonEmptyTrimmed: String? {
        guard let unwrapped = self else { return nil }
        let value = unwrapped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }
        return value
    }
}

private extension String {
    var trimmedNonEmpty: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

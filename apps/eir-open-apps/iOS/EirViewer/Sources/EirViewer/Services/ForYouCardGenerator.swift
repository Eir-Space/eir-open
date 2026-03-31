import Foundation

enum ForYouCardGenerator {
    static func generate(document: EirDocument?, actions: [HealthAction]) -> [ForYouCard] {
        let primaryAction = actions.first
        let additionalActions = Array(actions.dropFirst().prefix(4))
        let context = buildContext(from: document)

        var cards: [ForYouCard] = []

        if let primaryAction {
            cards.append(actionCard(primaryAction, sortOrder: 0, theme: .ember, eyebrow: "Best next step"))
        }

        cards.append(
            ForYouCard(
                id: "meditation-reset",
                sortOrder: 1,
                kind: .meditation,
                theme: .tide,
                eyebrow: "Reset",
                title: context.hasStressSignals ? "One-minute reset" : "Slow your pace",
                summary: "A guided breathing minute to steady your body before the next thing.",
                durationLabel: "1 min",
                symbolName: "wind",
                action: nil,
                quiz: nil,
                reading: nil,
                reflection: nil,
                breathing: ForYouBreathing(inhaleSeconds: 4, exhaleSeconds: 6, rounds: 6)
            )
        )

        cards.append(
            ForYouCard(
                id: "quiz-cue",
                sortOrder: 2,
                kind: .quiz,
                theme: .aurora,
                eyebrow: "Tiny quiz",
                title: "What makes a small habit stick?",
                summary: "A 10-second behavior nudge grounded in habit research.",
                durationLabel: "10 sec",
                symbolName: "sparkles",
                action: nil,
                quiz: ForYouQuiz(
                    question: "What makes a five-minute health action most likely to happen?",
                    options: [
                        ForYouQuizOption(
                            id: "motivation",
                            title: "Waiting until you feel motivated",
                            feedback: "Motivation helps, but it is unreliable when life is crowded.",
                            isCorrect: false
                        ),
                        ForYouQuizOption(
                            id: "cue",
                            title: "Attaching it to an existing cue",
                            feedback: "Yes. Existing cues lower friction and make repetition more automatic.",
                            isCorrect: true
                        ),
                        ForYouQuizOption(
                            id: "willpower",
                            title: "Trying to do more at once",
                            feedback: "More ambition usually means more friction, which lowers follow-through.",
                            isCorrect: false
                        )
                    ],
                    successTitle: "Better odds"
                ),
                reading: nil,
                reflection: nil,
                breathing: nil
            )
        )

        cards.append(
            ForYouCard(
                id: "reading-questions",
                sortOrder: 3,
                kind: .reading,
                theme: .coral,
                eyebrow: "2-minute read",
                title: context.hasAppointments ? "Take one better question to care" : "Use small questions well",
                summary: "A short piece on how one prepared question can improve a visit or follow-up.",
                durationLabel: "2 min",
                symbolName: "book.pages.fill",
                action: nil,
                quiz: nil,
                reading: ForYouReading(
                    kicker: "Good visits often start before the visit itself.",
                    paragraphs: [
                        "A useful health question is specific enough to answer in one conversation and concrete enough to reduce uncertainty.",
                        "Instead of 'What does this mean?', try 'What should I watch for over the next two weeks?'",
                        "If you only prepare one line, you are far more likely to remember it when the visit starts."
                    ]
                ),
                reflection: nil,
                breathing: nil
            )
        )

        cards.append(
            ForYouCard(
                id: "reflection-prompt",
                sortOrder: 4,
                kind: .reflection,
                theme: .velvet,
                eyebrow: "Writing prompt",
                title: "Write one honest line",
                summary: "A short prompt to turn body signals into something you can actually use.",
                durationLabel: "1 min",
                symbolName: "square.and.pencil",
                action: nil,
                quiz: nil,
                reading: nil,
                reflection: ForYouReflection(
                    prompt: context.hasRecords
                        ? "What would make your body feel 5% easier today?"
                        : "What is the smallest thing that would help you feel more steady today?",
                    placeholder: "Write one honest line..."
                ),
                breathing: nil
            )
        )

        let themes: [ForYouCardTheme] = [.meadow, .ember, .tide, .aurora]
        for (offset, action) in additionalActions.enumerated() {
            cards.append(
                actionCard(
                    action,
                    sortOrder: 5 + offset,
                    theme: themes[offset % themes.count],
                    eyebrow: action.source.title
                )
            )
        }

        return cards
    }

    private static func actionCard(
        _ action: HealthAction,
        sortOrder: Int,
        theme: ForYouCardTheme,
        eyebrow: String
    ) -> ForYouCard {
        ForYouCard(
            id: "action-\(action.id)",
            sortOrder: sortOrder,
            kind: .action,
            theme: theme,
            eyebrow: eyebrow,
            title: action.title,
            summary: action.summary,
            durationLabel: action.durationLabel,
            symbolName: action.category.systemImage,
            action: action,
            quiz: nil,
            reading: nil,
            reflection: nil,
            breathing: nil
        )
    }

    private static func buildContext(from document: EirDocument?) -> ForYouContext {
        guard let document else {
            return ForYouContext(hasRecords: false, hasStressSignals: false, hasAppointments: false)
        }

        let text = document.entries
            .prefix(20)
            .map {
                [
                    $0.category,
                    $0.type,
                    $0.content?.summary,
                    $0.content?.details,
                    $0.content?.notes?.joined(separator: " ")
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            }
            .joined(separator: "\n")
            .lowercased()

        return ForYouContext(
            hasRecords: true,
            hasStressSignals: containsAny(in: text, keywords: ["stress", "oro", "ångest", "hjärtklappning", "utmatt"]),
            hasAppointments: containsAny(in: text, keywords: ["besök", "remiss", "uppfölj", "mottagning", "provtagning"])
        )
    }

    private static func containsAny(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private struct ForYouContext {
        let hasRecords: Bool
        let hasStressSignals: Bool
        let hasAppointments: Bool
    }
}

import Foundation

enum HealthActionGenerator {
    static func generateActions(document: EirDocument?) -> [HealthAction] {
        let starter = starterActions()
        guard let document else { return starter }

        let recentEntries = Array(document.entries.sorted {
            ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast)
        }.prefix(16))

        let corpus = recentEntries.map { entryText(for: $0) }
            .joined(separator: "\n")
            .lowercased()

        let recordIDs = recentEntries.map(\.id)
        var actions: [HealthAction] = []

        if containsAny(in: corpus, keywords: ["blodtryck", "stress", "hjärtklappning", "oro", "ångest", "huvudvärk"]) {
            actions.append(
                HealthAction(
                    id: "records-breath-reset",
                    title: "Box breathing reset",
                    summary: "Bring your pulse and attention down with four calm rounds of structured breathing.",
                    insight: "Your records mention patterns that often benefit from short down-regulation breaks.",
                    category: .breath,
                    durationMinutes: 4,
                    benefits: ["Can lower stress in the moment", "Creates a calmer starting point before the next task"],
                    steps: ["Sit down or stand still.", "Breathe in for 4 seconds.", "Hold for 4 seconds.", "Breathe out for 4 seconds.", "Hold out for 4 seconds and repeat 4 rounds."],
                    source: .records,
                    linkedEntryIDs: recordIDs
                )
            )
        }

        if containsAny(in: corpus, keywords: ["smärta", "rygg", "nacke", "axel", "muskel", "stel", "ont", "värk"]) {
            actions.append(
                HealthAction(
                    id: "records-mobility-release",
                    title: "Neck and shoulder release",
                    summary: "Reset tension with slow shoulder rolls, neck circles, and a short standing stretch.",
                    insight: "Your records suggest strain or pain-related language where gentle mobility can help daily comfort.",
                    category: .recovery,
                    durationMinutes: 5,
                    benefits: ["Can ease stiffness", "May make desk time and walking feel lighter"],
                    steps: ["Roll both shoulders backward 10 times.", "Tilt your head gently side to side for 30 seconds each.", "Clasp your hands and reach forward for 20 seconds.", "Stand tall and take five slow breaths.", "Finish with a short walk across the room."],
                    source: .records,
                    linkedEntryIDs: recordIDs
                )
            )
        }

        if containsAny(in: corpus, keywords: ["läkemedel", "recept", "medicin", "tablett", "dos"]) {
            actions.append(
                HealthAction(
                    id: "records-med-check",
                    title: "Two-minute medication check",
                    summary: "Open your medicine list, confirm the next dose, and note anything unclear for later.",
                    insight: "Medication-related entries are easier to act on when you keep the next question or dose visible.",
                    category: .planning,
                    durationMinutes: 2,
                    benefits: ["Reduces avoidable confusion", "Makes follow-up questions easier to ask later"],
                    steps: ["Open your medication list or latest record.", "Check the next planned dose.", "Write down one question if anything feels unclear.", "Put the note where you will see it later today."],
                    source: .records,
                    linkedEntryIDs: recordIDs
                )
            )
        }

        if containsAny(in: corpus, keywords: ["sömn", "trött", "utmatt", "fatigue", "insomni"]) {
            actions.append(
                HealthAction(
                    id: "records-sleep-runway",
                    title: "Sleep runway reset",
                    summary: "Use five quiet minutes to dim light, lower stimulation, and give tonight a cleaner landing.",
                    insight: "Your records include fatigue or sleep-related signals that make evening friction worth reducing.",
                    category: .sleep,
                    durationMinutes: 5,
                    benefits: ["Creates a calmer evening transition", "Can make it easier to settle later"],
                    steps: ["Dim the nearest light.", "Put your phone on low brightness or away from reach.", "Set out water for later.", "Pick one thing to stop doing for the night.", "Take six slow breaths before moving on."],
                    source: .records,
                    linkedEntryIDs: recordIDs
                )
            )
        }

        if containsAny(in: corpus, keywords: ["glukos", "blodsocker", "diabetes", "kolesterol", "lab", "prov"]) {
            actions.append(
                HealthAction(
                    id: "records-postmeal-walk",
                    title: "After-meal walk",
                    summary: "Take a short, easy walk after food to add movement without turning it into a workout.",
                    insight: "Lab and metabolic patterns often pair well with steady, low-friction movement.",
                    category: .movement,
                    durationMinutes: 8,
                    benefits: ["Adds useful movement without much setup", "Can support steadier energy afterward"],
                    steps: ["Put on shoes if needed.", "Walk at an easy pace for 8 minutes.", "Keep your shoulders relaxed.", "When you return, drink a glass of water."],
                    source: .records,
                    linkedEntryIDs: recordIDs
                )
            )
        }

        if containsAny(in: corpus, keywords: ["besök", "remiss", "uppfölj", "mottagning", "provtagning"]) {
            actions.append(
                HealthAction(
                    id: "records-followup-note",
                    title: "Capture the next question",
                    summary: "Write one sentence about what you want clarified at your next visit or follow-up.",
                    insight: "Recent care contact language often creates loose ends that are easy to forget later.",
                    category: .focus,
                    durationMinutes: 3,
                    benefits: ["Improves follow-up conversations", "Turns vague worry into a concrete question"],
                    steps: ["Open Notes.", "Write one question starting with 'I want to understand...'.", "Add the date or clinic name if you know it.", "Star it or pin it."],
                    source: .records,
                    linkedEntryIDs: recordIDs
                )
            )
        }

        var unique = uniqued(actions + starter)
        if unique.count > 8 {
            unique = Array(unique.prefix(8))
        }
        return unique
    }

    private static func starterActions() -> [HealthAction] {
        [
            HealthAction(
                id: "starter-daylight-walk",
                title: "Five-minute daylight walk",
                summary: "Step outside for a short walk and let your eyes catch natural light.",
                insight: "A tiny amount of daylight and motion is one of the easiest ways to support energy and rhythm.",
                category: .movement,
                durationMinutes: 5,
                benefits: ["Can improve alertness", "Builds momentum for the rest of the day"],
                steps: ["Step outside.", "Walk at an easy pace for five minutes.", "Keep your gaze up, not only on the phone.", "Notice one thing around you before going back in."],
                source: .starter,
                linkedEntryIDs: []
            ),
            HealthAction(
                id: "starter-water-reset",
                title: "Water and posture reset",
                summary: "Drink a glass of water and reset your posture before the next block of work.",
                insight: "Hydration and posture are small levers that often improve how the next hour feels.",
                category: .hydration,
                durationMinutes: 3,
                benefits: ["Can improve concentration", "Breaks long static sitting"],
                steps: ["Pour a glass of water.", "Stand tall with both feet grounded.", "Roll shoulders back once.", "Drink slowly."],
                source: .starter,
                linkedEntryIDs: []
            ),
            HealthAction(
                id: "starter-breath-downshift",
                title: "Nervous system downshift",
                summary: "Take a deliberate breathing break before stress becomes the default.",
                insight: "A short breathing ritual is one of the highest-return actions when time is tight.",
                category: .breath,
                durationMinutes: 3,
                benefits: ["Can reduce reactivity", "Makes transitions feel cleaner"],
                steps: ["Sit or stand still.", "Inhale through your nose for 4 seconds.", "Exhale for 6 seconds.", "Repeat 6 times."],
                source: .starter,
                linkedEntryIDs: []
            ),
            HealthAction(
                id: "starter-desk-release",
                title: "Desk body release",
                summary: "Undo a little desk stiffness with simple standing mobility.",
                insight: "Short mobility breaks are often more realistic than promising a workout later.",
                category: .recovery,
                durationMinutes: 4,
                benefits: ["Loosens hips and shoulders", "Helps you return to work with less tension"],
                steps: ["Stand up.", "Reach both arms overhead for 20 seconds.", "Fold forward gently.", "Twist left and right.", "Walk around the room once."],
                source: .starter,
                linkedEntryIDs: []
            ),
            HealthAction(
                id: "starter-evening-close",
                title: "Quiet evening close",
                summary: "Give the day a soft landing with one screen-light and one mind-light reduction.",
                insight: "Better evenings often come from removing friction, not adding more discipline.",
                category: .sleep,
                durationMinutes: 5,
                benefits: ["Supports better sleep onset", "Lowers late-evening stimulation"],
                steps: ["Lower the brightness on your phone.", "Turn off one unnecessary light.", "Put tomorrow’s first task on paper.", "Leave the phone out of reach for five minutes."],
                source: .starter,
                linkedEntryIDs: []
            )
        ]
    }

    private static func entryText(for entry: EirEntry) -> String {
        [
            entry.category,
            entry.type,
            entry.provider?.name,
            entry.content?.summary,
            entry.content?.details,
            entry.content?.notes?.joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private static func containsAny(in text: String, keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func uniqued(_ actions: [HealthAction]) -> [HealthAction] {
        var seen = Set<String>()
        return actions.filter { action in
            seen.insert(action.id).inserted
        }
    }
}

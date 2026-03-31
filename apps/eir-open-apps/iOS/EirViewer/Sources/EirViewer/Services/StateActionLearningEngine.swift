import Foundation

struct StateActionRecommendation: Identifiable, Equatable {
    let id = UUID()
    let actionID: String
    let headline: String
    let summary: String
    let whyItFits: [String]
    let learningLabel: String
    let confidence: Double
    let score: Double
}

struct StateActionLearningSummary: Equatable {
    let resolvedExperiences: Int
    let pendingFollowUps: Int
    let learningLabel: String
    let statusLine: String

    static let empty = StateActionLearningSummary(
        resolvedExperiences: 0,
        pendingFollowUps: 0,
        learningLabel: "Starting",
        statusLine: "Save a state, try an action, then save a follow-up state."
    )
}

private struct StateActionPendingIntervention: Codable, Hashable, Identifiable {
    let id: UUID
    let actionID: String
    let createdAt: Date
    let preStateScores: [String: Double]
}

private struct StateActionLearningExperience: Codable, Hashable, Identifiable {
    let id: UUID
    let actionID: String
    let createdAt: Date
    let resolvedAt: Date
    let reward: Double
    let stateDelta: Double
}

private struct StateActionLearningPayload: Codable {
    var pending: [StateActionPendingIntervention] = []
    var experiences: [StateActionLearningExperience] = []
}

enum StateActionLearningEngine {
    static func recordActionCompletion(profileID: UUID, actionID: String) {
        guard let latestState = loadLatestState(profileID: profileID) else { return }

        var payload = loadPayload(profileID: profileID)
        let calendar = Calendar.current
        let alreadyPending = payload.pending.contains {
            $0.actionID == actionID &&
            calendar.isDate($0.createdAt, inSameDayAs: Date())
        }

        guard !alreadyPending else { return }

        payload.pending.append(
            StateActionPendingIntervention(
                id: UUID(),
                actionID: actionID,
                createdAt: Date(),
                preStateScores: latestState.scores
            )
        )
        payload.pending = Array(payload.pending.sorted { $0.createdAt > $1.createdAt }.prefix(16))
        savePayload(payload, profileID: profileID)
    }

    @discardableResult
    static func resolvePendingInterventions(profileID: UUID, with state: StateCheckInRecord) -> Int {
        var payload = loadPayload(profileID: profileID)
        var resolvedCount = 0
        var remaining: [StateActionPendingIntervention] = []

        for pending in payload.pending {
            guard pending.createdAt < state.createdAt else {
                remaining.append(pending)
                continue
            }

            let interval = state.createdAt.timeIntervalSince(pending.createdAt)
            if interval > 60 * 60 * 48 {
                continue
            }

            let reward = rewardScore(pre: pending.preStateScores, post: state.scores)
            payload.experiences.append(
                StateActionLearningExperience(
                    id: UUID(),
                    actionID: pending.actionID,
                    createdAt: pending.createdAt,
                    resolvedAt: state.createdAt,
                    reward: reward,
                    stateDelta: reward
                )
            )
            resolvedCount += 1
        }

        payload.pending = Array(remaining.sorted { $0.createdAt > $1.createdAt }.prefix(16))
        payload.experiences = Array(payload.experiences.sorted { $0.resolvedAt > $1.resolvedAt }.prefix(160))
        savePayload(payload, profileID: profileID)
        return resolvedCount
    }

    static func summary(profileID: UUID?) -> StateActionLearningSummary {
        guard let profileID else { return .empty }
        let payload = loadPayload(profileID: profileID)
        let label = learningLabel(for: payload.experiences.count)
        let line: String

        if payload.experiences.isEmpty {
            line = "The engine is still exploring what tends to help from each state."
        } else if payload.pending.isEmpty {
            line = "Learned from \(payload.experiences.count) state follow-up\(payload.experiences.count == 1 ? "" : "s") on this device."
        } else {
            line = "\(payload.pending.count) action follow-up\(payload.pending.count == 1 ? "" : "s") waiting for the next saved state."
        }

        return StateActionLearningSummary(
            resolvedExperiences: payload.experiences.count,
            pendingFollowUps: payload.pending.count,
            learningLabel: label,
            statusLine: line
        )
    }

    static func recommend(
        profileID: UUID?,
        actions: [HealthAction],
        state: StateCheckInRecord?
    ) -> StateActionRecommendation? {
        guard let profileID, let state, !actions.isEmpty else { return nil }

        let payload = loadPayload(profileID: profileID)
        let actionLookup = Dictionary(uniqueKeysWithValues: actions.map { ($0.id, $0) })
        let totalExperienceCount = max(payload.experiences.count, 1)

        let ranked = actions.map { action -> (HealthAction, Double, [String], Int) in
            let heuristic = heuristicScore(for: action.category, scores: state.scores)
            let actionExperiences = payload.experiences.filter { $0.actionID == action.id }
            let categoryExperiences = payload.experiences.filter { experience in
                guard let learnedAction = actionLookup[experience.actionID] else { return false }
                return learnedAction.category == action.category
            }

            let actionMean = meanReward(for: actionExperiences)
            let categoryMean = meanReward(for: categoryExperiences)
            let exploration = min(
                sqrt(log(Double(totalExperienceCount) + 1) / Double(actionExperiences.count + 1)) * 0.18,
                0.18
            )

            let score =
                (heuristic * 0.62) +
                (normalizeReward(actionMean) * 0.22) +
                (normalizeReward(categoryMean) * 0.08) +
                exploration

            return (
                action,
                score,
                explanation(
                    for: action,
                    scores: state.scores,
                    actionExperienceCount: actionExperiences.count,
                    actionMean: actionMean
                ),
                actionExperiences.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.durationMinutes < rhs.0.durationMinutes
            }
            return lhs.1 > rhs.1
        }

        guard let best = ranked.first else { return nil }
        let confidence = min(0.36 + (Double(best.3) * 0.12), 0.86)

        return StateActionRecommendation(
            actionID: best.0.id,
            headline: best.0.title,
            summary: best.0.summary,
            whyItFits: best.2,
            learningLabel: learningLabel(for: best.3),
            confidence: confidence,
            score: best.1
        )
    }

    private static func heuristicScore(for category: HealthActionCategory, scores: [String: Double]) -> Double {
        let lowPhysical = 1 - (scores["physical_energy"] ?? 0.5)
        let lowMental = 1 - (scores["mental_energy"] ?? 0.5)
        let lowMood = 1 - (scores["mood"] ?? 0.5)
        let lowMotivation = 1 - (scores["motivation"] ?? 0.5)
        let lowComfort = 1 - (scores["body_comfort"] ?? 0.5)
        let highStress = scores["stress_load"] ?? 0.5

        let value: Double
        switch category {
        case .movement:
            value = (0.30 * lowMood) + (0.28 * lowMotivation) + (0.22 * lowPhysical) + (0.12 * highStress) + (0.08 * lowMental)
        case .breath:
            value = (0.52 * highStress) + (0.26 * lowComfort) + (0.14 * lowMental) + (0.08 * lowMood)
        case .recovery:
            value = (0.30 * highStress) + (0.22 * lowPhysical) + (0.22 * lowComfort) + (0.14 * lowMental) + (0.12 * lowMood)
        case .hydration:
            value = (0.38 * lowPhysical) + (0.28 * highStress) + (0.18 * lowComfort) + (0.16 * lowMental)
        case .focus:
            value = (0.42 * lowMental) + (0.26 * lowMotivation) + (0.18 * highStress) + (0.14 * lowMood)
        case .sleep:
            value = (0.32 * lowPhysical) + (0.26 * highStress) + (0.22 * lowMental) + (0.20 * lowMood)
        case .planning:
            value = (0.40 * lowMotivation) + (0.26 * lowMental) + (0.18 * highStress) + (0.16 * lowMood)
        case .nutrition:
            value = (0.38 * lowPhysical) + (0.22 * lowMood) + (0.20 * highStress) + (0.20 * lowMental)
        }

        return min(max(value, 0), 1)
    }

    private static func explanation(
        for action: HealthAction,
        scores: [String: Double],
        actionExperienceCount: Int,
        actionMean: Double
    ) -> [String] {
        let topDrivers = stateDrivers(scores: scores)
        var reasons: [String] = []

        if topDrivers.contains("stress") {
            reasons.append("High pressure makes \(action.category.title.lowercased()) a good next move.")
        }
        if topDrivers.contains("motivation") {
            reasons.append("Lower drive suggests using an action with low start friction.")
        }
        if topDrivers.contains("mental") {
            reasons.append("Mental energy looks reduced, so the recommendation leans restorative and clear.")
        }
        if topDrivers.contains("physical") {
            reasons.append("Physical energy is down, so the action favors support over intensity.")
        }
        if reasons.isEmpty {
            reasons.append("This action matches the shape of the current state better than the other available options.")
        }

        if actionExperienceCount > 0 {
            if actionMean > 0.08 {
                reasons.append("This action has improved later states \(actionExperienceCount) time\(actionExperienceCount == 1 ? "" : "s") on this device.")
            } else if actionMean < -0.08 {
                reasons.append("The engine is still exploring this action because past results have been mixed.")
            } else {
                reasons.append("Past follow-ups for this action are still neutral, so the engine is balancing fit and exploration.")
            }
        } else {
            reasons.append("No direct follow-up history yet, so this is partly an exploration pick.")
        }

        return Array(reasons.prefix(3))
    }

    private static func stateDrivers(scores: [String: Double]) -> [String] {
        let pairs: [(String, Double)] = [
            ("stress", scores["stress_load"] ?? 0.5),
            ("physical", 1 - (scores["physical_energy"] ?? 0.5)),
            ("mental", 1 - (scores["mental_energy"] ?? 0.5)),
            ("mood", 1 - (scores["mood"] ?? 0.5)),
            ("motivation", 1 - (scores["motivation"] ?? 0.5)),
            ("comfort", 1 - (scores["body_comfort"] ?? 0.5)),
        ]

        return pairs
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map(\.0)
    }

    private static func rewardScore(pre: [String: Double], post: [String: Double]) -> Double {
        let positiveIDs = ["physical_energy", "mental_energy", "mood", "motivation", "body_comfort"]
        let positiveDelta = positiveIDs
            .map { (post[$0] ?? 0.5) - (pre[$0] ?? 0.5) }
            .reduce(0, +) / Double(positiveIDs.count)

        let stressDelta = (pre["stress_load"] ?? 0.5) - (post["stress_load"] ?? 0.5)
        return min(max((positiveDelta * 0.72) + (stressDelta * 0.28), -1), 1)
    }

    private static func meanReward(for experiences: [StateActionLearningExperience]) -> Double {
        guard !experiences.isEmpty else { return 0 }
        return experiences.map(\.reward).reduce(0, +) / Double(experiences.count)
    }

    private static func normalizeReward(_ reward: Double) -> Double {
        min(max((reward + 1) / 2, 0), 1)
    }

    private static func learningLabel(for experienceCount: Int) -> String {
        switch experienceCount {
        case 0:
            return "Exploring"
        case 1 ... 3:
            return "Learning"
        case 4 ... 8:
            return "Adapting"
        default:
            return "Personalized"
        }
    }

    private static func loadPayload(profileID: UUID) -> StateActionLearningPayload {
        EncryptedStore.load(StateActionLearningPayload.self, forKey: storageKey(for: profileID)) ?? StateActionLearningPayload()
    }

    private static func savePayload(_ payload: StateActionLearningPayload, profileID: UUID) {
        EncryptedStore.save(payload, forKey: storageKey(for: profileID))
    }

    private static func loadLatestState(profileID: UUID) -> StateCheckInRecord? {
        (EncryptedStore.load([StateCheckInRecord].self, forKey: stateStorageKey(for: profileID)) ?? [])
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private static func storageKey(for profileID: UUID) -> String {
        "eir_state_action_learning_\(profileID.uuidString)"
    }

    private static func stateStorageKey(for profileID: UUID) -> String {
        "state_check_in_history_\(profileID.uuidString)"
    }
}

@MainActor
final class StateActionRecommendationViewModel: ObservableObject {
    @Published private(set) var recommendation: StateActionRecommendation?
    @Published private(set) var summary: StateActionLearningSummary = .empty

    func sync(profileID: UUID?, actions: [HealthAction], state: StateCheckInRecord?) {
        recommendation = StateActionLearningEngine.recommend(
            profileID: profileID,
            actions: actions,
            state: state
        )
        summary = StateActionLearningEngine.summary(profileID: profileID)
    }
}

import Foundation

enum NextBestHealthActionWedge: String, Codable, CaseIterable, Identifiable {
    case recovery

    var id: String { rawValue }
}

enum NextBestHealthActionState: String, Codable, CaseIterable, Identifiable {
    case recoverToday
    case steadyToday
    case watchClosely

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recoverToday: return "Recover today"
        case .steadyToday: return "Steady today"
        case .watchClosely: return "Watch closely"
        }
    }
}

enum NextBestHealthActionEscalationLevel: String, Codable {
    case none
    case reflect
    case careSuggestion
}

struct NextBestHealthActionDriver: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let detail: String?

    init(id: UUID = UUID(), title: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

struct NextBestHealthActionSnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let profileID: UUID?
    let wedge: NextBestHealthActionWedge
    let headline: String
    let summary: String
    let state: NextBestHealthActionState
    let confidence: Double
    let drivers: [NextBestHealthActionDriver]
    let signalSummary: [RecoverySignal]
    let recommendedActionID: String?
    let escalationLevel: NextBestHealthActionEscalationLevel
    let careSuggestion: CareSuggestion?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        profileID: UUID?,
        wedge: NextBestHealthActionWedge,
        headline: String,
        summary: String,
        state: NextBestHealthActionState,
        confidence: Double,
        drivers: [NextBestHealthActionDriver],
        signalSummary: [RecoverySignal],
        recommendedActionID: String?,
        escalationLevel: NextBestHealthActionEscalationLevel,
        careSuggestion: CareSuggestion?
    ) {
        self.id = id
        self.date = date
        self.profileID = profileID
        self.wedge = wedge
        self.headline = headline
        self.summary = summary
        self.state = state
        self.confidence = min(max(confidence, 0), 1)
        self.drivers = drivers
        self.signalSummary = signalSummary
        self.recommendedActionID = recommendedActionID
        self.escalationLevel = escalationLevel
        self.careSuggestion = careSuggestion
    }
}

struct RecoveryActionOutcome: Identifiable, Codable, Hashable {
    let id: UUID
    let actionID: String
    let date: Date
    var completed: Bool
    var helpfulnessRating: Int?
    var followUpStressRating: Int?
    var notes: String?

    init(
        id: UUID = UUID(),
        actionID: String,
        date: Date = Date(),
        completed: Bool,
        helpfulnessRating: Int? = nil,
        followUpStressRating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.actionID = actionID
        self.date = date
        self.completed = completed
        self.helpfulnessRating = helpfulnessRating.map { min(max($0, 1), 5) }
        self.followUpStressRating = followUpStressRating.map { min(max($0, 1), 5) }
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

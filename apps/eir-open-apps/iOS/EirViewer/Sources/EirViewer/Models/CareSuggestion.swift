import Foundation

enum SuggestedClinicType: String, Codable, CaseIterable, Identifiable {
    case primaryCare
    case psychiatry
    case psychology
    case rehab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primaryCare: return "Primary Care"
        case .psychiatry: return "Psychiatry"
        case .psychology: return "Psychology"
        case .rehab: return "Rehab"
        }
    }
}

struct CareSuggestion: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let profileID: UUID?
    let triggerReason: String
    let suggestedClinicTypes: [SuggestedClinicType]
    let questionPrompt: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        profileID: UUID?,
        triggerReason: String,
        suggestedClinicTypes: [SuggestedClinicType],
        questionPrompt: String
    ) {
        self.id = id
        self.date = date
        self.profileID = profileID
        self.triggerReason = triggerReason
        self.suggestedClinicTypes = suggestedClinicTypes
        self.questionPrompt = questionPrompt
    }
}

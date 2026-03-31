import Foundation

enum AdaptiveCheckInPromptID: String, Codable, CaseIterable, Identifiable {
    case defaultSymptoms
    case sleepTiming
    case mentalLoad
    case symptomTrend

    var id: String { rawValue }
}

enum DailyCheckInSymptom: String, Codable, CaseIterable, Identifiable {
    case anxious = "Anxiety"
    case headache = "Headache"
    case palpitations = "Palpitations"
    case fatigue = "Fatigue"
    case lowMood = "Low Mood"
    case bodyTension = "Body Tension"
    case poorSleep = "Poor Sleep"
    case dizziness = "Dizziness"
    case other = "Other"

    var id: String { rawValue }
}

struct DailyCheckIn: Identifiable, Codable, Hashable {
    let id: UUID
    let profileID: UUID
    let createdAt: Date
    var sleepRating: Int
    var stressRating: Int
    var energyRating: Int
    var symptoms: [DailyCheckInSymptom]
    var freeText: String?
    var voiceNoteAttachmentID: UUID?
    var adaptivePromptID: AdaptiveCheckInPromptID?

    init(
        id: UUID = UUID(),
        profileID: UUID,
        createdAt: Date = Date(),
        sleepRating: Int,
        stressRating: Int,
        energyRating: Int,
        symptoms: [DailyCheckInSymptom] = [],
        freeText: String? = nil,
        voiceNoteAttachmentID: UUID? = nil,
        adaptivePromptID: AdaptiveCheckInPromptID? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.createdAt = createdAt
        self.sleepRating = min(max(sleepRating, 1), 5)
        self.stressRating = min(max(stressRating, 1), 5)
        self.energyRating = min(max(energyRating, 1), 5)
        self.symptoms = symptoms
        self.freeText = freeText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.voiceNoteAttachmentID = voiceNoteAttachmentID
        self.adaptivePromptID = adaptivePromptID
    }

    var symptomBurdenScore: Double {
        min(Double(symptoms.count) / 3.0, 1.0)
    }

    var dayStamp: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: createdAt)
    }
}

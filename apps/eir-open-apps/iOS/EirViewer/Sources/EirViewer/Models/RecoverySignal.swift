import Foundation

enum RecoverySignalKind: String, Codable, CaseIterable, Identifiable {
    case sleepDurationHours
    case sleepRegularityHours
    case restingHeartRate
    case heartRateVariability
    case steps
    case workouts
    case selfReportedSleep
    case selfReportedStress
    case selfReportedEnergy
    case symptomBurden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleepDurationHours: return "Sleep Duration"
        case .sleepRegularityHours: return "Sleep Regularity"
        case .restingHeartRate: return "Resting Heart Rate"
        case .heartRateVariability: return "HRV"
        case .steps: return "Steps"
        case .workouts: return "Workouts"
        case .selfReportedSleep: return "Sleep Rating"
        case .selfReportedStress: return "Stress Rating"
        case .selfReportedEnergy: return "Energy Rating"
        case .symptomBurden: return "Symptoms"
        }
    }
}

enum RecoverySignalQuality: String, Codable {
    case measured
    case derived
    case selfReported
}

struct RecoverySignal: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let kind: RecoverySignalKind
    let value: Double
    let baseline: Double?
    let delta: Double?
    let quality: RecoverySignalQuality

    init(
        id: UUID = UUID(),
        date: Date,
        kind: RecoverySignalKind,
        value: Double,
        baseline: Double? = nil,
        delta: Double? = nil,
        quality: RecoverySignalQuality
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.value = value
        self.baseline = baseline
        self.delta = delta
        self.quality = quality
    }
}

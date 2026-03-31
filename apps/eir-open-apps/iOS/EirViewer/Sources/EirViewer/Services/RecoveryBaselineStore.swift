import Foundation

final class RecoveryBaselineStore {
    private(set) var checkIns: [DailyCheckIn] = []
    private(set) var outcomes: [RecoveryActionOutcome] = []
    private(set) var latestSnapshot: NextBestHealthActionSnapshot?

    private var profileID: UUID?

    func load(profileID: UUID?) {
        self.profileID = profileID
        checkIns = EncryptedStore.load([DailyCheckIn].self, forKey: checkInStorageKey) ?? []
        outcomes = EncryptedStore.load([RecoveryActionOutcome].self, forKey: outcomeStorageKey) ?? []
        latestSnapshot = EncryptedStore.load(NextBestHealthActionSnapshot.self, forKey: snapshotStorageKey)
    }

    func saveCheckIn(_ checkIn: DailyCheckIn) {
        guard profileID != nil else { return }

        var next = checkIns.filter { $0.dayStamp != checkIn.dayStamp }
        next.append(checkIn)
        next.sort { $0.createdAt > $1.createdAt }
        checkIns = Array(next.prefix(60))
        EncryptedStore.save(checkIns, forKey: checkInStorageKey)
    }

    func saveOutcome(_ outcome: RecoveryActionOutcome) {
        guard profileID != nil else { return }

        var next = outcomes.filter {
            !Calendar.current.isDate($0.date, inSameDayAs: outcome.date) || $0.actionID != outcome.actionID
        }
        next.append(outcome)
        next.sort { $0.date > $1.date }
        outcomes = Array(next.prefix(120))
        EncryptedStore.save(outcomes, forKey: outcomeStorageKey)
    }

    func saveSnapshot(_ snapshot: NextBestHealthActionSnapshot) {
        guard profileID != nil else { return }
        latestSnapshot = snapshot
        EncryptedStore.save(snapshot, forKey: snapshotStorageKey)
    }

    private var checkInStorageKey: String {
        "eir_next_action_check_ins_\(profileID?.uuidString ?? "global")"
    }

    private var outcomeStorageKey: String {
        "eir_next_action_outcomes_\(profileID?.uuidString ?? "global")"
    }

    private var snapshotStorageKey: String {
        "eir_next_action_snapshot_\(profileID?.uuidString ?? "global")"
    }
}

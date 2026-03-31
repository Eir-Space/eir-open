import Foundation

@MainActor
final class NextBestHealthActionViewModel: ObservableObject {
    @Published private(set) var snapshot: NextBestHealthActionSnapshot?
    @Published private(set) var metrics: HealthKitService.RecoveryMetrics = .empty
    @Published private(set) var recentCheckIns: [DailyCheckIn] = []
    @Published private(set) var recentOutcomes: [RecoveryActionOutcome] = []
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let baselineStore = RecoveryBaselineStore()
    private var currentProfileID: UUID?

    var latestCheckIn: DailyCheckIn? {
        recentCheckIns.sorted { $0.createdAt > $1.createdAt }.first
    }

    var hasCheckInToday: Bool {
        guard let latestCheckIn else { return false }
        return Calendar.current.isDateInToday(latestCheckIn.createdAt)
    }

    var measuredSignalCount: Int {
        snapshot?.signalSummary.filter { $0.quality == .measured }.count ?? 0
    }

    func sync(profileID: UUID?, document: EirDocument?, actions: [HealthAction]) async {
        guard let profileID else {
            currentProfileID = nil
            snapshot = nil
            recentCheckIns = []
            recentOutcomes = []
            metrics = .empty
            return
        }

        if currentProfileID != profileID {
            currentProfileID = profileID
            baselineStore.load(profileID: profileID)
            recentCheckIns = baselineStore.checkIns
            recentOutcomes = baselineStore.outcomes
            snapshot = baselineStore.latestSnapshot
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            metrics = try await HealthKitService.shared.loadRecoveryMetrics()
            errorMessage = nil
        } catch {
            // HealthKit access should not block a next-action recommendation.
            metrics = .empty
            errorMessage = nil
        }

        let nextSnapshot = NextBestHealthActionEngine.generateSnapshot(
            context: NextBestHealthActionContext(
                profileID: profileID,
                document: document,
                actions: actions,
                recentCheckIns: recentCheckIns,
                outcomes: recentOutcomes,
                metrics: metrics
            )
        )

        snapshot = nextSnapshot
        baselineStore.saveSnapshot(nextSnapshot)
    }

    func saveCheckIn(
        _ checkIn: DailyCheckIn,
        document: EirDocument?,
        actions: [HealthAction]
    ) async {
        guard currentProfileID == checkIn.profileID || currentProfileID == nil else { return }
        if currentProfileID == nil {
            currentProfileID = checkIn.profileID
            baselineStore.load(profileID: checkIn.profileID)
        }
        baselineStore.saveCheckIn(checkIn)
        recentCheckIns = baselineStore.checkIns
        await sync(profileID: checkIn.profileID, document: document, actions: actions)
    }

    func saveOutcome(
        _ outcome: RecoveryActionOutcome,
        document: EirDocument?,
        actions: [HealthAction]
    ) async {
        guard let currentProfileID else { return }
        baselineStore.saveOutcome(outcome)
        recentOutcomes = baselineStore.outcomes
        await sync(profileID: currentProfileID, document: document, actions: actions)
    }
}

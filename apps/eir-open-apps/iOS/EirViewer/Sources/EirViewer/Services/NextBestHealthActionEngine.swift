import Foundation

struct NextBestHealthActionContext {
    let profileID: UUID?
    let document: EirDocument?
    let actions: [HealthAction]
    let recentCheckIns: [DailyCheckIn]
    let outcomes: [RecoveryActionOutcome]
    let metrics: HealthKitService.RecoveryMetrics
}

enum NextBestHealthActionEngine {
    static func generateSnapshot(context: NextBestHealthActionContext) -> NextBestHealthActionSnapshot {
        DailyRecoveryStrategy.generateSnapshot(
            context: DailyRecoveryContext(
                profileID: context.profileID,
                document: context.document,
                actions: context.actions,
                recentCheckIns: context.recentCheckIns,
                outcomes: context.outcomes,
                metrics: context.metrics
            )
        )
    }
}

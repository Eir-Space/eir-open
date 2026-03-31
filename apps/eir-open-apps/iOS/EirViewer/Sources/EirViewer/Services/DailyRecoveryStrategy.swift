import Foundation

struct DailyRecoveryContext {
    let profileID: UUID?
    let document: EirDocument?
    let actions: [HealthAction]
    let recentCheckIns: [DailyCheckIn]
    let outcomes: [RecoveryActionOutcome]
    let metrics: HealthKitService.RecoveryMetrics
}

enum DailyRecoveryStrategy {
    static func generateSnapshot(context: DailyRecoveryContext) -> NextBestHealthActionSnapshot {
        let latestCheckIn = context.recentCheckIns.sorted { $0.createdAt > $1.createdAt }.first
        let signals = buildSignals(metrics: context.metrics, checkIn: latestCheckIn)
        let scored = score(signals: signals, outcomes: context.outcomes)
        let state = state(for: scored.score)
        let recommendedAction = pickAction(
            from: context.actions,
            state: state,
            signals: signals,
            latestCheckIn: latestCheckIn
        )
        let careSuggestion = careSuggestionIfNeeded(
            state: state,
            recentCheckIns: context.recentCheckIns,
            latestCheckIn: latestCheckIn
        )

        let headline = headline(for: state, latestCheckIn: latestCheckIn, signals: signals)
        let summary = summary(for: state, drivers: scored.drivers, recommendedAction: recommendedAction)
        let escalationLevel: NextBestHealthActionEscalationLevel = careSuggestion == nil
            ? (state == .steadyToday ? .none : .reflect)
            : .careSuggestion

        return NextBestHealthActionSnapshot(
            profileID: context.profileID,
            wedge: .recovery,
            headline: headline,
            summary: summary,
            state: state,
            confidence: confidence(for: signals),
            drivers: Array(scored.drivers.prefix(3)),
            signalSummary: signals,
            recommendedActionID: recommendedAction?.id,
            escalationLevel: escalationLevel,
            careSuggestion: careSuggestion
        )
    }

    private static func buildSignals(
        metrics: HealthKitService.RecoveryMetrics,
        checkIn: DailyCheckIn?
    ) -> [RecoverySignal] {
        var signals: [RecoverySignal] = []
        let now = Date()

        if let sleepHours = metrics.sleepHoursLastNight {
            let baseline = metrics.sleepHoursBaseline
            signals.append(
                RecoverySignal(
                    date: now,
                    kind: .sleepDurationHours,
                    value: sleepHours,
                    baseline: baseline,
                    delta: baseline.map { sleepHours - $0 },
                    quality: .measured
                )
            )
        }

        if let startHour = metrics.sleepStartHourLastNight {
            let baseline = metrics.sleepStartHourBaseline
            let absoluteDelta = baseline.map { abs(startHour - $0) }
            signals.append(
                RecoverySignal(
                    date: now,
                    kind: .sleepRegularityHours,
                    value: startHour,
                    baseline: baseline,
                    delta: absoluteDelta,
                    quality: .derived
                )
            )
        }

        if let restingHeartRate = metrics.restingHeartRateRecent {
            let baseline = metrics.restingHeartRateBaseline
            signals.append(
                RecoverySignal(
                    date: now,
                    kind: .restingHeartRate,
                    value: restingHeartRate,
                    baseline: baseline,
                    delta: baseline.map { restingHeartRate - $0 },
                    quality: .measured
                )
            )
        }

        if let heartRateVariability = metrics.heartRateVariabilityRecent {
            let baseline = metrics.heartRateVariabilityBaseline
            signals.append(
                RecoverySignal(
                    date: now,
                    kind: .heartRateVariability,
                    value: heartRateVariability,
                    baseline: baseline,
                    delta: baseline.map { heartRateVariability - $0 },
                    quality: .measured
                )
            )
        }

        if let steps = metrics.stepsYesterday {
            let baseline = metrics.stepsBaseline
            signals.append(
                RecoverySignal(
                    date: now,
                    kind: .steps,
                    value: steps,
                    baseline: baseline,
                    delta: baseline.map { steps - $0 },
                    quality: .measured
                )
            )
        }

        signals.append(
            RecoverySignal(
                date: now,
                kind: .workouts,
                value: Double(metrics.workoutsLast7Days),
                baseline: nil,
                delta: nil,
                quality: .derived
            )
        )

        if let checkIn {
            signals.append(
                RecoverySignal(
                    date: checkIn.createdAt,
                    kind: .selfReportedSleep,
                    value: Double(checkIn.sleepRating),
                    quality: .selfReported
                )
            )
            signals.append(
                RecoverySignal(
                    date: checkIn.createdAt,
                    kind: .selfReportedStress,
                    value: Double(checkIn.stressRating),
                    quality: .selfReported
                )
            )
            signals.append(
                RecoverySignal(
                    date: checkIn.createdAt,
                    kind: .selfReportedEnergy,
                    value: Double(checkIn.energyRating),
                    quality: .selfReported
                )
            )

            if !checkIn.symptoms.isEmpty {
                signals.append(
                    RecoverySignal(
                        date: checkIn.createdAt,
                        kind: .symptomBurden,
                        value: checkIn.symptomBurdenScore,
                        quality: .selfReported
                    )
                )
            }
        }

        return signals
    }

    private static func score(
        signals: [RecoverySignal],
        outcomes: [RecoveryActionOutcome]
    ) -> (score: Double, drivers: [NextBestHealthActionDriver]) {
        var score = 72.0
        var rankedDrivers: [(impact: Double, driver: NextBestHealthActionDriver)] = []

        for signal in signals {
            switch signal.kind {
            case .sleepDurationHours:
                guard let delta = signal.delta else { continue }
                if delta <= -1.0 {
                    score -= 14
                    rankedDrivers.append((14, .init(title: "Sleep dropped below your baseline", detail: "You slept about \(formatHours(abs(delta))) less than usual.")))
                } else if delta <= -0.5 {
                    score -= 8
                    rankedDrivers.append((8, .init(title: "Sleep was a bit shorter than usual", detail: "Your sleep duration was slightly below your recent norm.")))
                } else if delta >= 0.5 {
                    score += 4
                }

            case .sleepRegularityHours:
                guard let delta = signal.delta else { continue }
                if delta >= 1.5 {
                    score -= 8
                    rankedDrivers.append((8, .init(title: "Sleep timing was off", detail: "Your sleep started much later or earlier than your usual rhythm.")))
                } else if delta >= 0.75 {
                    score -= 4
                }

            case .restingHeartRate:
                guard let delta = signal.delta else { continue }
                if delta >= 6 {
                    score -= 10
                    rankedDrivers.append((10, .init(title: "Resting load looks elevated", detail: "Your resting heart rate is above your recent range.")))
                } else if delta >= 3 {
                    score -= 6
                }

            case .heartRateVariability:
                guard let delta = signal.delta else { continue }
                if delta <= -15 {
                    score -= 10
                    rankedDrivers.append((10, .init(title: "Recovery variability is down", detail: "Your HRV is below your recent baseline.")))
                } else if delta <= -8 {
                    score -= 6
                }

            case .steps:
                guard let baseline = signal.baseline, baseline > 0 else { continue }
                let ratio = signal.value / baseline
                if ratio < 0.6 {
                    score -= 5
                    rankedDrivers.append((5, .init(title: "Movement was lower than usual", detail: "Yesterday had less movement than your recent baseline.")))
                } else if ratio > 1.2 {
                    score += 2
                }

            case .selfReportedSleep:
                switch Int(signal.value.rounded()) {
                case 1:
                    score -= 14
                    rankedDrivers.append((14, .init(title: "You reported poor sleep", detail: "Your own check-in points to a rough night.")))
                case 2:
                    score -= 8
                case 4:
                    score += 4
                case 5:
                    score += 8
                default:
                    break
                }

            case .selfReportedStress:
                switch Int(signal.value.rounded()) {
                case 5:
                    score -= 18
                    rankedDrivers.append((18, .init(title: "Stress feels high today", detail: "Your check-in suggests the nervous system load is already high.")))
                case 4:
                    score -= 10
                    rankedDrivers.append((10, .init(title: "Stress is elevated today", detail: "A lighter, lower-friction action is likely more useful today.")))
                case 1:
                    score += 4
                default:
                    break
                }

            case .selfReportedEnergy:
                switch Int(signal.value.rounded()) {
                case 1:
                    score -= 14
                    rankedDrivers.append((14, .init(title: "Energy is low today", detail: "Today looks like a recovery-first day rather than a push day.")))
                case 2:
                    score -= 8
                case 5:
                    score += 8
                default:
                    break
                }

            case .symptomBurden:
                if signal.value >= 0.67 {
                    score -= 12
                    rankedDrivers.append((12, .init(title: "Symptoms are present today", detail: "Your check-in included several symptoms worth tracking.")))
                } else if signal.value >= 0.34 {
                    score -= 6
                }

            case .workouts:
                break
            }
        }

        let recentUnhelpfulOutcomes = outcomes
            .sorted { $0.date > $1.date }
            .prefix(3)
            .filter { ($0.helpfulnessRating ?? 3) <= 2 }
        if recentUnhelpfulOutcomes.count >= 2 {
            score -= 8
            rankedDrivers.append((8, .init(title: "Recent actions have not helped much", detail: "It may be time to shift from self-management alone to preparing for care.")))
        }

        score = min(max(score, 0), 100)
        let orderedDrivers = rankedDrivers
            .sorted { $0.impact > $1.impact }
            .map(\.driver)

        return (score, orderedDrivers)
    }

    private static func state(for score: Double) -> NextBestHealthActionState {
        switch score {
        case ..<45:
            return .watchClosely
        case ..<70:
            return .recoverToday
        default:
            return .steadyToday
        }
    }

    private static func pickAction(
        from actions: [HealthAction],
        state: NextBestHealthActionState,
        signals: [RecoverySignal],
        latestCheckIn: DailyCheckIn?
    ) -> HealthAction? {
        let highStress = latestCheckIn?.stressRating ?? 0 >= 4
        let lowSleep = latestCheckIn?.sleepRating ?? 5 <= 2
            || signals.contains { $0.kind == .sleepDurationHours && ($0.delta ?? 0) <= -0.5 }
        let lowMovement = signals.contains { signal in
            guard signal.kind == .steps, let baseline = signal.baseline, baseline > 0 else { return false }
            return signal.value / baseline < 0.6
        }
        let symptomsPresent = latestCheckIn?.symptoms.isEmpty == false

        let preferredCategories: [HealthActionCategory]
        if highStress {
            preferredCategories = [.breath, .recovery, .focus, .sleep, .movement]
        } else if lowSleep {
            preferredCategories = [.sleep, .breath, .recovery, .movement]
        } else if symptomsPresent && state == .watchClosely {
            preferredCategories = [.planning, .focus, .recovery]
        } else if lowMovement {
            preferredCategories = [.movement, .recovery, .hydration]
        } else {
            preferredCategories = [.movement, .hydration, .focus, .breath]
        }

        for category in preferredCategories {
            if let action = actions.first(where: { $0.category == category }) {
                return action
            }
        }

        return actions.first
    }

    private static func careSuggestionIfNeeded(
        state: NextBestHealthActionState,
        recentCheckIns: [DailyCheckIn],
        latestCheckIn: DailyCheckIn?
    ) -> CareSuggestion? {
        guard state == .watchClosely else { return nil }

        let recent = recentCheckIns.sorted { $0.createdAt > $1.createdAt }.prefix(5)
        let highStressStreak = recent.prefix(3).count == 3 && recent.prefix(3).allSatisfy { $0.stressRating >= 4 }
        let symptomsPersist = recent.filter { !$0.symptoms.isEmpty }.count >= 3
        guard highStressStreak || symptomsPersist || !(latestCheckIn?.symptoms.isEmpty ?? true) else {
            return nil
        }

        let symptoms = Set(latestCheckIn?.symptoms ?? [])
        let suggestedClinicTypes: [SuggestedClinicType]
        if symptoms.contains(.anxious) || symptoms.contains(.lowMood) || highStressStreak {
            suggestedClinicTypes = [.primaryCare, .psychology, .psychiatry]
        } else if symptoms.contains(.bodyTension) {
            suggestedClinicTypes = [.primaryCare, .rehab]
        } else {
            suggestedClinicTypes = [.primaryCare]
        }

        return CareSuggestion(
            profileID: latestCheckIn?.profileID,
            triggerReason: "Stress or symptom strain has repeated across recent check-ins.",
            suggestedClinicTypes: suggestedClinicTypes,
            questionPrompt: "Over the last few days I have noticed lower recovery and higher stress. What would be most useful to monitor or discuss next?"
        )
    }

    private static func headline(
        for state: NextBestHealthActionState,
        latestCheckIn: DailyCheckIn?,
        signals: [RecoverySignal]
    ) -> String {
        let highStress = latestCheckIn?.stressRating ?? 0 >= 4
        let lowSleep = latestCheckIn?.sleepRating ?? 5 <= 2
            || signals.contains { $0.kind == .sleepDurationHours && ($0.delta ?? 0) <= -0.5 }

        switch state {
        case .watchClosely:
            return highStress ? "Take a lighter day and keep an eye on this pattern" : "Protect your recovery today"
        case .recoverToday:
            return lowSleep ? "Protect your energy today" : "Make today a low-friction recovery day"
        case .steadyToday:
            return "Your recovery looks relatively steady today"
        }
    }

    private static func summary(
        for state: NextBestHealthActionState,
        drivers: [NextBestHealthActionDriver],
        recommendedAction: HealthAction?
    ) -> String {
        let driverText = drivers.first?.title ?? "Your recent signals suggest a simple action is worth doing today."
        if let recommendedAction {
            switch state {
            case .watchClosely:
                return "\(driverText). Start with \(recommendedAction.title.lowercased()) and keep the day lighter than usual."
            case .recoverToday:
                return "\(driverText). \(recommendedAction.title) is the best low-friction move for today."
            case .steadyToday:
                return "\(driverText). \(recommendedAction.title) can help you keep the day stable."
            }
        }

        return driverText
    }

    private static func confidence(for signals: [RecoverySignal]) -> Double {
        let measured = signals.filter { $0.quality == .measured }.count
        let selfReported = signals.filter { $0.quality == .selfReported }.count
        let raw = 0.25 + Double(measured) * 0.12 + Double(selfReported) * 0.08
        return min(max(raw, 0.3), 0.95)
    }

    private static func formatHours(_ hours: Double) -> String {
        if hours >= 1 {
            return String(format: "%.1f h", hours)
        }
        return String(format: "%.0f min", hours * 60)
    }
}

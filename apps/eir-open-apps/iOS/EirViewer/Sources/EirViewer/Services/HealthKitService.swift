import Foundation
import HealthKit

// MARK: - Data Types

enum HealthDataCategory: String, CaseIterable, Identifiable {
    case heartRate = "Hjärtfrekvens"
    case bloodPressure = "Blodtryck"
    case oxygenSaturation = "Syremättnad"
    case bodyTemperature = "Kroppstemperatur"
    case respiratoryRate = "Andningsfrekvens"
    case weight = "Vikt"
    case height = "Längd"
    case bloodGlucose = "Blodsocker"
    case steps = "Steg"
    case activeEnergy = "Aktiv energi"
    case workouts = "Träningspass"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .heartRate: return "heart.fill"
        case .bloodPressure: return "stethoscope"
        case .oxygenSaturation: return "lungs.fill"
        case .bodyTemperature: return "thermometer"
        case .respiratoryRate: return "wind"
        case .weight: return "scalemass.fill"
        case .height: return "ruler"
        case .bloodGlucose: return "drop.fill"
        case .steps: return "figure.walk"
        case .activeEnergy: return "flame.fill"
        case .workouts: return "figure.run"
        }
    }

    var eirCategory: String {
        switch self {
        case .heartRate, .bloodPressure, .oxygenSaturation, .bodyTemperature,
             .respiratoryRate, .weight, .height, .bloodGlucose:
            return "Lab"
        case .steps, .activeEnergy, .workouts:
            return "Hälsodata"
        }
    }

    var unit: String {
        switch self {
        case .heartRate: return "BPM"
        case .bloodPressure: return "mmHg"
        case .oxygenSaturation: return "%"
        case .bodyTemperature: return "°C"
        case .respiratoryRate: return "andetag/min"
        case .weight: return "kg"
        case .height: return "cm"
        case .bloodGlucose: return "mmol/L"
        case .steps: return "steg"
        case .activeEnergy: return "kcal"
        case .workouts: return ""
        }
    }

    /// Whether this type should be aggregated to daily summaries
    var aggregateDaily: Bool {
        switch self {
        case .heartRate, .oxygenSaturation, .respiratoryRate, .steps, .activeEnergy:
            return true
        default:
            return false
        }
    }

    var hkSampleType: HKSampleType? {
        switch self {
        case .heartRate:
            return HKQuantityType(.heartRate)
        case .bloodPressure:
            return HKCorrelationType(.bloodPressure)
        case .oxygenSaturation:
            return HKQuantityType(.oxygenSaturation)
        case .bodyTemperature:
            return HKQuantityType(.bodyTemperature)
        case .respiratoryRate:
            return HKQuantityType(.respiratoryRate)
        case .weight:
            return HKQuantityType(.bodyMass)
        case .height:
            return HKQuantityType(.height)
        case .bloodGlucose:
            return HKQuantityType(.bloodGlucose)
        case .steps:
            return HKQuantityType(.stepCount)
        case .activeEnergy:
            return HKQuantityType(.activeEnergyBurned)
        case .workouts:
            return HKWorkoutType.workoutType()
        }
    }

    var hkAuthorizationTypes: Set<HKObjectType> {
        switch self {
        case .bloodPressure:
            return [
                HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
                HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)
            ]
            .compactMap { $0 }
            .reduce(into: Set<HKObjectType>()) { partialResult, type in
                partialResult.insert(type)
            }
        default:
            guard let sampleType = hkSampleType else { return [] }
            return [sampleType]
        }
    }

    var hkUnit: HKUnit? {
        switch self {
        case .heartRate: return .count().unitDivided(by: .minute())
        case .bloodPressure: return .millimeterOfMercury()
        case .oxygenSaturation: return .percent()
        case .bodyTemperature: return .degreeCelsius()
        case .respiratoryRate: return .count().unitDivided(by: .minute())
        case .weight: return .gramUnit(with: .kilo)
        case .height: return .meterUnit(with: .centi)
        case .bloodGlucose: return .moleUnit(with: .milli, molarMass: HKUnitMolarMassBloodGlucose).unitDivided(by: .liter())
        case .steps: return .count()
        case .activeEnergy: return .kilocalorie()
        case .workouts: return nil
        }
    }
}

enum DateRangeOption: String, CaseIterable, Identifiable {
    case thirtyDays = "30 dagar"
    case sixMonths = "6 månader"
    case oneYear = "1 år"
    case allTime = "Allt"

    var id: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .thirtyDays: return cal.date(byAdding: .day, value: -30, to: now) ?? now
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: now) ?? now
        case .oneYear: return cal.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime: return cal.date(byAdding: .year, value: -50, to: now) ?? now
        }
    }
}

// MARK: - Service

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let calendar = Calendar.current

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var recoveryAuthorizationTypes: Set<HKObjectType> {
        [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKWorkoutType.workoutType(),
        ]
        .compactMap { $0 }
        .reduce(into: Set<HKObjectType>()) { partialResult, type in
            partialResult.insert(type)
        }
    }

    // MARK: - Authorization

    func requestAuthorization(for categories: [HealthDataCategory]) async throws {
        let readTypes = categories.reduce(into: Set<HKObjectType>()) { partialResult, category in
            partialResult.formUnion(category.hkAuthorizationTypes)
        }

        try await requestAuthorization(readTypes: readTypes)
    }

    func requestRecoveryAuthorization() async throws {
        try await requestAuthorization(readTypes: recoveryAuthorizationTypes)
    }

    private func requestAuthorization(readTypes: Set<HKObjectType>) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Sample Count

    func sampleCount(for category: HealthDataCategory, from startDate: Date) async throws -> Int {
        guard let sampleType = category.hkSampleType else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results?.count ?? 0)
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Query Samples

    func querySamples(for category: HealthDataCategory, from startDate: Date, to endDate: Date = Date()) async throws -> [HKSample] {
        guard let sampleType = category.hkSampleType else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: results ?? [])
                }
            }
            store.execute(query)
        }
    }

    // MARK: - Daily Statistics (for high-frequency data)

    struct RecoveryMetrics {
        let sleepHoursLastNight: Double?
        let sleepHoursBaseline: Double?
        let sleepStartHourLastNight: Double?
        let sleepStartHourBaseline: Double?
        let restingHeartRateRecent: Double?
        let restingHeartRateBaseline: Double?
        let heartRateVariabilityRecent: Double?
        let heartRateVariabilityBaseline: Double?
        let stepsYesterday: Double?
        let stepsBaseline: Double?
        let workoutsLast7Days: Int

        static let empty = RecoveryMetrics(
            sleepHoursLastNight: nil,
            sleepHoursBaseline: nil,
            sleepStartHourLastNight: nil,
            sleepStartHourBaseline: nil,
            restingHeartRateRecent: nil,
            restingHeartRateBaseline: nil,
            heartRateVariabilityRecent: nil,
            heartRateVariabilityBaseline: nil,
            stepsYesterday: nil,
            stepsBaseline: nil,
            workoutsLast7Days: 0
        )
    }

    struct DailyStat {
        let date: Date
        let min: Double?
        let avg: Double?
        let max: Double?
        let sum: Double?
    }

    func queryDailyStatistics(
        for category: HealthDataCategory,
        from startDate: Date,
        to endDate: Date = Date()
    ) async throws -> [DailyStat] {
        guard let quantityType = category.hkSampleType as? HKQuantityType,
              let unit = category.hkUnit else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        let options: HKStatisticsOptions
        switch category {
        case .steps, .activeEnergy:
            options = .cumulativeSum
        default:
            options = [.discreteMin, .discreteAverage, .discreteMax]
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: Calendar.current.startOfDay(for: startDate),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let collection = collection else {
                    continuation.resume(returning: [])
                    return
                }

                var stats: [DailyStat] = []
                collection.enumerateStatistics(from: startDate, to: endDate) { stat, _ in
                    let isCumulative = (category == .steps || category == .activeEnergy)

                    if isCumulative {
                        if let sum = stat.sumQuantity()?.doubleValue(for: unit) {
                            stats.append(DailyStat(date: stat.startDate, min: nil, avg: nil, max: nil, sum: sum))
                        }
                    } else {
                        let minVal = stat.minimumQuantity()?.doubleValue(for: unit)
                        let avgVal = stat.averageQuantity()?.doubleValue(for: unit)
                        let maxVal = stat.maximumQuantity()?.doubleValue(for: unit)
                        if minVal != nil || avgVal != nil || maxVal != nil {
                            stats.append(DailyStat(date: stat.startDate, min: minVal, avg: avgVal, max: maxVal, sum: nil))
                        }
                    }
                }
                continuation.resume(returning: stats)
            }

            store.execute(query)
        }
    }

    // MARK: - Recovery Signals

    func loadRecoveryMetrics(referenceDate: Date = Date()) async throws -> RecoveryMetrics {
        guard isAvailable else {
            return .empty
        }

        let today = calendar.startOfDay(for: referenceDate)
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        async let sleepSummaries = querySleepNightSummaries(from: twentyEightDaysAgo, to: referenceDate)
        async let recentRestingHeartRate = averageQuantity(
            identifier: .restingHeartRate,
            unit: .count().unitDivided(by: .minute()),
            startDate: threeDaysAgo,
            endDate: referenceDate
        )
        async let baselineRestingHeartRate = averageQuantity(
            identifier: .restingHeartRate,
            unit: .count().unitDivided(by: .minute()),
            startDate: twentyEightDaysAgo,
            endDate: threeDaysAgo
        )
        async let recentHeartRateVariability = averageQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            startDate: threeDaysAgo,
            endDate: referenceDate
        )
        async let baselineHeartRateVariability = averageQuantity(
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli),
            startDate: twentyEightDaysAgo,
            endDate: threeDaysAgo
        )
        async let recentStepStats = queryDailyStatistics(for: .steps, from: fourteenDaysAgo, to: referenceDate)
        async let recentWorkouts = querySamples(for: .workouts, from: sevenDaysAgo, to: referenceDate)

        let sleep = try await sleepSummaries
        let completeNights = sleep.filter { $0.bucketDate < today }
        let lastNight = completeNights.last
        let baselineNights = Array(completeNights.dropLast().suffix(14))

        let lastNightHours = lastNight?.totalHours
        let baselineSleepHours = average(baselineNights.map(\.totalHours))
        let lastNightStartHour = lastNight?.startHour
        let baselineSleepStartHour = average(baselineNights.map(\.startHour))

        let stepStats = try await recentStepStats
        let completeStepDays = stepStats
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted { $0.date < $1.date }
        let yesterdaySteps = completeStepDays.last?.sum
        let baselineSteps = average(completeStepDays.dropLast().compactMap(\.sum))

        return RecoveryMetrics(
            sleepHoursLastNight: lastNightHours,
            sleepHoursBaseline: baselineSleepHours,
            sleepStartHourLastNight: lastNightStartHour,
            sleepStartHourBaseline: baselineSleepStartHour,
            restingHeartRateRecent: try await recentRestingHeartRate,
            restingHeartRateBaseline: try await baselineRestingHeartRate,
            heartRateVariabilityRecent: try await recentHeartRateVariability,
            heartRateVariabilityBaseline: try await baselineHeartRateVariability,
            stepsYesterday: yesterdaySteps,
            stepsBaseline: baselineSteps,
            workoutsLast7Days: (try await recentWorkouts).count
        )
    }

    private func averageQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> Double? {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let samples = (results as? [HKQuantitySample]) ?? []
                guard !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let total = samples.reduce(0.0) { partialResult, sample in
                    partialResult + sample.quantity.doubleValue(for: unit)
                }
                continuation.resume(returning: total / Double(samples.count))
            }
            store.execute(query)
        }
    }

    private func querySleepNightSummaries(from startDate: Date, to endDate: Date) async throws -> [SleepNightSummary] {
        guard let sampleType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let calendar = self.calendar

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let samples = (results as? [HKCategorySample]) ?? []
                guard !samples.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                var totals: [Date: Double] = [:]
                var earliestStart: [Date: Date] = [:]

                for sample in samples where Self.isAsleepSleepValue(sample.value) {
                    let bucketDate = Self.sleepBucketDate(for: sample.endDate, calendar: calendar)
                    totals[bucketDate, default: 0] += sample.endDate.timeIntervalSince(sample.startDate) / 3600

                    if let current = earliestStart[bucketDate] {
                        earliestStart[bucketDate] = min(current, sample.startDate)
                    } else {
                        earliestStart[bucketDate] = sample.startDate
                    }
                }

                let summaries = totals.keys.sorted().compactMap { date -> SleepNightSummary? in
                    guard let totalHours = totals[date] else { return nil }
                    let start = earliestStart[date] ?? date
                    let components = calendar.dateComponents([.hour, .minute], from: start)
                    let startHour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
                    return SleepNightSummary(bucketDate: date, totalHours: totalHours, startHour: startHour)
                }

                continuation.resume(returning: summaries)
            }
            store.execute(query)
        }
    }

    private func average<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        let array = Array(values)
        guard !array.isEmpty else { return nil }
        return array.reduce(0, +) / Double(array.count)
    }

    private static func isAsleepSleepValue(_ value: Int) -> Bool {
        guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: value) else { return false }
        switch sleepValue {
        case .awake, .inBed:
            return false
        default:
            return true
        }
    }

    private static func sleepBucketDate(for endDate: Date, calendar: Calendar) -> Date {
        let shifted = endDate.addingTimeInterval(-12 * 60 * 60)
        return calendar.startOfDay(for: shifted)
    }

    private struct SleepNightSummary {
        let bucketDate: Date
        let totalHours: Double
        let startHour: Double
    }
}

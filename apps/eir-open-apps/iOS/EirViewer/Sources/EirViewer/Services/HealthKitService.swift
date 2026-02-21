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
        switch self {
        case .thirtyDays: return cal.date(byAdding: .day, value: -30, to: Date())!
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: Date())!
        case .oneYear: return cal.date(byAdding: .year, value: -1, to: Date())!
        case .allTime: return cal.date(byAdding: .year, value: -50, to: Date())!
        }
    }
}

// MARK: - Service

final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization(for categories: [HealthDataCategory]) async throws {
        let readTypes: Set<HKSampleType> = Set(categories.compactMap(\.hkSampleType))

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
}

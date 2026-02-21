import Foundation
import HealthKit

@MainActor
class HealthKitImportViewModel: ObservableObject {

    enum ImportPhase: Equatable {
        case selectingTypes
        case authorizing
        case importing
        case preview
        case saving
        case complete(URL)
        case error(String)
    }

    @Published var phase: ImportPhase = .selectingTypes
    @Published var selectedDateRange: DateRangeOption = .sixMonths
    @Published var selectedCategories: Set<HealthDataCategory> = Set(HealthDataCategory.allCases)
    @Published var sampleCounts: [HealthDataCategory: Int] = [:]
    @Published var importProgress: Double = 0
    @Published var importedEntryCount: Int = 0
    @Published var categoryCounts: [String: Int] = [:]

    private let service = HealthKitService.shared
    private var importedDocument: EirDocument?

    var isHealthKitAvailable: Bool {
        service.isAvailable
    }

    // MARK: - Load Sample Counts

    func loadSampleCounts() async {
        let startDate = selectedDateRange.startDate
        for category in HealthDataCategory.allCases {
            do {
                let count = try await service.sampleCount(for: category, from: startDate)
                sampleCounts[category] = count
            } catch {
                sampleCounts[category] = 0
            }
        }
    }

    // MARK: - Import Flow

    func startImport(patientName: String?) async {
        let categories = Array(selectedCategories)
        guard !categories.isEmpty else {
            phase = .error("Välj minst en datatyp att importera.")
            return
        }

        // Authorize
        phase = .authorizing
        do {
            try await service.requestAuthorization(for: categories)
        } catch {
            phase = .error("Kunde inte få behörighet till Apple Health: \(error.localizedDescription)")
            return
        }

        // Import
        phase = .importing
        importProgress = 0

        let startDate = selectedDateRange.startDate
        let endDate = Date()
        let totalSteps = Double(categories.count)
        var currentStep: Double = 0

        var dailyStats: [(HealthDataCategory, [HealthKitService.DailyStat])] = []
        var individualSamples: [(HealthDataCategory, [HKSample])] = []

        for category in categories {
            do {
                if category.aggregateDaily {
                    let stats = try await service.queryDailyStatistics(for: category, from: startDate, to: endDate)
                    if !stats.isEmpty {
                        dailyStats.append((category, stats))
                    }
                } else {
                    let samples = try await service.querySamples(for: category, from: startDate, to: endDate)
                    if !samples.isEmpty {
                        individualSamples.append((category, samples))
                    }
                }
            } catch {
                // Skip failed categories silently
            }

            currentStep += 1
            importProgress = currentStep / totalSteps
        }

        // Convert
        let document = HealthKitToEirConverter.convert(
            dailyStats: dailyStats,
            individualSamples: individualSamples,
            patientName: patientName
        )

        importedDocument = document
        importedEntryCount = document.entries.count

        // Build category breakdown
        var counts: [String: Int] = [:]
        for entry in document.entries {
            let key = entry.type ?? entry.category ?? "Okänt"
            counts[key, default: 0] += 1
        }
        categoryCounts = counts

        if document.entries.isEmpty {
            phase = .error("Ingen hälsodata hittades för den valda perioden.")
        } else {
            phase = .preview
        }
    }

    // MARK: - Save

    func save() -> URL? {
        guard let document = importedDocument else { return nil }
        phase = .saving

        do {
            let yaml = try HealthKitToEirConverter.serializeToYAML(document)
            let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
                .replacingOccurrences(of: "/", with: "-")
            let fileName = "apple-health-\(dateStr).eir"
            let url = try HealthKitToEirConverter.saveToDocuments(yaml, fileName: fileName)
            phase = .complete(url)
            return url
        } catch {
            phase = .error("Kunde inte spara filen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Reset

    func reset() {
        phase = .selectingTypes
        importProgress = 0
        importedEntryCount = 0
        categoryCounts = [:]
        importedDocument = nil
    }
}

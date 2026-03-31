import Foundation

actor SelfReferralClinicCatalog {
    static let shared = SelfReferralClinicCatalog()

    private var cachedClinics: [SelfReferralClinic]?

    func loadClinics() throws -> [SelfReferralClinic] {
        if let cachedClinics {
            return cachedClinics
        }

        guard let url = Bundle.main.url(forResource: "self-referral-clinics-sweden", withExtension: "json") else {
            throw CatalogError.missingBundleResource
        }

        let data = try Data(contentsOf: url)
        let dataset = try JSONDecoder().decode(SelfReferralClinicDataset.self, from: data)
        cachedClinics = dataset.clinics
        return dataset.clinics
    }
}

extension SelfReferralClinicCatalog {
    enum CatalogError: LocalizedError {
        case missingBundleResource

        var errorDescription: String? {
            switch self {
            case .missingBundleResource:
                return "The verified self-referral clinic dataset is missing from the app bundle."
            }
        }
    }
}

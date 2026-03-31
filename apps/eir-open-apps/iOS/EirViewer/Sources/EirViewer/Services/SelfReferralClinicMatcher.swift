import CoreLocation
import Foundation

enum SelfReferralClinicMatcher {
    static func rankedClinics(
        from clinics: [SelfReferralClinic],
        query: String,
        suggestedTypes: Set<SuggestedClinicType>,
        userLocation: CLLocation?,
        limit: Int = 20
    ) -> [SelfReferralClinicMatch] {
        clinics
            .compactMap { match(for: $0, query: query, suggestedTypes: suggestedTypes, userLocation: userLocation) }
            .sorted(by: compareMatches)
            .prefix(limit)
            .map { $0 }
    }

    private static func match(
        for clinic: SelfReferralClinic,
        query: String,
        suggestedTypes: Set<SuggestedClinicType>,
        userLocation: CLLocation?
    ) -> SelfReferralClinicMatch? {
        let normalizedQuery = normalize(query)
        let text = searchableText(for: clinic)

        let suggestionScore = scoreSuggestedTypes(suggestedTypes, clinic: clinic, text: text)
        let queryScore = scoreQuery(normalizedQuery, clinic: clinic, text: text)
        let distanceKm = userLocation.flatMap { distance(from: $0, to: clinic) }
        let distanceScore = distanceKm.map(scoreDistance) ?? 0

        if !suggestedTypes.isEmpty && suggestionScore == 0 {
            return nil
        }

        if !normalizedQuery.isEmpty && queryScore == 0 {
            return nil
        }

        let accessScore = (clinic.access.has1177EServices ? 8 : 0)
            + (!clinic.access.bookingActions.isEmpty ? 6 : 0)
            + (!clinic.selfReferral.actions.isEmpty ? 8 : 0)

        let score = suggestionScore + queryScore + distanceScore + accessScore
        guard score > 0 else { return nil }

        return SelfReferralClinicMatch(
            clinic: clinic,
            score: score,
            distanceKm: distanceKm
        )
    }

    private static func scoreSuggestedTypes(
        _ suggestedTypes: Set<SuggestedClinicType>,
        clinic: SelfReferralClinic,
        text: String
    ) -> Int {
        guard !suggestedTypes.isEmpty else { return 12 }

        return suggestedTypes
            .map { bonus(for: $0, clinic: clinic, text: text) }
            .max() ?? 0
    }

    private static func bonus(
        for suggestedType: SuggestedClinicType,
        clinic: SelfReferralClinic,
        text: String
    ) -> Int {
        switch suggestedType {
        case .primaryCare:
            if clinic.type == .primaryCare { return 90 }
            if clinic.tags.contains("primary_care") { return 75 }
            if text.contains("vardcentral") { return 70 }
            return 0

        case .psychiatry:
            if clinic.specialties.contains("psychiatry") { return 96 }
            if clinic.tags.contains("psychiatry") { return 88 }
            if clinic.type == .mentalHealth { return 80 }
            if text.contains("psyki") { return 72 }
            return 0

        case .psychology:
            if text.contains("psykolog") || text.contains("psycholog") || text.contains("samtalsterapi") {
                return 94
            }
            if clinic.type == .mentalHealth { return 78 }
            if clinic.specialties.contains("psychiatry") || clinic.tags.contains("psychiatry") {
                return 32
            }
            return 0

        case .rehab:
            let rehabTerms = ["rehab", "rehabil", "fysio", "fysioterapi", "sjukgymnast", "stress"]
            if rehabTerms.contains(where: text.contains) { return 92 }
            if clinic.tags.contains("primary_care") { return 22 }
            return 0
        }
    }

    private static func scoreQuery(
        _ normalizedQuery: String,
        clinic: SelfReferralClinic,
        text: String
    ) -> Int {
        guard !normalizedQuery.isEmpty else { return 0 }

        let exactFields = [
            normalize(clinic.location.municipality),
            normalize(clinic.location.county)
        ]

        if exactFields.contains(normalizedQuery) {
            return 120
        }

        var score = 0
        let name = normalize(clinic.name)
        let municipality = normalize(clinic.location.municipality)
        let county = normalize(clinic.location.county)
        let address = normalize(clinic.location.address)

        if name.contains(normalizedQuery) { score += 92 }
        if municipality.contains(normalizedQuery) { score += 74 }
        if county.contains(normalizedQuery) { score += 66 }
        if address.contains(normalizedQuery) { score += 58 }
        if text.contains(normalizedQuery) { score += 26 }

        let tokens = normalizedQuery.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count > 1 {
            let tokenHits = tokens.filter { token in
                guard !token.isEmpty else { return false }
                return text.contains(token)
            }.count
            score += min(tokenHits * 12, 36)
        }

        return score
    }

    private static func scoreDistance(_ distanceKm: Double) -> Int {
        switch distanceKm {
        case ..<5: return 46
        case ..<20: return 36
        case ..<50: return 24
        case ..<100: return 14
        case ..<200: return 6
        default: return 0
        }
    }

    private static func searchableText(for clinic: SelfReferralClinic) -> String {
        let parts: [String?] = [
            clinic.name,
            clinic.type.rawValue,
            clinic.location.address,
            clinic.location.municipality,
            clinic.location.county,
            clinic.tags.joined(separator: " "),
            clinic.specialties.joined(separator: " "),
            clinic.summary,
            clinic.firstActionLabel
        ]
        return normalize(parts.compactMap { $0 }.joined(separator: " "))
    }

    private static func distance(from location: CLLocation, to clinic: SelfReferralClinic) -> Double? {
        guard let coordinate = clinic.coordinate else { return nil }
        let clinicLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: clinicLocation) / 1000
    }

    private static func compareMatches(_ lhs: SelfReferralClinicMatch, _ rhs: SelfReferralClinicMatch) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        switch (lhs.distanceKm, rhs.distanceKm) {
        case let (left?, right?) where left != right:
            return left < right
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhs.clinic.name.localizedCaseInsensitiveCompare(rhs.clinic.name) == .orderedAscending
        }
    }

    private static func normalize(_ value: String?) -> String {
        (value ?? "")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

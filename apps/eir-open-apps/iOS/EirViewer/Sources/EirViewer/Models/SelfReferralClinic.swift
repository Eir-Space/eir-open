import CoreLocation
import Foundation

enum SelfReferralClinicType: String, Codable, CaseIterable, Hashable, Sendable {
    case specialist
    case primaryCare = "primary_care"
    case hospital
    case other
    case maternity
    case mentalHealth = "mental_health"

    var title: String {
        switch self {
        case .specialist: return "Specialist"
        case .primaryCare: return "Primary Care"
        case .hospital: return "Hospital"
        case .other: return "Other"
        case .maternity: return "Maternity"
        case .mentalHealth: return "Mental Health"
        }
    }
}

struct SelfReferralClinicDataset: Codable, Hashable, Sendable {
    let clinics: [SelfReferralClinic]
}

struct SelfReferralClinic: Codable, Identifiable, Hashable, Sendable {
    struct Location: Codable, Hashable, Sendable {
        let address: String?
        let municipality: String?
        let county: String?
        let lat: Double?
        let lng: Double?
    }

    struct Contact: Codable, Hashable, Sendable {
        let phone: String?
    }

    struct Links: Codable, Hashable, Sendable {
        let profile1177: String
        let website: String?

        enum CodingKeys: String, CodingKey {
            case profile1177 = "profile_1177"
            case website
        }
    }

    struct SelfReferralEvidence: Codable, Hashable, Sendable {
        let text: String
        let actionCode: String?
        let excerpt: String?
        let url: String?

        enum CodingKeys: String, CodingKey {
            case text
            case actionCode = "action_code"
            case excerpt
            case url
        }
    }

    struct SelfReferralInfo: Codable, Hashable, Sendable {
        let verified: Bool
        let verificationStatus: String?
        let actions: [String]
        let evidence: [SelfReferralEvidence]

        enum CodingKeys: String, CodingKey {
            case verified
            case verificationStatus = "verification_status"
            case actions
            case evidence
        }
    }

    struct Access: Codable, Hashable, Sendable {
        let has1177EServices: Bool
        let videoConsultation: Bool
        let bookingActions: [String]

        enum CodingKeys: String, CodingKey {
            case has1177EServices = "has_1177_e_services"
            case videoConsultation = "video_consultation"
            case bookingActions = "booking_actions"
        }
    }

    let id: String
    let hsaID: String
    let name: String
    let type: SelfReferralClinicType
    let specialties: [String]
    let tags: [String]
    let location: Location
    let contact: Contact
    let links: Links
    let selfReferral: SelfReferralInfo
    let access: Access
    let summary: String

    enum CodingKeys: String, CodingKey {
        case id
        case hsaID = "hsa_id"
        case name
        case type
        case specialties
        case tags
        case location
        case contact
        case links
        case selfReferral = "self_referral"
        case access
        case summary
    }

    init(
        id: String,
        hsaID: String? = nil,
        name: String,
        type: SelfReferralClinicType,
        specialties: [String] = [],
        tags: [String] = [],
        location: Location,
        contact: Contact = Contact(phone: nil),
        links: Links,
        selfReferral: SelfReferralInfo,
        access: Access = Access(has1177EServices: true, videoConsultation: false, bookingActions: []),
        summary: String = ""
    ) {
        self.id = id
        self.hsaID = hsaID ?? id
        self.name = name
        self.type = type
        self.specialties = specialties
        self.tags = tags
        self.location = location
        self.contact = contact
        self.links = links
        self.selfReferral = selfReferral
        self.access = access
        self.summary = summary
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = location.lat, let lng = location.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var displayLocationLine: String {
        var parts: [String] = []
        if let municipality = location.municipality, !municipality.isEmpty {
            parts.append(municipality)
        }
        if let county = location.county, !county.isEmpty {
            parts.append(county)
        }
        if !parts.isEmpty {
            return parts.joined(separator: ", ")
        }
        return location.address ?? "Location unavailable"
    }

    var firstActionLabel: String? {
        selfReferral.actions.first
    }

    var firstEvidence: SelfReferralEvidence? {
        selfReferral.evidence.first
    }

    var selfReferralURL: URL? {
        selfReferral.evidence
            .compactMap(\.url)
            .compactMap(URL.init(string:))
            .first
    }

    var selfReferralButtonTitle: String {
        if let firstActionLabel, !firstActionLabel.isEmpty {
            return firstActionLabel
        }
        return "Start egenremiss on 1177"
    }
}

struct SelfReferralClinicMatch: Identifiable, Hashable, Sendable {
    let clinic: SelfReferralClinic
    let score: Int
    let distanceKm: Double?

    var id: String { clinic.id }
}

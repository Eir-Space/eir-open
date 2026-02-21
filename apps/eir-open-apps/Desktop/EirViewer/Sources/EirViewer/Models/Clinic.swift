import Foundation
import CoreLocation

struct Clinic: Codable, Identifiable {
    let hsaId: String
    let name: String
    let address: String?
    let phone: String?
    let internationalPhone: String?
    let url: String?
    let lat: Double?
    let lng: Double?
    let hasMvkServices: Bool
    let hasListing: Bool
    let videoOrChat: Bool
    let vaccinatesForFlu: Bool
    let vaccinatesForCovid19: Bool

    var id: String { hsaId }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

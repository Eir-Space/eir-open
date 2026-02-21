import Foundation

struct PersonProfile: Codable, Identifiable {
    let id: UUID
    var displayName: String
    let fileURL: URL
    let patientName: String?
    var personalNumber: String?
    var birthDate: String?
    let totalEntries: Int?
    let addedAt: Date

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

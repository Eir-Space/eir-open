import Foundation

struct EirDocument: Codable {
    let metadata: EirMetadata
    let entries: [EirEntry]
}

struct EirMetadata: Codable {
    let formatVersion: String?
    let createdAt: String?
    let source: String?
    let patient: EirPatient?
    let exportInfo: EirExportInfo?

    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case createdAt = "created_at"
        case source
        case patient
        case exportInfo = "export_info"
    }
}

struct EirPatient: Codable {
    let name: String?
    let birthDate: String?
    let personalNumber: String?

    enum CodingKeys: String, CodingKey {
        case name
        case birthDate = "birth_date"
        case personalNumber = "personal_number"
    }
}

struct EirExportInfo: Codable {
    let totalEntries: Int?
    let dateRange: EirDateRange?
    let healthcareProviders: [String]?

    enum CodingKeys: String, CodingKey {
        case totalEntries = "total_entries"
        case dateRange = "date_range"
        case healthcareProviders = "healthcare_providers"
    }
}

struct EirDateRange: Codable {
    let start: String?
    let end: String?
}

struct EirEntry: Codable, Identifiable {
    let id: String
    let date: String?
    let time: String?
    let category: String?
    let type: String?
    let provider: EirProvider?
    let status: String?
    let responsiblePerson: EirResponsiblePerson?
    let content: EirContent?
    let attachments: [String]?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case id, date, time, category, type, provider, status
        case responsiblePerson = "responsible_person"
        case content, attachments, tags
    }

    var displayDate: String {
        date ?? ""
    }

    var parsedDate: Date? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var dateGroupKey: String {
        guard let parsed = parsedDate else { return date ?? "Okänt datum" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter.string(from: parsed)
    }
}

struct EirProvider: Codable {
    let name: String?
    let region: String?
    let location: String?
}

struct EirResponsiblePerson: Codable {
    let name: String?
    let role: String?
}

struct EirContent: Codable {
    let summary: String?
    let details: String?
    let notes: [String]?
}

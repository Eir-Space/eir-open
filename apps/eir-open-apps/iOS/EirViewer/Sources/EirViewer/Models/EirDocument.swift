import Foundation

struct EirDocument: Codable {
    let metadata: EirMetadata
    let entries: [EirEntry]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decodeIfPresent(EirMetadata.self, forKey: .metadata) ?? EirMetadata()
        entries = try container.decodeIfPresent([SafeEntry].self, forKey: .entries)?.compactMap(\.entry) ?? []
    }

    init(metadata: EirMetadata, entries: [EirEntry]) {
        self.metadata = metadata
        self.entries = entries
    }

    /// Wrapper that skips individual entries that fail to decode instead of failing the whole document.
    private struct SafeEntry: Decodable {
        let entry: EirEntry?
        init(from decoder: Decoder) throws {
            entry = try? EirEntry(from: decoder)
        }
    }
}

struct EirMetadata: Codable {
    let formatVersion: String?
    let createdAt: String?
    let source: String?
    let patient: EirPatient?
    let exportInfo: EirExportInfo?

    init(formatVersion: String? = nil, createdAt: String? = nil, source: String? = nil, patient: EirPatient? = nil, exportInfo: EirExportInfo? = nil) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.source = source
        self.patient = patient
        self.exportInfo = exportInfo
    }

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

    init(totalEntries: Int? = nil, dateRange: EirDateRange? = nil, healthcareProviders: [String]? = nil) {
        self.totalEntries = totalEntries
        self.dateRange = dateRange
        self.healthcareProviders = healthcareProviders
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // total_entries can be int or string
        if let n = try? container.decodeIfPresent(Int.self, forKey: .totalEntries) {
            totalEntries = n
        } else if let s = try? container.decodeIfPresent(String.self, forKey: .totalEntries) {
            totalEntries = Int(s)
        } else {
            totalEntries = nil
        }
        dateRange = try container.decodeIfPresent(EirDateRange.self, forKey: .dateRange)
        healthcareProviders = try container.decodeIfPresent([String].self, forKey: .healthcareProviders)
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

    init(id: String, date: String?, time: String?, category: String?, type: String?, provider: EirProvider?, status: String?, responsiblePerson: EirResponsiblePerson?, content: EirContent?, attachments: [String]?, tags: [String]?) {
        self.id = id
        self.date = date
        self.time = time
        self.category = category
        self.type = type
        self.provider = provider
        self.status = status
        self.responsiblePerson = responsiblePerson
        self.content = content
        self.attachments = attachments
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id falls back to a generated UUID if missing
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        date = try container.decodeIfPresent(String.self, forKey: .date)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        provider = try container.decodeIfPresent(EirProvider.self, forKey: .provider)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        responsiblePerson = try container.decodeIfPresent(EirResponsiblePerson.self, forKey: .responsiblePerson)
        content = try container.decodeIfPresent(EirContent.self, forKey: .content)
        attachments = try container.decodeIfPresent([String].self, forKey: .attachments)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
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

    init(summary: String?, details: String?, notes: [String]?) {
        self.summary = summary
        self.details = details
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)

        // details can be a string or an array of strings
        if let str = try? container.decodeIfPresent(String.self, forKey: .details) {
            details = str
        } else if let arr = try? container.decodeIfPresent([String].self, forKey: .details) {
            details = arr.joined(separator: "\n")
        } else {
            details = nil
        }

        // notes can be a string or an array of strings
        if let arr = try? container.decodeIfPresent([String].self, forKey: .notes) {
            notes = arr
        } else if let str = try? container.decodeIfPresent(String.self, forKey: .notes) {
            notes = str.isEmpty ? nil : [str]
        } else {
            notes = nil
        }
    }
}

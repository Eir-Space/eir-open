import Foundation

struct PersonProfile: Codable, Identifiable {
    let id: UUID
    var displayName: String
    let fileName: String
    let patientName: String?
    let personalNumber: String?
    let birthDate: String?
    let totalEntries: Int?
    let addedAt: Date

    /// Resolves the full file URL from the current Documents directory.
    /// This is computed at runtime because the iOS sandbox container path
    /// changes between app launches.
    var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    // MARK: - Migration from old format

    enum CodingKeys: String, CodingKey {
        case id, displayName, fileName, fileURL, patientName, personalNumber, birthDate, totalEntries, addedAt
    }

    init(id: UUID, displayName: String, fileName: String, patientName: String?, personalNumber: String?, birthDate: String?, totalEntries: Int?, addedAt: Date) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
        self.patientName = patientName
        self.personalNumber = personalNumber
        self.birthDate = birthDate
        self.totalEntries = totalEntries
        self.addedAt = addedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        patientName = try container.decodeIfPresent(String.self, forKey: .patientName)
        personalNumber = try container.decodeIfPresent(String.self, forKey: .personalNumber)
        birthDate = try container.decodeIfPresent(String.self, forKey: .birthDate)
        totalEntries = try container.decodeIfPresent(Int.self, forKey: .totalEntries)
        addedAt = try container.decode(Date.self, forKey: .addedAt)

        // Try new fileName key first, then migrate from old fileURL key
        if let name = try container.decodeIfPresent(String.self, forKey: .fileName) {
            fileName = name
        } else {
            let url = try container.decode(URL.self, forKey: .fileURL)
            fileName = url.lastPathComponent
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(patientName, forKey: .patientName)
        try container.encode(personalNumber, forKey: .personalNumber)
        try container.encode(birthDate, forKey: .birthDate)
        try container.encode(totalEntries, forKey: .totalEntries)
        try container.encode(addedAt, forKey: .addedAt)
    }
}

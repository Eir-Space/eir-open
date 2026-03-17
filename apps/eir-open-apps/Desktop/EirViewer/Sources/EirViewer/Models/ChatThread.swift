import Foundation

struct ChatThread: Codable, Identifiable {
    let id: UUID
    let profileID: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var excludedEntryIDs: Set<String>

    init(id: UUID, profileID: UUID, title: String, createdAt: Date, updatedAt: Date, excludedEntryIDs: Set<String> = []) {
        self.id = id
        self.profileID = profileID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.excludedEntryIDs = excludedEntryIDs
    }

    // Backward-compatible decoding — existing threads without excludedEntryIDs default to empty
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        profileID = try container.decode(UUID.self, forKey: .profileID)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        excludedEntryIDs = (try? container.decode(Set<String>.self, forKey: .excludedEntryIDs)) ?? []
    }
}

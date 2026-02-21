import Foundation

struct ChatThread: Codable, Identifiable {
    let id: UUID
    let profileID: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
}

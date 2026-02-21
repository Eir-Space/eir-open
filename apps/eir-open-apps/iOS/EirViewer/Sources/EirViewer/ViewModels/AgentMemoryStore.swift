import Foundation
import SwiftUI

@MainActor
class AgentMemoryStore: ObservableObject {
    @Published var memory = AgentMemory(
        soul: AgentDefaults.defaultSoul,
        user: AgentDefaults.defaultUser,
        memory: AgentDefaults.defaultMemory,
        agents: AgentDefaults.defaultAgents
    )

    private var profileID: UUID?

    // MARK: - File Paths

    private func agentDirectory(for profileID: UUID) -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("EirViewer")
            .appendingPathComponent("agent")
            .appendingPathComponent(profileID.uuidString)
    }

    private func filePath(_ name: String) -> URL? {
        guard let profileID else { return nil }
        return agentDirectory(for: profileID).appendingPathComponent(name)
    }

    // MARK: - Load & Save

    func load(profileID: UUID) {
        self.profileID = profileID
        let dir = agentDirectory(for: profileID)

        // Create directory if missing
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        memory.soul = readOrCreate(dir: dir, name: "SOUL.md", fallback: AgentDefaults.defaultSoul)
        memory.user = readOrCreate(dir: dir, name: "USER.md", fallback: AgentDefaults.defaultUser)
        memory.memory = readOrCreate(dir: dir, name: "MEMORY.md", fallback: AgentDefaults.defaultMemory)
        memory.agents = readOrCreate(dir: dir, name: "AGENTS.md", fallback: AgentDefaults.defaultAgents)
    }

    func save() {
        guard let profileID else { return }
        let dir = agentDirectory(for: profileID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        writeFile(dir: dir, name: "SOUL.md", content: memory.soul)
        writeFile(dir: dir, name: "USER.md", content: memory.user)
        writeFile(dir: dir, name: "MEMORY.md", content: memory.memory)
        writeFile(dir: dir, name: "AGENTS.md", content: memory.agents)
    }

    func updateMemory(_ content: String) {
        memory.memory = content
        if let path = filePath("MEMORY.md") {
            try? content.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    func updateUser(_ content: String) {
        memory.user = content
        if let path = filePath("USER.md") {
            try? content.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    var isOnboardingNeeded: Bool {
        memory.user.trimmingCharacters(in: .whitespacesAndNewlines)
            == AgentDefaults.defaultUser.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func readOrCreate(dir: URL, name: String, fallback: String) -> String {
        let path = dir.appendingPathComponent(name)
        if let content = try? String(contentsOf: path, encoding: .utf8) {
            return content
        }
        // Create with default content
        try? fallback.write(to: path, atomically: true, encoding: .utf8)
        return fallback
    }

    private func writeFile(dir: URL, name: String, content: String) {
        let path = dir.appendingPathComponent(name)
        try? content.write(to: path, atomically: true, encoding: .utf8)
    }
}

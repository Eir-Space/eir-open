import Foundation
import SwiftUI

@MainActor
class ChatThreadStore: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var selectedThreadID: UUID?
    @Published var messages: [ChatMessage] = []

    private var currentProfileID: UUID?

    // MARK: - Thread Management

    func loadThreads(for profileID: UUID) {
        currentProfileID = profileID
        selectedThreadID = nil
        messages = []

        let key = "eir_chat_threads_\(profileID.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ChatThread].self, from: data) {
            threads = decoded.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            threads = []
        }
    }

    @discardableResult
    func createThread(profileID: UUID) -> ChatThread {
        let thread = ChatThread(
            id: UUID(),
            profileID: profileID,
            title: "New Conversation",
            createdAt: Date(),
            updatedAt: Date()
        )
        threads.insert(thread, at: 0)
        selectedThreadID = thread.id
        messages = []
        saveThreads(for: profileID)
        return thread
    }

    func selectThread(_ threadID: UUID) {
        selectedThreadID = threadID
        let key = "eir_chat_messages_\(threadID.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = decoded
        } else {
            messages = []
        }
    }

    func deleteThread(_ threadID: UUID) {
        UserDefaults.standard.removeObject(forKey: "eir_chat_messages_\(threadID.uuidString)")

        threads.removeAll { $0.id == threadID }
        if selectedThreadID == threadID {
            selectedThreadID = nil
            messages = []
        }

        if let profileID = currentProfileID {
            saveThreads(for: profileID)
        }
    }

    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        persistMessages()
        touchThread()
    }

    func updateLastMessage(content: String) {
        guard !messages.isEmpty else { return }
        messages[messages.count - 1].content = content
    }

    func persistMessages() {
        guard let threadID = selectedThreadID else { return }
        let key = "eir_chat_messages_\(threadID.uuidString)"
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func updateThreadTitle(_ threadID: UUID, title: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].title = title
        if let profileID = currentProfileID {
            saveThreads(for: profileID)
        }
    }

    var selectedThread: ChatThread? {
        threads.first { $0.id == selectedThreadID }
    }

    // MARK: - Persistence

    private func saveThreads(for profileID: UUID) {
        let key = "eir_chat_threads_\(profileID.uuidString)"
        if let data = try? JSONEncoder().encode(threads) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func touchThread() {
        guard let threadID = selectedThreadID,
              let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].updatedAt = Date()
        threads.sort { $0.updatedAt > $1.updatedAt }
        if let profileID = currentProfileID {
            saveThreads(for: profileID)
        }
    }
}

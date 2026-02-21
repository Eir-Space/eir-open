import SwiftUI

enum NavTab: String, CaseIterable, Identifiable {
    case journal = "Journal"
    case chat = "Chat"
    case findCare = "Find Care"
    case healthData = "My Health Data"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .journal: return "doc.text"
        case .chat: return "bubble.left.and.bubble.right"
        case .findCare: return "map"
        case .healthData: return "arrow.down.doc"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var chatThreadStore: ChatThreadStore
    @EnvironmentObject var agentMemoryStore: AgentMemoryStore
    @EnvironmentObject var clinicStore: ClinicStore
    @EnvironmentObject var embeddingStore: EmbeddingStore
    @EnvironmentObject var modelManager: ModelManager

    @State private var selectedTab: NavTab = .journal
    @State private var showingAddPerson = false
    @State private var pendingFileURL: URL?
    @State private var pendingEntryID: String?

    var body: some View {
        Group {
            if profileStore.profiles.isEmpty {
                WelcomeView()
            } else {
                NavigationSplitView {
                    SidebarView(selectedTab: $selectedTab)
                } detail: {
                    switch selectedTab {
                    case .journal:
                        JournalTimelineView()
                    case .chat:
                        ChatView()
                    case .findCare:
                        FindCareView()
                    case .healthData:
                        HealthDataBrowserView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    loadSelectedProfile()
                }
                .onChange(of: profileStore.selectedProfileID) {
                    loadSelectedProfile()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddPersonSheet)) { notification in
            pendingFileURL = notification.object as? URL
            showingAddPerson = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToJournalEntry)) { notification in
            if let nav = notification.object as? NavigateToEntry {
                if nav.profileID != profileStore.selectedProfileID {
                    // Switching profiles — store entry ID as pending since
                    // loadSelectedProfile() will reset selectedEntryID
                    pendingEntryID = nav.entryID
                    profileStore.selectProfile(nav.profileID)
                } else {
                    documentVM.selectedEntryID = nav.entryID
                }
                selectedTab = .journal
            } else if let entryID = notification.object as? String {
                documentVM.selectedEntryID = entryID
                selectedTab = .journal
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .explainEntryWithAI)) { notification in
            guard let entry = notification.object as? EirEntry,
                  let profileID = profileStore.selectedProfileID else { return }
            chatVM.newConversation(chatThreadStore: chatThreadStore, profileID: profileID)
            selectedTab = .chat

            var prompt = "Explain this journal entry in plain language. Help me understand what happened during this visit, what the medical terms mean, and if there's anything important I should be aware of:\n\n"
            prompt += "Entry ID: \(entry.id)\n"
            prompt += "Date: \(entry.date ?? "Unknown")\n"
            prompt += "Category: \(entry.category ?? "Unknown")\n"
            if let type = entry.type { prompt += "Type: \(type)\n" }
            if let provider = entry.provider?.name { prompt += "Provider: \(provider)\n" }
            if let person = entry.responsiblePerson?.name { prompt += "Doctor: \(person)\n" }
            if let summary = entry.content?.summary { prompt += "Summary: \(summary)\n" }
            if let details = entry.content?.details { prompt += "Details: \(details)\n" }
            if let notes = entry.content?.notes, !notes.isEmpty {
                prompt += "Notes:\n\(notes.joined(separator: "\n"))\n"
            }

            chatVM.inputText = prompt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                chatVM.sendMessage(
                    document: documentVM.document,
                    settingsVM: settingsVM,
                    chatThreadStore: chatThreadStore,
                    profileID: profileID,
                    agentMemoryStore: agentMemoryStore,
                    clinicStore: clinicStore,
                    profileStore: profileStore,
                    embeddingStore: embeddingStore
                )
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonSheet(initialURL: pendingFileURL)
        }
    }

    private func loadSelectedProfile() {
        guard let profile = profileStore.selectedProfile else { return }
        documentVM.loadFile(url: profile.fileURL)
        chatThreadStore.loadThreads(for: profile.id)
        agentMemoryStore.load(profileID: profile.id)

        // Apply pending entry navigation after profile document is loaded
        if let entryID = pendingEntryID {
            pendingEntryID = nil
            documentVM.selectedEntryID = entryID
        }

        // Open vector store and auto-index if embeddings are enabled
        embeddingStore.openStore(profileID: profile.id)
        if embeddingStore.isEnabled, modelManager.isModelAvailable(embeddingStore.selectedModelID) {
            var allDocs: [(personName: String, document: EirDocument)] = []
            for p in profileStore.profiles {
                if let doc = try? EirParser.parse(url: p.fileURL) {
                    allDocs.append((personName: p.displayName, document: doc))
                }
            }
            if !allDocs.isEmpty {
                embeddingStore.indexDocuments(allDocuments: allDocs, modelManager: modelManager)
            }
        }
    }
}

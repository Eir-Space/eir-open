import SwiftUI

enum NavTab: String, CaseIterable, Identifiable {
    case journal = "Journal"
    case chat = "Chat"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .journal: return "doc.text"
        case .chat: return "bubble.left.and.bubble.right"
        case .settings: return "gearshape"
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

    @State private var selectedTab: NavTab = .journal

    var body: some View {
        if profileStore.profiles.isEmpty {
            WelcomeView()
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    JournalView()
                }
                .tabItem { Label("Journal", systemImage: "doc.text") }
                .tag(NavTab.journal)

                NavigationStack {
                    ChatView()
                }
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(NavTab.chat)

                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(NavTab.settings)
            }
            .tint(AppColors.primary)
            .onAppear {
                loadSelectedProfile()
            }
            .onChange(of: profileStore.selectedProfileID) {
                loadSelectedProfile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToJournalEntry)) { notification in
                if let entryID = notification.object as? String {
                    documentVM.selectedEntryID = entryID
                    selectedTab = .journal
                }
            }
        }
    }

    private func loadSelectedProfile() {
        guard let profile = profileStore.selectedProfile else { return }
        documentVM.loadFile(url: profile.fileURL)
        chatThreadStore.loadThreads(for: profile.id)
        agentMemoryStore.load(profileID: profile.id)
    }
}

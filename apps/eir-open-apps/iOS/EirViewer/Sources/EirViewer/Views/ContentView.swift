import SwiftUI

enum NavTab: String, CaseIterable, Identifiable {
    case journal = "Journal"
    case healthData = "Health Data"
    case chat = "Chat"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .journal: return "doc.text"
        case .healthData: return "heart.text.clipboard"
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
    @EnvironmentObject var healthDataExtractor: HealthDataExtractor

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
                    HealthDataBrowserView()
                }
                .tabItem { Label("Health Data", systemImage: "heart.text.clipboard") }
                .tag(NavTab.healthData)

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
            .overlay(alignment: .top) {
                if healthDataExtractor.isExtracting && selectedTab != .healthData {
                    Button {
                        selectedTab = .healthData
                    } label: {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Downloading health data... \(Int(healthDataExtractor.progress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .cornerRadius(20)
                        .shadow(radius: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: healthDataExtractor.isExtracting)
                }
            }
            .onAppear {
                // Auto-select first profile if none selected
                if profileStore.selectedProfileID == nil,
                   let first = profileStore.profiles.first {
                    profileStore.selectProfile(first.id)
                }
                loadSelectedProfile()
            }
            .onChange(of: profileStore.selectedProfileID) {
                loadSelectedProfile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileDidLoad)) { _ in
                // Switch to journal tab and reload when a profile is loaded
                selectedTab = .journal
                loadSelectedProfile()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToJournalEntry)) { notification in
                if let entryID = notification.object as? String {
                    documentVM.selectedEntryID = entryID
                    selectedTab = .journal
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToChat)) { _ in
                selectedTab = .chat
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

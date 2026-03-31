import SwiftUI

enum NavTab: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case action = "Action"
    case journal = "Journal"
    case findCare = "Find Care"
    case chat = "Chat"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .forYou: return "sparkles"
        case .action: return "figure.run.square.stack"
        case .journal: return "doc.text"
        case .findCare: return "cross.case"
        case .chat: return "bubble.left.and.bubble.right"
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

    @State private var selectedTab: NavTab = .forYou

    var body: some View {
        if profileStore.profiles.isEmpty {
            WelcomeView()
        } else {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ForYouView()
                        .topLevelProfileToolbar()
                }
                .tabItem { Label("For You", systemImage: "sparkles") }
                .tag(NavTab.forYou)

                NavigationStack {
                    ActionLibraryView()
                        .topLevelProfileToolbar()
                }
                .tabItem { Label("Action", systemImage: "figure.run.square.stack") }
                .tag(NavTab.action)

                NavigationStack {
                    JournalView()
                        .topLevelProfileToolbar()
                }
                .tabItem { Label("Journal", systemImage: "doc.text") }
                .tag(NavTab.journal)

                NavigationStack {
                    FindCareView()
                        .topLevelProfileToolbar()
                }
                .tabItem { Label("Find Care", systemImage: "cross.case") }
                .tag(NavTab.findCare)

                NavigationStack {
                    ChatView()
                        .topLevelProfileToolbar()
                }
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(NavTab.chat)
            }
            .tint(AppColors.primary)
            .overlay(alignment: .top) {
                if healthDataExtractor.isExtracting && selectedTab != .journal {
                    Button {
                        NotificationCenter.default.post(name: .openJournalImport, object: nil)
                        selectedTab = .journal
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
            .onReceive(NotificationCenter.default.publisher(for: .navigateToAction)) { _ in
                selectedTab = .action
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

extension Notification.Name {
    static let navigateToAction = Notification.Name("navigateToAction")
}

struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct TopLevelProfileToolbarModifier: ViewModifier {
    @EnvironmentObject private var profileStore: ProfileStore

    @State private var showingProfile = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingProfile = true
                    } label: {
                        ProfileToolbarAvatar(initials: profileStore.selectedProfile?.initials)
                    }
                    .accessibilityLabel("Open Profile and Settings")
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileSettingsSheet()
            }
    }
}

private struct ProfileToolbarAvatar: View {
    let initials: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(AppColors.backgroundMuted)

                if let initials, !initials.isEmpty {
                    Text(initials)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.text)
                } else {
                    Image(systemName: "person.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.text)
                }
            }
            .frame(width: 30, height: 30)

            Circle()
                .fill(AppColors.primaryStrong)
                .frame(width: 14, height: 14)
                .overlay {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
        }
    }
}

extension View {
    func topLevelProfileToolbar() -> some View {
        modifier(TopLevelProfileToolbarModifier())
    }
}

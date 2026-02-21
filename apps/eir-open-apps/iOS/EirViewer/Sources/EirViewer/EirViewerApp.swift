import SwiftUI

@main
struct EirViewerApp: App {
    @StateObject private var documentVM = DocumentViewModel()
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var chatThreadStore = ChatThreadStore()
    @StateObject private var agentMemoryStore = AgentMemoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(documentVM)
                .environmentObject(chatVM)
                .environmentObject(settingsVM)
                .environmentObject(profileStore)
                .environmentObject(chatThreadStore)
                .environmentObject(agentMemoryStore)
                .onOpenURL { url in
                    let ext = url.pathExtension.lowercased()
                    guard ext == "eir" || ext == "yaml" || ext == "yml" else { return }
                    if let profile = profileStore.addProfile(displayName: "", fileURL: url) {
                        profileStore.selectProfile(profile.id)
                    }
                }
        }
    }
}

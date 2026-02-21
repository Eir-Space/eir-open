import SwiftUI
import SQLiteVec

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SPM builds produce a raw executable, not an .app bundle.
        // macOS won't deliver keyboard events unless we explicitly
        // register as a regular (Dock-visible) app and activate.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Initialize sqlite-vec extension
        try? SQLiteVec.initialize()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "eir" || ext == "yaml" || ext == "yml" {
                NotificationCenter.default.post(
                    name: .openEirFile,
                    object: url
                )
                return
            }
        }
    }
}

extension Notification.Name {
    static let openEirFile = Notification.Name("openEirFile")
    static let showAddPersonSheet = Notification.Name("showAddPersonSheet")
}

@main
struct EirViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var documentVM = DocumentViewModel()
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var chatThreadStore = ChatThreadStore()
    @StateObject private var clinicStore = ClinicStore()
    @StateObject private var agentMemoryStore = AgentMemoryStore()
    @StateObject private var embeddingStore = EmbeddingStore()
    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(documentVM)
                .environmentObject(chatVM)
                .environmentObject(settingsVM)
                .environmentObject(profileStore)
                .environmentObject(chatThreadStore)
                .environmentObject(clinicStore)
                .environmentObject(agentMemoryStore)
                .environmentObject(embeddingStore)
                .environmentObject(modelManager)
                .onAppear {
                    loadFromCommandLine()
                }
                .onReceive(NotificationCenter.default.publisher(for: .openEirFile)) { notification in
                    if let url = notification.object as? URL {
                        NotificationCenter.default.post(
                            name: .showAddPersonSheet,
                            object: url
                        )
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open EIR File...") {
                    documentVM.openFilePicker { url in
                        NotificationCenter.default.post(
                            name: .showAddPersonSheet,
                            object: url
                        )
                    }
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settingsVM)
                .environmentObject(agentMemoryStore)
                .environmentObject(embeddingStore)
                .environmentObject(modelManager)
                .environmentObject(profileStore)
        }
    }

    private func loadFromCommandLine() {
        let args = CommandLine.arguments
        for arg in args.dropFirst() {
            if arg.hasSuffix(".eir") || arg.hasSuffix(".yaml") || arg.hasSuffix(".yml") {
                let url = URL(fileURLWithPath: arg)
                // Command-line files add directly (no sheet) for quick launch
                if let profile = profileStore.addProfile(displayName: "", fileURL: url) {
                    profileStore.selectProfile(profile.id)
                }
                return
            }
        }
    }
}

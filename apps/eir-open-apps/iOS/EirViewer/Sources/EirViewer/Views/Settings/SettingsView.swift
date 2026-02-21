import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var agentMemoryStore: AgentMemoryStore
    @EnvironmentObject var profileStore: ProfileStore

    @State private var showingAddPerson = false
    @State private var showHealthKitImport = false
    @State private var renamingProfileID: UUID?
    @State private var renameText: String = ""

    var body: some View {
        Form {
            // MARK: - People
            Section("People") {
                ForEach(profileStore.profiles) { profile in
                    PersonRow(
                        profile: profile,
                        isSelected: profile.id == profileStore.selectedProfileID
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        profileStore.selectProfile(profile.id)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            profileStore.removeProfile(profile.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        Button {
                            renameText = profile.displayName
                            renamingProfileID = profile.id
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(AppColors.primary)
                    }
                }

                Button {
                    showingAddPerson = true
                } label: {
                    Label("Add Person...", systemImage: "person.badge.plus")
                }

                Button {
                    showHealthKitImport = true
                } label: {
                    Label("Import from Apple Health", systemImage: "heart.fill")
                        .foregroundColor(AppColors.pink)
                }
            }

            // MARK: - AI Provider
            Section("AI Provider") {
                Picker("Active Provider", selection: $settingsVM.activeProviderType) {
                    ForEach(LLMProviderType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            // MARK: - Provider Cards
            ForEach(settingsVM.providers) { config in
                ProviderSection(config: config)
                    .environmentObject(settingsVM)
            }

            // MARK: - Agent Configuration
            Section("Agent Configuration") {
                AgentConfigCard(
                    title: "Identity (SOUL.md)",
                    defaultContent: AgentDefaults.defaultSoul,
                    content: $agentMemoryStore.memory.soul
                )
                AgentConfigCard(
                    title: "User Profile (USER.md)",
                    defaultContent: AgentDefaults.defaultUser,
                    content: $agentMemoryStore.memory.user
                )
                AgentConfigCard(
                    title: "Memory (MEMORY.md)",
                    defaultContent: AgentDefaults.defaultMemory,
                    content: $agentMemoryStore.memory.memory
                )
                AgentConfigCard(
                    title: "Skills (AGENTS.md)",
                    defaultContent: AgentDefaults.defaultAgents,
                    content: $agentMemoryStore.memory.agents
                )
            }
            .onChange(of: agentMemoryStore.memory.soul) { _, _ in agentMemoryStore.save() }
            .onChange(of: agentMemoryStore.memory.user) { _, _ in agentMemoryStore.save() }
            .onChange(of: agentMemoryStore.memory.memory) { _, _ in agentMemoryStore.save() }
            .onChange(of: agentMemoryStore.memory.agents) { _, _ in agentMemoryStore.save() }

            // MARK: - Info
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(AppColors.primary)
                    Text("API keys are stored securely in Keychain")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingAddPerson) {
            AddPersonSheet()
        }
        .sheet(isPresented: $showHealthKitImport) {
            HealthKitImportView()
        }
        .alert("Rename Person", isPresented: Binding(
            get: { renamingProfileID != nil },
            set: { if !$0 { renamingProfileID = nil } }
        )) {
            TextField("Display name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renamingProfileID = nil
            }
            Button("Rename") {
                if let id = renamingProfileID {
                    profileStore.renameProfile(id, to: renameText)
                }
                renamingProfileID = nil
            }
        } message: {
            Text("Enter a new display name for this person.")
        }
    }
}

// MARK: - Provider Section

private struct ProviderSection: View {
    let config: LLMProviderConfig
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var showKey = false

    var isActive: Bool { settingsVM.activeProviderType == config.type }
    var hasKey: Bool { !apiKey.isEmpty }

    var body: some View {
        Section {
            // Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(config.type.rawValue)
                            .font(.headline)
                        if isActive {
                            Text("Active")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    Text(config.type.defaultBaseURL)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(hasKey ? AppColors.green : AppColors.border)
                        .frame(width: 8, height: 8)
                    Text(hasKey ? "Configured" : "No API key")
                        .font(.caption)
                        .foregroundColor(hasKey ? AppColors.green : AppColors.textSecondary)
                }
            }

            // API Key
            HStack {
                if showKey {
                    TextField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                }

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .onChange(of: apiKey) { _, newValue in
                settingsVM.setApiKey(newValue, for: config.type)
            }

            // Model
            HStack {
                Text("Model")
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                TextField("Model name", text: $model)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: model) { _, newValue in
                        var updated = config
                        updated.model = newValue
                        settingsVM.updateProvider(updated)
                    }
            }

            // Custom base URL
            if config.type == .custom {
                HStack {
                    Text("Base URL")
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    TextField("https://api.example.com/v1", text: $baseURL)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: baseURL) { _, newValue in
                            var updated = config
                            updated.baseURL = newValue
                            settingsVM.updateProvider(updated)
                        }
                }
            }

            if !isActive && hasKey {
                Button("Use \(config.type.rawValue)") {
                    settingsVM.setActiveProvider(config.type)
                }
                .foregroundColor(AppColors.primary)
            }
        }
        .onAppear {
            apiKey = settingsVM.apiKey(for: config.type)
            baseURL = config.baseURL
            model = config.model
        }
    }
}

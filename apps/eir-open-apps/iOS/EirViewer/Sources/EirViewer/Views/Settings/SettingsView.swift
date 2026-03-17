import SwiftUI
import HealthKit

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

                if HKHealthStore.isHealthDataAvailable() {
                    Button {
                        showHealthKitImport = true
                    } label: {
                        Label("Import from Apple Health", systemImage: "heart.fill")
                            .foregroundColor(AppColors.pink)
                    }
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

            // MARK: - Local Models & Prompt Style (shown first when local is active)
            if settingsVM.activeProviderType.isLocal {
                ForEach(settingsVM.providers.filter({ $0.type.isLocal })) { config in
                    ProviderSection(config: config)
                        .environmentObject(settingsVM)
                }

                PromptStyleSection()
                    .environmentObject(settingsVM)
            }

            // MARK: - Cloud Provider Cards
            ForEach(settingsVM.providers.filter({ !$0.type.isLocal })) { config in
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

            // MARK: - Privacy & Data
            Section("Privacy & Data") {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(AppColors.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("API keys are stored securely in Keychain")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("On-device models keep all data on your phone")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if hasAnyCloudConsent {
                    Button(role: .destructive) {
                        resetCloudConsent()
                    } label: {
                        Label("Reset Cloud Data Sharing Consent", systemImage: "arrow.counterclockwise")
                            .font(.callout)
                    }
                }

                Link(destination: URL(string: "https://eir.health/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
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

    private var hasAnyCloudConsent: Bool {
        LLMProviderType.allCases.filter { !$0.isLocal }.contains { type in
            ChatViewModel.hasCloudConsent(for: type)
        }
    }

    private func resetCloudConsent() {
        for type in LLMProviderType.allCases where !type.isLocal {
            UserDefaults.standard.removeObject(forKey: "cloudConsent_\(type.rawValue)")
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
                    if config.type.isLocal {
                        Text("Runs entirely on device — no data leaves your phone")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    } else {
                        Text(config.type.defaultBaseURL)
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if !config.type.isLocal {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(hasKey ? AppColors.green : AppColors.border)
                            .frame(width: 8, height: 8)
                        Text(hasKey ? "Configured" : "No API key")
                            .font(.caption)
                            .foregroundColor(hasKey ? AppColors.green : AppColors.textSecondary)
                    }
                }
            }

            if config.type.isLocal {
                // Local model UI — handled by LocalModelSection
                LocalModelSection()
            } else {
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
        }
        .onAppear {
            apiKey = settingsVM.apiKey(for: config.type)
            baseURL = config.baseURL
            model = config.model
        }
    }
}

// MARK: - Local Model Section

private struct LocalModelSection: View {
    @EnvironmentObject var localModelManager: LocalModelManager
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showAddModel = false
    @State private var newModelId = ""

    var body: some View {
        // Error banner
        if case .error(let msg) = localModelManager.status {
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }

        // Model list
        ForEach(localModelManager.models) { model in
            LocalModelRow(model: model)
        }
        .onDelete { offsets in
            let ids = offsets.map { localModelManager.models[$0].id }
            for id in ids {
                localModelManager.removeModel(id)
            }
        }

        // Add model button
        Button {
            newModelId = ""
            showAddModel = true
        } label: {
            Label("Add Model...", systemImage: "plus.circle")
        }
        .foregroundColor(AppColors.primary)
        .alert("Add Model", isPresented: $showAddModel) {
            TextField("mlx-community/model-name", text: $newModelId)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let id = newModelId.trimmingCharacters(in: .whitespaces)
                guard !id.isEmpty else { return }
                // Use last path component as display name
                let name = id.components(separatedBy: "/").last ?? id
                localModelManager.addModel(id: id, displayName: name)
            }
        } message: {
            Text("Enter a HuggingFace model ID")
        }

        // Unload from memory
        if localModelManager.activeModelId != nil {
            Button(role: .destructive) {
                localModelManager.unloadModel()
            } label: {
                Label("Unload from Memory", systemImage: "xmark.circle")
            }
        }

        // Use on-device button
        if localModelManager.isReady && settingsVM.activeProviderType != .local {
            Button("Use On-Device") {
                settingsVM.setActiveProvider(.local)
            }
            .foregroundColor(AppColors.primary)
        }
    }
}

// MARK: - Local Model Row

private struct LocalModelRow: View {
    let model: LocalModel
    @EnvironmentObject var localModelManager: LocalModelManager

    var isActive: Bool { localModelManager.activeModelId == model.id }
    var isDownloading: Bool { localModelManager.downloadingModelId == model.id }
    var isLoading: Bool {
        isDownloading && localModelManager.status == .loading
    }

    var body: some View {
        Button {
            guard !isActive else { return }
            Task { await localModelManager.loadModel(model.id) }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                            .font(.subheadline)
                            .foregroundColor(AppColors.text)
                        Text(model.id)
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColors.green)
                                .frame(width: 8, height: 8)
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(AppColors.green)
                        }
                    } else if isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    } else if isDownloading {
                        Text("\(Int(localModelManager.downloadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(AppColors.yellow)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Download progress bar
                if isDownloading && localModelManager.status == .downloading {
                    ProgressView(value: localModelManager.downloadProgress)
                        .tint(AppColors.primary)
                }
            }
        }
        .disabled(isDownloading || (localModelManager.status == .downloading && !isDownloading))
    }
}

// MARK: - Prompt Style Section

private struct PromptStyleSection: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showCreatePrompt = false
    @State private var editingPrompt: PromptVersion?

    var body: some View {
        Section {
            ForEach(settingsVM.allPromptVersions) { version in
                Button {
                    settingsVM.activePromptVersionId = version.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(version.name)
                                    .font(.body)
                                    .foregroundColor(AppColors.text)
                                if !version.isBuiltIn {
                                    Text("Custom")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(AppColors.primary.opacity(0.15))
                                        .foregroundColor(AppColors.primary)
                                        .cornerRadius(3)
                                }
                            }
                            Text(version.description)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        if settingsVM.activePromptVersionId == version.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !version.isBuiltIn {
                        Button(role: .destructive) {
                            settingsVM.deleteCustomPrompt(version.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editingPrompt = version
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(AppColors.primary)
                    }
                }
            }

            Button {
                showCreatePrompt = true
            } label: {
                Label("Create Custom Style...", systemImage: "plus.circle")
            }
            .foregroundColor(AppColors.primary)
        } header: {
            Text("Prompt Style (On-Device)")
        }
        .sheet(isPresented: $showCreatePrompt) {
            PromptEditorSheet(settingsVM: settingsVM)
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditorSheet(settingsVM: settingsVM, editing: prompt)
        }
    }
}

// MARK: - Prompt Editor Sheet

private struct PromptEditorSheet: View {
    @ObservedObject var settingsVM: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var description: String
    @State private var systemPrompt: String

    private let editingId: String?

    init(settingsVM: SettingsViewModel, editing: PromptVersion? = nil) {
        self.settingsVM = settingsVM
        self.editingId = editing?.id
        _name = State(initialValue: editing?.name ?? "")
        _description = State(initialValue: editing?.description ?? "")
        _systemPrompt = State(initialValue: editing?.systemPrompt ?? """
        You are Eir, a medical records assistant. Always respond in English. Records may be in Swedish — translate them. Be concise.

        CRITICAL CONSTRAINTS:
        1. Use ONLY information from the provided records. Never guess.
        2. If the answer is not in the records, say so.
        3. Never invent medications, dosages, or diagnoses.
        4. Never provide definitive diagnoses.
        """)
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Simple & Friendly", text: $name)
                }

                Section("Description") {
                    TextField("Short description", text: $description)
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 200)
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    Text("The prompt tells the AI how to respond. Patient records and user context are appended automatically.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .navigationTitle(editingId != nil ? "Edit Prompt" : "New Prompt Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespaces)
                        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
                        let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespaces)

                        if let id = editingId {
                            let updated = PromptVersion(
                                id: id,
                                name: trimmedName,
                                description: trimmedDesc,
                                systemPrompt: trimmedPrompt
                            )
                            settingsVM.updateCustomPrompt(updated)
                        } else {
                            settingsVM.addCustomPrompt(
                                name: trimmedName,
                                description: trimmedDesc,
                                systemPrompt: trimmedPrompt
                            )
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

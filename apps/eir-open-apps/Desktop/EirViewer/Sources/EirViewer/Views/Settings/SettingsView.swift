import SwiftUI

// macOS Settings window (Cmd+,)
struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var agentMemoryStore: AgentMemoryStore
    @EnvironmentObject var embeddingStore: EmbeddingStore
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        InlineSettingsView()
            .environmentObject(settingsVM)
            .environmentObject(agentMemoryStore)
            .environmentObject(embeddingStore)
            .environmentObject(modelManager)
            .frame(width: 600, height: 750)
    }
}

// Full in-app settings view (used in sidebar navigation and Settings window)
struct InlineSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var agentMemoryStore: AgentMemoryStore
    @EnvironmentObject var embeddingStore: EmbeddingStore
    @EnvironmentObject var modelManager: ModelManager
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.text)
                    Text("Configure AI providers to chat about your medical records")
                        .foregroundColor(AppColors.textSecondary)
                }

                // Active provider
                GroupBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Provider")
                                .font(.headline)
                                .foregroundColor(AppColors.text)
                            Text("Choose which AI provider to use for chat")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        Picker("", selection: $settingsVM.activeProviderType) {
                            ForEach(LLMProviderType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .frame(width: 160)
                    }
                    .padding(4)
                }

                // Provider cards
                ForEach(settingsVM.providers) { config in
                    ProviderCard(config: config)
                        .environmentObject(settingsVM)
                }

                // Smart Search (Embeddings)
                EmbeddingSettingsView()

                // Agent Configuration
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Agent Configuration")
                            .font(.headline)
                            .foregroundColor(AppColors.text)
                        Text("Customize the AI agent's identity, memory, and capabilities")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)

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
                        // Reset Agent button
                        Divider()
                            .padding(.vertical, 4)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Agent")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.text)
                                Text("Resets all files to defaults — the agent will re-introduce itself on next chat")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            Button("Reset") {
                                showResetConfirmation = true
                            }
                            .foregroundColor(AppColors.red)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(4)
                }
                .onChange(of: agentMemoryStore.memory.soul) { _, _ in agentMemoryStore.save() }
                .onChange(of: agentMemoryStore.memory.user) { _, _ in agentMemoryStore.save() }
                .onChange(of: agentMemoryStore.memory.memory) { _, _ in agentMemoryStore.save() }
                .onChange(of: agentMemoryStore.memory.agents) { _, _ in agentMemoryStore.save() }
                .alert("Reset Agent?", isPresented: $showResetConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        agentMemoryStore.resetToDefaults()
                    }
                } message: {
                    Text("This will reset the agent's identity, user profile, memory, and skills to defaults. The agent will re-introduce itself on the next chat.")
                }

                // Info
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(AppColors.primary)
                    Text("API keys are stored securely in macOS Keychain")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(AppColors.background)
    }
}

struct ProviderCard: View {
    let config: LLMProviderConfig
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var model: String = ""
    @State private var showKey = false

    var isActive: Bool { settingsVM.activeProviderType == config.type }
    var hasKey: Bool { !apiKey.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(config.type.rawValue)
                            .font(.headline)
                            .foregroundColor(AppColors.text)
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
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(hasKey ? AppColors.green : AppColors.border)
                        .frame(width: 8, height: 8)
                    Text(hasKey ? "Configured" : "No API key")
                        .font(.caption)
                        .foregroundColor(hasKey ? AppColors.green : AppColors.textSecondary)
                }

                if !isActive {
                    Button("Use") {
                        settingsVM.setActiveProvider(config.type)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                    .controlSize(.small)
                    .disabled(!hasKey)
                }
            }
            .padding(16)

            Divider()

            // API Key field
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)

                    HStack(spacing: 8) {
                        Group {
                            if showKey {
                                TextField("Enter your API key", text: $apiKey)
                            } else {
                                SecureField("Enter your API key", text: $apiKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            settingsVM.setApiKey(newValue, for: config.type)
                        }

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help(showKey ? "Hide key" : "Show key")
                    }

                    // Hint for providers that need API keys
                    if config.type == .anthropic, !hasKey {
                        Text("Get a key at console.anthropic.com")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    } else if config.type == .minimax, !hasKey {
                        Text("Get a key at platform.minimax.io — uses Anthropic format")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    } else if config.type == .groq, !hasKey {
                        Text("Free API key at console.groq.com")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Model field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)

                    TextField("Model name", text: $model)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: model) { _, newValue in
                            var updated = config
                            updated.model = newValue
                            settingsVM.updateProvider(updated)
                        }
                }

                // Custom base URL
                if config.type == .custom {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.text)

                        TextField("https://api.example.com/v1", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: baseURL) { _, newValue in
                                var updated = config
                                updated.baseURL = newValue
                                settingsVM.updateProvider(updated)
                            }
                    }
                }
            }
            .padding(16)
        }
        .background(AppColors.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive ? AppColors.primary.opacity(0.3) : AppColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        .onAppear {
            apiKey = settingsVM.apiKey(for: config.type)
            baseURL = config.baseURL
            model = config.model
        }
    }
}

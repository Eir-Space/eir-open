import SwiftUI

struct PromptStyleSettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var showCustomPromptEditor = false
    @State private var editingPrompt: PromptVersion?
    @State private var editName = ""
    @State private var editDescription = ""
    @State private var editSystemPrompt = ""

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Prompt Style")
                    .font(.headline)
                    .foregroundColor(AppColors.text)
                Text("Choose how the on-device model responds to your questions")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Picker("Style", selection: $settingsVM.activePromptVersionId) {
                    ForEach(settingsVM.allPromptVersions) { version in
                        Text(version.name).tag(version.id)
                    }
                }
                .labelsHidden()

                // Description of active prompt
                if let active = settingsVM.activePromptVersion {
                    Text(active.description)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.divider.opacity(0.5))
                        .cornerRadius(6)
                }

                // Custom prompts section
                Divider()
                    .padding(.vertical, 2)

                HStack {
                    Text("Custom Prompts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                    Spacer()
                    Button("New Prompt") {
                        editingPrompt = nil
                        editName = ""
                        editDescription = ""
                        editSystemPrompt = ""
                        showCustomPromptEditor = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ForEach(settingsVM.customPrompts) { prompt in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.name)
                                .font(.subheadline)
                                .foregroundColor(AppColors.text)
                            Text(prompt.description)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            editingPrompt = prompt
                            editName = prompt.name
                            editDescription = prompt.description
                            editSystemPrompt = prompt.systemPrompt
                            showCustomPromptEditor = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)

                        Button {
                            settingsVM.deleteCustomPrompt(id: prompt.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(AppColors.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }

                if settingsVM.customPrompts.isEmpty {
                    Text("No custom prompts yet")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }
            }
            .padding(4)
        }
        .sheet(isPresented: $showCustomPromptEditor) {
            CustomPromptEditorSheet(
                name: $editName,
                description: $editDescription,
                systemPrompt: $editSystemPrompt,
                isEditing: editingPrompt != nil,
                onSave: {
                    if let existing = editingPrompt {
                        var updated = existing
                        updated.name = editName
                        updated.description = editDescription
                        updated.systemPrompt = editSystemPrompt
                        settingsVM.updateCustomPrompt(updated)
                    } else {
                        settingsVM.addCustomPrompt(
                            name: editName,
                            description: editDescription,
                            systemPrompt: editSystemPrompt
                        )
                    }
                    showCustomPromptEditor = false
                }
            )
        }
    }
}

private struct CustomPromptEditorSheet: View {
    @Binding var name: String
    @Binding var description: String
    @Binding var systemPrompt: String
    let isEditing: Bool
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Edit Custom Prompt" : "New Custom Prompt")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g. My Custom Style", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Brief description", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextEditor(text: $systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 200)
                    .border(AppColors.border, width: 1)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") { onSave() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500, height: 450)
    }
}

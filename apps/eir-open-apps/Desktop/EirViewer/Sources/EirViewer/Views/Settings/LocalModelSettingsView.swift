import SwiftUI

struct LocalModelSettingsView: View {
    @EnvironmentObject var localModelManager: LocalModelManager

    @State private var showAddModel = false
    @State private var customModelId = ""
    @State private var customModelName = ""

    private var systemRAM: Int { LocalModelManager.systemRAMGB }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("On-Device Models")
                        .font(.headline)
                        .foregroundColor(AppColors.text)
                    Spacer()
                    // System RAM badge
                    Text("\(systemRAM) GB RAM")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.primary.opacity(0.1))
                        .foregroundColor(AppColors.primary)
                        .cornerRadius(4)
                }

                Text("Download and run models locally on your Mac — no API key needed")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                ForEach(localModelManager.models) { model in
                    LocalModelRow(model: model)
                }

                // Add custom model
                Divider()
                    .padding(.vertical, 2)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Custom Model")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.text)
                        Text("Add any MLX model from HuggingFace")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Button("Add Model") {
                        showAddModel = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(4)
        }
        .sheet(isPresented: $showAddModel) {
            AddCustomModelSheet(
                modelId: $customModelId,
                modelName: $customModelName,
                onAdd: {
                    let name = customModelName.isEmpty ? customModelId.components(separatedBy: "/").last ?? customModelId : customModelName
                    localModelManager.addModel(id: customModelId, displayName: name)
                    customModelId = ""
                    customModelName = ""
                    showAddModel = false
                }
            )
        }
    }
}

private struct LocalModelRow: View {
    let model: LocalModel
    @EnvironmentObject var localModelManager: LocalModelManager

    private var status: String { localModelManager.modelStatus(model.id) }
    private var isRecommended: Bool { LocalModelManager.isRecommended(model) }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)

                    if !isRecommended {
                        Text("\(model.minRAMGB)GB+ RAM")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppColors.orange.opacity(0.15))
                            .foregroundColor(AppColors.orange)
                            .cornerRadius(3)
                    }

                    if status == "active" {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(AppColors.green.opacity(0.15))
                            .foregroundColor(AppColors.green)
                            .cornerRadius(3)
                    }
                }

                Text(model.id)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if status == "downloading" {
                ProgressView(value: localModelManager.downloadProgress)
                    .frame(width: 80)
                Text("\(Int(localModelManager.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 35)
            } else if status == "active" {
                Button("Unload") {
                    localModelManager.unloadModel()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if status == "error" {
                VStack(alignment: .trailing, spacing: 2) {
                    Button("Retry") {
                        localModelManager.lastErrorModelId = nil
                        localModelManager.status = .notDownloaded
                        Task { await localModelManager.loadModel(model.id) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    if let msg = localModelManager.errorMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundColor(AppColors.red)
                            .lineLimit(2)
                            .frame(maxWidth: 200, alignment: .trailing)
                    }
                }
            } else {
                Button("Download & Load") {
                    Task { await localModelManager.loadModel(model.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Remove custom models (not presets)
            if !LocalModelManager.presets.contains(where: { $0.id == model.id }) {
                Button {
                    localModelManager.removeModel(model.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(AppColors.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AddCustomModelSheet: View {
    @Binding var modelId: String
    @Binding var modelName: String
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Custom Model")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("HuggingFace Model ID")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g. mlx-community/Llama-3-8B-4bit", text: $modelId)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name (optional)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("e.g. Llama 3 8B", text: $modelName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Add") { onAdd() }
                    .buttonStyle(.borderedProminent)
                    .disabled(modelId.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

import SwiftUI

struct EmbeddingSettingsView: View {
    @EnvironmentObject var embeddingStore: EmbeddingStore
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var profileStore: ProfileStore

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Search")
                            .font(.headline)
                            .foregroundColor(AppColors.text)
                        Text("Use on-device AI to understand meaning, not just keywords")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { embeddingStore.isEnabled },
                        set: { embeddingStore.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                if embeddingStore.isEnabled {
                    Divider()

                    // Model selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Embedding Model")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.text)

                        ForEach(ModelManager.availableModels) { model in
                            ModelRow(
                                model: model,
                                isSelected: embeddingStore.selectedModelID == model.id,
                                isAvailable: modelManager.isModelAvailable(model.id),
                                isDownloading: modelManager.isDownloading && embeddingStore.selectedModelID == model.id,
                                downloadProgress: modelManager.downloadProgress,
                                onSelect: {
                                    embeddingStore.setModel(model.id)
                                },
                                onDownload: {
                                    embeddingStore.setModel(model.id)
                                    modelManager.downloadModel(model)
                                },
                                onDelete: {
                                    modelManager.deleteModel(model)
                                    if embeddingStore.selectedModelID == model.id {
                                        embeddingStore.setModel("apple-nl")
                                    }
                                }
                            )
                        }
                    }

                    Divider()

                    // Index status
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Search Index")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.text)

                            if embeddingStore.isIndexing {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                    Text("Indexing \(embeddingStore.indexedCount)/\(embeddingStore.totalCount) entries...")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            } else if embeddingStore.indexedCount > 0 {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(AppColors.green)
                                        .frame(width: 6, height: 6)
                                    Text("\(embeddingStore.indexedCount) entries indexed")
                                        .font(.caption)
                                        .foregroundColor(AppColors.green)
                                }
                            } else {
                                Text("No entries indexed yet")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        if embeddingStore.isIndexing {
                            Button("Cancel") {
                                embeddingStore.cancelIndexing()
                            }
                            .controlSize(.small)
                        } else {
                            HStack(spacing: 8) {
                                Button("Index Now") {
                                    startIndexing()
                                }
                                .controlSize(.small)
                                .disabled(!modelManager.isModelAvailable(embeddingStore.selectedModelID) || profileStore.profiles.isEmpty)

                                Button("Clear Index") {
                                    embeddingStore.clearIndex()
                                }
                                .controlSize(.small)
                                .disabled(embeddingStore.indexedCount == 0)
                            }
                        }
                    }

                    if embeddingStore.isIndexing {
                        ProgressView(value: embeddingStore.indexProgress)
                            .tint(AppColors.primary)
                    }

                    // Error
                    if let error = embeddingStore.errorMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(AppColors.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppColors.red)
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    private func startIndexing() {
        guard let profile = profileStore.selectedProfile else { return }
        embeddingStore.openStore(profileID: profile.id)

        var allDocs: [(personName: String, document: EirDocument)] = []
        for p in profileStore.profiles {
            if let doc = try? EirParser.parse(url: p.fileURL) {
                allDocs.append((personName: p.displayName, document: doc))
            }
        }
        guard !allDocs.isEmpty else { return }
        embeddingStore.indexDocuments(allDocuments: allDocs, modelManager: modelManager)
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: ModelManager.ModelInfo
    let isSelected: Bool
    let isAvailable: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Radio indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(.subheadline)
                    .foregroundColor(AppColors.text)
                Text(model.description)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if model.isBuiltIn {
                Text("Built-in")
                    .font(.caption2)
                    .foregroundColor(AppColors.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.green.opacity(0.1))
                    .cornerRadius(4)
            } else if isDownloading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else if isAvailable {
                HStack(spacing: 4) {
                    Text("Downloaded")
                        .font(.caption2)
                        .foregroundColor(AppColors.green)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete model")
                }
            } else {
                Button {
                    onDownload()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text(ModelManager.formatSize(model.sizeBytes))
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? AppColors.primary.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            if isAvailable {
                onSelect()
            }
        }
    }
}

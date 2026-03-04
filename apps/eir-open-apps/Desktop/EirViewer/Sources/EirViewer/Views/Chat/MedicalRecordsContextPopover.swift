import SwiftUI

struct MedicalRecordsContextPopover: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var chatThreadStore: ChatThreadStore

    @State private var searchText = ""

    private var allEntries: [EirEntry] {
        documentVM.document?.entries ?? []
    }

    private var filteredEntries: [EirEntry] {
        if searchText.isEmpty { return allEntries }
        return allEntries.filter { entry in
            entry.content?.summary?.localizedCaseInsensitiveContains(searchText) == true ||
            entry.category?.localizedCaseInsensitiveContains(searchText) == true ||
            entry.provider?.name?.localizedCaseInsensitiveContains(searchText) == true ||
            entry.date?.contains(searchText) == true
        }
    }

    private var includedCount: Int {
        allEntries.count - chatThreadStore.excludedEntryIDs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Medical Records in Context")
                    .font(.headline)
                    .foregroundColor(AppColors.text)
                Spacer()
                Text("\(includedCount)/\(allEntries.count)")
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                    .fontWeight(.medium)
            }
            .padding()

            // Add all / Remove all
            HStack(spacing: 8) {
                Button {
                    chatThreadStore.includeAllEntries()
                } label: {
                    Text("Include All")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(chatThreadStore.excludedEntryIDs.isEmpty)

                Button {
                    chatThreadStore.excludeAllEntries(from: documentVM.document)
                } label: {
                    Text("Remove All")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(includedCount == 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                TextField("Search entries...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
            }
            .padding(8)
            .background(AppColors.divider)
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Entry list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredEntries) { entry in
                        RecordContextRow(
                            entry: entry,
                            isIncluded: !chatThreadStore.isEntryExcluded(entry.id)
                        ) {
                            chatThreadStore.toggleEntry(entry.id)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 380, height: 440)
    }
}

private struct RecordContextRow: View {
    let entry: EirEntry
    let isIncluded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isIncluded ? "checkmark.circle.fill" : "circle")
                    .font(.callout)
                    .foregroundColor(isIncluded ? AppColors.primary : AppColors.textSecondary)

                Circle()
                    .fill(AppColors.categoryColor(for: entry.category ?? "Other"))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.content?.summary ?? entry.type ?? entry.category ?? "Entry")
                        .font(.caption)
                        .foregroundColor(isIncluded ? AppColors.text : AppColors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        if let date = entry.date {
                            Text(date)
                        }
                        if let cat = entry.category {
                            Text(cat)
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isIncluded ? Color.clear : AppColors.divider.opacity(0.3))
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct JournalTimelineView: View {
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        HSplitView {
            // Entry list
            VStack(spacing: 0) {
                FilterBarView()

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(documentVM.groupedEntries, id: \.key) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    EntryCardView(
                                        entry: entry,
                                        isSelected: documentVM.selectedEntryID == entry.id
                                    )
                                    .onTapGesture {
                                        documentVM.selectedEntryID = entry.id
                                    }
                                    .contentShape(Rectangle())
                                }
                            } header: {
                                Text(group.key)
                                    .font(.headline)
                                    .foregroundColor(AppColors.text)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(minWidth: 350, idealWidth: 420)
            .background(AppColors.background)

            // Detail pane
            if let entry = documentVM.selectedEntry {
                EntryDetailView(entry: entry)
                    .frame(minWidth: 350)
            } else {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    Text("Select an entry to view details")
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
            }
        }
    }
}

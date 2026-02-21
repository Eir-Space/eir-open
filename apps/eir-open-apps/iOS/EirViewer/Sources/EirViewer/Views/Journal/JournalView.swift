import SwiftUI

struct JournalView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var profileStore: ProfileStore

    @State private var showingAddPerson = false

    var body: some View {
        Group {
            if documentVM.document == nil {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    Text("No records loaded")
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(documentVM.groupedEntries, id: \.key) { group in
                            Section {
                                ForEach(group.entries) { entry in
                                    NavigationLink(value: entry.id) {
                                        EntryCardView(
                                            entry: entry,
                                            isSelected: false
                                        )
                                    }
                                    .buttonStyle(.plain)
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
                .navigationDestination(for: String.self) { entryID in
                    if let entry = documentVM.document?.entries.first(where: { $0.id == entryID }) {
                        EntryDetailView(entry: entry)
                    }
                }
            }
        }
        .navigationTitle(profileStore.selectedProfile?.displayName ?? "Journal")
        .searchable(text: $documentVM.searchText, prompt: "Search entries...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // Category filter
                    Menu("Category") {
                        Button("All Categories") {
                            documentVM.selectedCategory = nil
                        }
                        ForEach(documentVM.categories, id: \.self) { cat in
                            Button {
                                documentVM.selectedCategory = cat
                            } label: {
                                HStack {
                                    Text(cat)
                                    if documentVM.selectedCategory == cat {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    // Provider filter
                    Menu("Provider") {
                        Button("All Providers") {
                            documentVM.selectedProvider = nil
                        }
                        ForEach(documentVM.providers, id: \.self) { prov in
                            Button {
                                documentVM.selectedProvider = prov
                            } label: {
                                HStack {
                                    Text(prov)
                                    if documentVM.selectedProvider == prov {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    if documentVM.selectedCategory != nil || documentVM.selectedProvider != nil {
                        Divider()
                        Button("Clear Filters", role: .destructive) {
                            documentVM.clearFilters()
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(
                            documentVM.selectedCategory != nil || documentVM.selectedProvider != nil
                                ? AppColors.primary
                                : AppColors.textSecondary
                        )
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(profileStore.profiles) { profile in
                        Button {
                            profileStore.selectProfile(profile.id)
                        } label: {
                            HStack {
                                Text(profile.displayName)
                                if profile.id == profileStore.selectedProfileID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button {
                        showingAddPerson = true
                    } label: {
                        Label("Add Person...", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            AddPersonSheet()
        }
        .background(AppColors.background)
    }
}

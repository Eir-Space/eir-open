import SwiftUI
import UniformTypeIdentifiers

@MainActor
class DocumentViewModel: ObservableObject {
    @Published var document: EirDocument?
    @Published var selectedEntryID: String?
    @Published var searchText: String = ""
    @Published var selectedCategory: String?
    @Published var selectedProvider: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    var filteredEntries: [EirEntry] {
        guard let entries = document?.entries else { return [] }
        return entries.filter { entry in
            let matchesSearch = searchText.isEmpty ||
                entry.content?.summary?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.content?.details?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.content?.notes?.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) == true ||
                entry.category?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.provider?.name?.localizedCaseInsensitiveContains(searchText) == true

            let matchesCategory = selectedCategory == nil || entry.category == selectedCategory
            let matchesProvider = selectedProvider == nil || entry.provider?.name == selectedProvider

            return matchesSearch && matchesCategory && matchesProvider
        }
    }

    var groupedEntries: [(key: String, entries: [EirEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.dateGroupKey }
        return grouped
            .map { (key: $0.key, entries: $0.value) }
            .sorted { lhs, rhs in
                let lhsDate = lhs.entries.first?.parsedDate ?? .distantPast
                let rhsDate = rhs.entries.first?.parsedDate ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    var categories: [String] {
        guard let entries = document?.entries else { return [] }
        return Array(Set(entries.compactMap(\.category))).sorted()
    }

    var providers: [String] {
        guard let entries = document?.entries else { return [] }
        return Array(Set(entries.compactMap(\.provider?.name))).sorted()
    }

    var selectedEntry: EirEntry? {
        document?.entries.first(where: { $0.id == selectedEntryID })
    }

    func loadFile(url: URL) {
        isLoading = true
        errorMessage = nil

        // Start security-scoped access for files from .fileImporter
        let didStartAccess = url.startAccessingSecurityScopedResource()

        do {
            document = try EirParser.parse(url: url)
            selectedEntryID = nil
            searchText = ""
            selectedCategory = nil
            selectedProvider = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }

        isLoading = false
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedProvider = nil
    }
}

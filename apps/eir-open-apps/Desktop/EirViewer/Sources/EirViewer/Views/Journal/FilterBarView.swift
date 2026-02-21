import SwiftUI

struct FilterBarView: View {
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                TextField("Search entries...", text: $documentVM.searchText)
                    .textFieldStyle(.plain)
                if !documentVM.searchText.isEmpty {
                    Button {
                        documentVM.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(AppColors.card)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 1)
            )

            Picker("Category", selection: $documentVM.selectedCategory) {
                Text("All Categories").tag(nil as String?)
                ForEach(documentVM.categories, id: \.self) { cat in
                    Text(cat).tag(cat as String?)
                }
            }
            .frame(width: 160)

            Picker("Provider", selection: $documentVM.selectedProvider) {
                Text("All Providers").tag(nil as String?)
                ForEach(documentVM.providers, id: \.self) { prov in
                    Text(prov).tag(prov as String?)
                }
            }
            .frame(width: 200)

            if documentVM.selectedCategory != nil || documentVM.selectedProvider != nil || !documentVM.searchText.isEmpty {
                Button("Clear") {
                    documentVM.clearFilters()
                }
                .foregroundColor(AppColors.primary)
            }

            Spacer()

            Text("\(documentVM.filteredEntries.count) entries")
                .font(.callout)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

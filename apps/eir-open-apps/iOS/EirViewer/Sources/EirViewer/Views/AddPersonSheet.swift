import SwiftUI
import UniformTypeIdentifiers

struct AddPersonSheet: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedURL: URL?
    @State private var parsedDoc: EirDocument?
    @State private var displayName: String = ""
    @State private var showFilePicker = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let doc = parsedDoc, let url = selectedURL {
                    parsedInfoView(doc: doc, url: url)
                } else {
                    filePickerView
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if parsedDoc != nil {
                        Button("Add") { addProfile() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "eir") ?? .yaml,
                .yaml,
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                parseFile(url: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - File Picker

    private var filePickerView: some View {
        VStack(spacing: 12) {
            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textSecondary)

                Text("Select an .eir or .yaml file")
                    .font(.callout)
                    .foregroundColor(AppColors.text)

                Button("Choose File...") {
                    showFilePicker = true
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppColors.card)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border, style: StrokeStyle(lineWidth: 2, dash: [6]))
            )

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(AppColors.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Parsed Info

    private func parsedInfoView(doc: EirDocument, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(AppColors.primarySoft)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initials(for: displayName))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    if let name = doc.metadata.patient?.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(AppColors.text)
                    }
                    if let pnr = doc.metadata.patient?.personalNumber {
                        Text(pnr)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Label("\(doc.entries.count) entries", systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(12)
            .background(AppColors.card)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                TextField("Name shown in app", text: $displayName)
                    .textFieldStyle(.roundedBorder)
            }

            Text(url.lastPathComponent)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Actions

    private func parseFile(url: URL) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let doc = try EirParser.parse(url: url)
            parsedDoc = doc
            selectedURL = url
            displayName = doc.metadata.patient?.name ?? url.deletingPathExtension().lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            parsedDoc = nil
            selectedURL = nil
        }
    }

    private func addProfile() {
        guard let url = selectedURL else { return }
        if let profile = profileStore.addProfile(displayName: displayName, fileURL: url) {
            profileStore.selectProfile(profile.id)
        }
        dismiss()
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

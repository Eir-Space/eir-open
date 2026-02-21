import SwiftUI
import UniformTypeIdentifiers

struct AddPersonSheet: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var initialURL: URL? = nil

    @State private var selectedURL: URL?
    @State private var parsedDoc: EirDocument?
    @State private var displayName: String = ""
    @State private var personalNumber: String = ""
    @State private var isDragging = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case displayName, personalNumber }

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Person")
                .font(.headline)

            if let doc = parsedDoc, let url = selectedURL {
                parsedInfoView(doc: doc, url: url)
            } else {
                filePickerView
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if parsedDoc != nil {
                    Button("Add") {
                        addProfile()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            if let url = initialURL {
                parseFile(url: url)
            }
        }
    }

    // MARK: - File Picker

    private var filePickerView: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isDragging ? AppColors.primary : AppColors.border,
                        style: StrokeStyle(lineWidth: 2, dash: [6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDragging ? AppColors.primarySoft : AppColors.card)
                    )
                    .frame(height: 120)

                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 24))
                        .foregroundColor(isDragging ? AppColors.primary : AppColors.textSecondary)

                    Text("Drop .eir or .yaml file here")
                        .font(.callout)
                        .foregroundColor(AppColors.text)

                    Button("Choose File...") {
                        pickFile()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers)
            }

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

                TextField("Name shown in sidebar", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .displayName)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Personal Number")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                TextField("e.g. 19900101-1234", text: $personalNumber)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .personalNumber)
            }

            Text(url.lastPathComponent)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Actions

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "eir") ?? .yaml,
            .yaml,
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select an EIR file (.eir or .yaml)"

        if panel.runModal() == .OK, let url = panel.url {
            parseFile(url: url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            let ext = url.pathExtension.lowercased()
            guard ext == "eir" || ext == "yaml" || ext == "yml" else { return }

            Task { @MainActor in
                parseFile(url: url)
            }
        }
        return true
    }

    private func parseFile(url: URL) {
        do {
            let doc = try EirParser.parse(url: url)
            parsedDoc = doc
            selectedURL = url
            displayName = doc.metadata.patient?.name ?? url.deletingPathExtension().lastPathComponent
            personalNumber = doc.metadata.patient?.personalNumber ?? ""
            errorMessage = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .displayName
            }
        } catch {
            errorMessage = error.localizedDescription
            parsedDoc = nil
            selectedURL = nil
        }
    }

    private func addProfile() {
        guard let url = selectedURL else { return }
        let pnr = personalNumber.isEmpty ? nil : personalNumber
        if let profile = profileStore.addProfile(displayName: displayName, personalNumber: pnr, fileURL: url) {
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

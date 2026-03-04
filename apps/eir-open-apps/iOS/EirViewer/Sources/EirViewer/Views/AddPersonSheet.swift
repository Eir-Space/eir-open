import SwiftUI
import UniformTypeIdentifiers

struct AddPersonSheet: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedURL: URL?
    @State private var parsedDoc: EirDocument?
    @State private var displayName: String = ""
    @State private var showFilePicker = false
    @State private var showQRScanner = false
    @State private var shouldDismissAfterChild = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let doc = parsedDoc, let url = selectedURL {
                    parsedInfoView(doc: doc, url: url)
                } else {
                    importOptionsView
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
        .sheet(isPresented: $showQRScanner, onDismiss: {
            // After QR scanner finishes dismissing, dismiss AddPersonSheet if a profile was loaded
            if shouldDismissAfterChild {
                shouldDismissAfterChild = false
                dismiss()
            }
        }) {
            QRScannerView()
        }
        // Auto-dismiss when a profile is loaded
        .onReceive(NotificationCenter.default.publisher(for: .profileDidLoad)) { _ in
            if showQRScanner {
                // QR scanner loaded a profile — dismiss QR first, then self via onDismiss
                shouldDismissAfterChild = true
                showQRScanner = false
            } else {
                // File import flow — no child sheet, dismiss directly
                dismiss()
            }
        }
    }

    // MARK: - Import Options

    private var importOptionsView: some View {
        VStack(spacing: 12) {
            // File import option
            Button {
                showFilePicker = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from File")
                            .font(.headline)
                            .foregroundColor(AppColors.text)
                        Text("Open an .eir or .yaml file")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(AppColors.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // QR code import option
            Button {
                showQRScanner = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan QR Code")
                            .font(.headline)
                            .foregroundColor(AppColors.text)
                        Text("Transfer from your Mac")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
                .background(AppColors.card)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

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
        // dismiss handled by .onReceive(.profileDidLoad)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

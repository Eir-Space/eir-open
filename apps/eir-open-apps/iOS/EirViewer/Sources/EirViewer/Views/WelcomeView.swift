import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @State private var showFilePicker = false
    @State private var showQRScanner = false
    @State private var showHealthKitImport = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 64))
                .foregroundColor(AppColors.primary)

            Text("Eir Viewer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text("View and explore your Swedish medical records")
                .font(.title3)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textSecondary)

                Text("Open your .eir or .yaml file to get started")
                    .font(.headline)
                    .foregroundColor(AppColors.text)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Choose File", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)

                Button {
                    showQRScanner = true
                } label: {
                    Label("Scan from Mac", systemImage: "qrcode.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.primary)

                Button {
                    showHealthKitImport = true
                } label: {
                    Label("Import from Apple Health", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.pink)
            }
            .padding(24)
            .background(AppColors.card)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .padding(.horizontal, 32)

            // Sample data button
            Button {
                loadSampleData()
            } label: {
                Label("Try with Sample Data", systemImage: "doc.text")
                    .font(.subheadline)
            }
            .foregroundColor(AppColors.primary)

            if let error = profileStore.errorMessage {
                Text(error)
                    .foregroundColor(AppColors.red)
                    .font(.callout)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Text("Supports EIR format v1.0 (.eir, .yaml)")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, 16)
        }
        .background(AppColors.background)
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
                if let profile = profileStore.addProfile(displayName: "", fileURL: url) {
                    profileStore.selectProfile(profile.id)
                }
            case .failure(let error):
                profileStore.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showQRScanner) {
            QRScannerView()
        }
        .sheet(isPresented: $showHealthKitImport) {
            HealthKitImportView()
        }
        // Auto-dismiss sheets when a profile is loaded
        .onReceive(NotificationCenter.default.publisher(for: .profileDidLoad)) { _ in
            showQRScanner = false
            showHealthKitImport = false
        }
    }

    private func loadSampleData() {
        // Copy bundled sample to Documents so it persists
        guard let bundleURL = Bundle.main.url(forResource: "sample-data", withExtension: "yaml") else {
            profileStore.errorMessage = "Sample data not found in app bundle"
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docs.appendingPathComponent("sample-data.yaml")

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: bundleURL, to: destURL)
        } catch {
            profileStore.errorMessage = "Failed to copy sample data: \(error.localizedDescription)"
            return
        }

        if let profile = profileStore.addProfile(displayName: "", fileURL: destURL) {
            profileStore.selectProfile(profile.id)
        }
    }
}

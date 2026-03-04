import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareToiPhoneView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @StateObject private var transferServer = LocalTransferServer()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Share to iPhone")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)
                Spacer()
                Button {
                    transferServer.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if transferServer.transferComplete {
                completeView
            } else if transferServer.isRunning, let url = transferServer.transferURL {
                qrCodeView(url: url)
            } else if let error = transferServer.errorMessage {
                errorView(error)
            } else {
                startView
            }
        }
        .padding(24)
        .frame(width: 360, height: 480)
        .onAppear {
            startServer()
        }
        .onDisappear {
            transferServer.stop()
        }
    }

    // MARK: - Views

    private var startView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Starting transfer server...")
                .font(.callout)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }

    private func qrCodeView(url: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            if let qrImage = generateQRCode(from: url) {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .background(Color.white)
                    .cornerRadius(12)
            }

            Text("Scan this QR code with the\nEir Viewer app on your iPhone")
                .font(.headline)
                .foregroundColor(AppColors.text)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Label("Both devices must be on the same WiFi", systemImage: "wifi")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let profile = profileStore.selectedProfile {
                    Label("Sharing: \(profile.displayName)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()
        }
    }

    private var completeView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("Transfer Complete!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text("Your records have been sent to your iPhone.")
                .font(.callout)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Done") {
                transferServer.stop()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)

            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Transfer Error")
                .font(.headline)
                .foregroundColor(AppColors.text)

            Text(message)
                .font(.callout)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                startServer()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func startServer() {
        guard let profile = profileStore.selectedProfile else {
            transferServer.errorMessage = "No profile selected"
            return
        }
        transferServer.start(fileURL: profile.fileURL)
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up for sharp rendering
        let scale = 10.0
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FileTransferQRCodeView: View {
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transferServer = LocalTransferServer()
    @State private var copiedLink = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if transferServer.transferComplete {
                    completionState
                } else if transferServer.isRunning, let url = transferServer.transferURL {
                    qrState(url: url)
                } else if let error = transferServer.errorMessage {
                    errorState(message: error)
                } else {
                    ProgressView("Startar export...")
                        .tint(AppColors.primary)
                }
            }
            .padding(24)
            .navigationTitle("QR-export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
        }
        .onAppear {
            transferServer.start(fileURL: fileURL)
        }
        .onDisappear {
            transferServer.stop()
        }
    }

    private func qrState(url: String) -> some View {
        VStack(spacing: 16) {
            if let qrImage = generateQRCode(from: url) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .background(Color.white)
                    .cornerRadius(16)
            }

            Text("Skanna QR-koden för att ladda ner exportfilen.")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Båda enheterna måste vara på samma Wi-Fi.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Text(fileURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(copiedLink ? "Länk kopierad" : "Kopiera länk") {
                UIPasteboard.general.string = url
                copiedLink = true
            }
            .buttonStyle(.bordered)
        }
    }

    private var completionState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppColors.green)

            Text("Nedladdning slutförd")
                .font(.title3)
                .fontWeight(.bold)

            Text("Exportfilen hämtades från den här enheten.")
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.orange)

            Text("Kunde inte starta QR-export")
                .font(.headline)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)

            Button("Försök igen") {
                copiedLink = false
                transferServer.start(fileURL: fileURL)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }
        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

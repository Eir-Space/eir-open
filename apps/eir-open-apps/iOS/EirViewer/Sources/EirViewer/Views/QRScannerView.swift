import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transferClient = LocalTransferClient()
    @State private var scannedURL: String?
    @State private var cameraError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = cameraError {
                    errorView(error)
                } else if transferClient.isDownloading {
                    downloadingView
                } else if let url = transferClient.downloadedURL {
                    successView(url)
                } else {
                    scannerView
                }
            }
            .background(Color.black)
            .navigationTitle("Scan from Mac")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Scanner

    private var scannerView: some View {
        VStack(spacing: 24) {
            Spacer()

            QRCameraPreview { code in
                guard scannedURL == nil else { return }
                scannedURL = code
                Task {
                    await transferClient.download(from: code)
                }
            } onError: { error in
                cameraError = error
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.primary, lineWidth: 2)
            )

            Text("Point your camera at the QR code\nshown on your Mac")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Both devices must be on the same WiFi network")
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
    }

    // MARK: - Downloading

    private var downloadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text("Downloading records...")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
    }

    // MARK: - Success

    private func successView(_ url: URL) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("Transfer Complete!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(url.lastPathComponent)
                .font(.callout)
                .foregroundColor(.gray)

            Button("Open Records") {
                if let profile = profileStore.addProfile(displayName: "", fileURL: url) {
                    profileStore.selectProfile(profile.id)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("Camera Access Required")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(message)
                .font(.callout)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primary)

            Spacer()
        }
    }
}

// MARK: - Camera Preview (AVCaptureSession wrapper)

private struct QRCameraPreview: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onError: onError)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video) else {
            onError("No camera available")
            return view
        }

        // Check permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            context.coordinator.setupSession(device: device, in: view)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        context.coordinator.setupSession(device: device, in: view)
                    } else {
                        onError("Camera access was denied. Enable it in Settings to scan QR codes.")
                    }
                }
            }
        default:
            onError("Camera access was denied. Enable it in Settings to scan QR codes.")
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeScanned: (String) -> Void
        let onError: (String) -> Void
        var session: AVCaptureSession?
        private var hasScanned = false

        init(onCodeScanned: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
            self.onError = onError
        }

        func setupSession(device: AVCaptureDevice, in view: UIView) {
            guard let session = session else { return }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                let output = AVCaptureMetadataOutput()
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    output.setMetadataObjectsDelegate(self, queue: .main)
                    output.metadataObjectTypes = [.qr]
                }

                let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds
                view.layer.addSublayer(previewLayer)

                // Auto-resize preview layer
                DispatchQueue.main.async {
                    previewLayer.frame = view.bounds
                }

                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                }
            } catch {
                onError("Could not start camera: \(error.localizedDescription)")
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !hasScanned,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  object.type == .qr,
                  let value = object.stringValue,
                  value.hasPrefix("http") else { return }

            hasScanned = true
            session?.stopRunning()

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            onCodeScanned(value)
        }
    }
}

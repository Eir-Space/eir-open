import Foundation
import Network
import SwiftUI

// MARK: - Transfer Server (macOS sends, iOS receives)

/// Lightweight HTTP server that serves an EIR file over the local network.
/// Used on macOS to share files to iOS via QR code.
@MainActor
class LocalTransferServer: ObservableObject {
    @Published var isRunning = false
    @Published var transferURL: String?
    @Published var errorMessage: String?
    @Published var transferComplete = false

    private var listener: NWListener?
    private var fileData: Data?
    private var fileName: String = "journal.eir"

    func start(fileURL: URL) {
        stop()

        // Read the file
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if didStartAccess { fileURL.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: fileURL) else {
            errorMessage = "Could not read file"
            return
        }

        fileData = data
        fileName = fileURL.lastPathComponent

        // Create listener on a random port
        let params = NWParameters.tcp
        params.includePeerToPeer = true

        do {
            listener = try NWListener(using: params)
        } catch {
            errorMessage = "Could not create server: \(error.localizedDescription)"
            return
        }

        // Advertise via Bonjour
        listener?.service = NWListener.Service(name: "EirTransfer", type: "_eir-transfer._tcp")

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    if let port = self?.listener?.port {
                        self?.isRunning = true
                        self?.transferURL = self?.buildTransferURL(port: port)
                    }
                case .failed(let error):
                    self?.errorMessage = "Server failed: \(error.localizedDescription)"
                    self?.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleConnection(connection)
            }
        }

        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        transferURL = nil
        transferComplete = false
    }

    private func buildTransferURL(port: NWEndpoint.Port) -> String? {
        // Get local IP address
        guard let ip = getLocalIPAddress() else { return nil }
        return "http://\(ip):\(port)/\(fileName)"
    }

    private func handleConnection(_ connection: NWConnection) {
        guard let fileData = self.fileData else {
            connection.cancel()
            return
        }
        let fileName = self.fileName

        connection.start(queue: .main)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            if request.contains("GET /") {
                let header = [
                    "HTTP/1.1 200 OK",
                    "Content-Type: application/x-yaml",
                    "Content-Length: \(fileData.count)",
                    "Content-Disposition: attachment; filename=\"\(fileName)\"",
                    "Access-Control-Allow-Origin: *",
                    "Connection: close",
                    "", ""
                ].joined(separator: "\r\n")

                var responseData = header.data(using: .utf8) ?? Data()
                responseData.append(fileData)

                connection.send(content: responseData, completion: .contentProcessed { _ in
                    connection.cancel()
                    Task { @MainActor in
                        self?.transferComplete = true
                    }
                })
            } else {
                connection.cancel()
            }
        }
    }
}

// MARK: - Transfer Client (iOS downloads from macOS)

@MainActor
class LocalTransferClient: ObservableObject {
    @Published var isDownloading = false
    @Published var errorMessage: String?
    @Published var downloadedURL: URL?

    func download(from urlString: String) async {
        isDownloading = true
        errorMessage = nil

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid transfer URL"
            isDownloading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                errorMessage = "Transfer failed"
                isDownloading = false
                return
            }

            // Extract filename from Content-Disposition or URL
            let fileName = url.lastPathComponent.isEmpty ? "transferred.eir" : url.lastPathComponent

            // Save to Documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destURL = docs.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try data.write(to: destURL)

            downloadedURL = destURL
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
        }

        isDownloading = false
    }
}

// MARK: - Helpers

func getLocalIPAddress() -> String? {
    var address: String?
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let interface = ptr.pointee
        let addrFamily = interface.ifa_addr.pointee.sa_family

        guard addrFamily == UInt8(AF_INET) else { continue } // IPv4 only

        let name = String(cString: interface.ifa_name)
        guard name == "en0" || name == "en1" else { continue } // WiFi interfaces

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(
            interface.ifa_addr,
            socklen_t(interface.ifa_addr.pointee.sa_len),
            &hostname, socklen_t(hostname.count),
            nil, 0,
            NI_NUMERICHOST
        )
        address = String(cString: hostname)
    }

    return address
}

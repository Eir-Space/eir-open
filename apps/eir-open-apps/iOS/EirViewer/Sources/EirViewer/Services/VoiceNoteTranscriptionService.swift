import Foundation

@MainActor
struct VoiceNoteTranscriptionService {
    struct Response: Decodable {
        let transcript: String
        let clientQuota: ManagedCloudQuota?
    }

    static func transcribe(
        draft: RecordedVoiceNoteDraft,
        settingsVM: SettingsViewModel
    ) async throws -> String {
        if let config = settingsVM.activeProvider,
           config.type.usesManagedTrialAccess,
           ChatViewModel.hasCloudConsent(for: config.type) {
            do {
                return try await transcribeHosted(draft: draft, settingsVM: settingsVM, config: config)
            } catch {
                return try await AppleSpeechTranscriptionService.transcribe(draft: draft)
            }
        }

        return try await AppleSpeechTranscriptionService.transcribe(draft: draft)
    }

    private static func transcribeHosted(
        draft: RecordedVoiceNoteDraft,
        settingsVM: SettingsViewModel,
        config: LLMProviderConfig
    ) async throws -> String {
        let token = try await settingsVM.resolvedCredential(for: config)
        let baseURL = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: baseURL)?.appending(path: "transcribe/upload") else {
            throw LLMError.requestFailed("The hosted transcription URL is not valid.")
        }

        let audioData = try Data(contentsOf: draft.fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("sv", forHTTPHeaderField: "X-Scribe-Language")
        request.setValue("sv-SE", forHTTPHeaderField: "X-Scribe-Locale")
        request.setValue("SE", forHTTPHeaderField: "X-Scribe-Country")
        request.httpBody = makeMultipartBody(boundary: boundary, data: audioData, mimeType: draft.mimeType, filename: draft.fileURL.lastPathComponent)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Transcription failed."
            throw LLMError.requestFailed(message)
        }

        let payload = try JSONDecoder().decode(Response.self, from: data)
        if let quota = payload.clientQuota {
            settingsVM.updateManagedAccessQuota(quota, for: config.type)
        }
        return payload.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func makeMultipartBody(boundary: String, data: Data, mimeType: String, filename: String) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

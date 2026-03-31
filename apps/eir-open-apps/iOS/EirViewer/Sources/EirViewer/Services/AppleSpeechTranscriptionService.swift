import Foundation
import Speech

struct AppleSpeechTranscriptionService {
    enum ServiceError: LocalizedError {
        case recognitionUnavailable
        case permissionDenied
        case permissionRestricted
        case noTranscript

        var errorDescription: String? {
            switch self {
            case .recognitionUnavailable:
                return "Speech recognition is not available on this device right now."
            case .permissionDenied:
                return "Speech recognition access is required to transcribe voice notes."
            case .permissionRestricted:
                return "Speech recognition is restricted on this device."
            case .noTranscript:
                return "The voice note could not be turned into text."
            }
        }
    }

    static func transcribe(
        draft: RecordedVoiceNoteDraft,
        localeIdentifier: String = "sv-SE"
    ) async throws -> String {
        let authorizationStatus = await requestAuthorization()
        switch authorizationStatus {
        case .authorized:
            break
        case .denied:
            throw ServiceError.permissionDenied
        case .restricted:
            throw ServiceError.permissionRestricted
        case .notDetermined:
            throw ServiceError.permissionDenied
        @unknown default:
            throw ServiceError.recognitionUnavailable
        }

        guard let recognizer = preferredRecognizer(localeIdentifier: localeIdentifier),
              recognizer.isAvailable else {
            throw ServiceError.recognitionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: draft.fileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.taskHint = .dictation

        let transcript = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = RecognitionSession(continuation: continuation)
            session.task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    session.finish(with: .failure(error))
                    return
                }

                guard let result else { return }
                guard result.isFinal else { return }

                let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if transcript.isEmpty {
                    session.finish(with: .failure(ServiceError.noTranscript))
                } else {
                    session.finish(with: .success(transcript))
                }
            }
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.noTranscript
        }
        return trimmed
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func preferredRecognizer(localeIdentifier: String) -> SFSpeechRecognizer? {
        if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) {
            return recognizer
        }

        if let recognizer = SFSpeechRecognizer(locale: Locale.current) {
            return recognizer
        }

        return SFSpeechRecognizer()
    }
}

private final class RecognitionSession {
    private var continuation: CheckedContinuation<String, Error>?
    var task: SFSpeechRecognitionTask?

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func finish(with result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        task?.cancel()
        task = nil
        continuation.resume(with: result)
    }

    deinit {
        task?.cancel()
    }
}

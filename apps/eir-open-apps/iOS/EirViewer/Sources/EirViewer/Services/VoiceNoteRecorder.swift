import AVFoundation
import Foundation

@MainActor
final class VoiceNoteRecorder: NSObject, ObservableObject {
    enum RecorderError: LocalizedError {
        case microphonePermissionDenied
        case recorderUnavailable

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access is required to record a voice note."
            case .recorderUnavailable:
                return "Voice recording could not be started."
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var liveWaveform: [Double] = Array(repeating: 0.12, count: 28)
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var capturedWaveform: [Double] = []
    private var recordingURL: URL?

    func start() async throws {
        errorMessage = nil
        try await requestMicrophonePermission()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let url = try Self.makeRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            throw RecorderError.recorderUnavailable
        }

        self.recorder = recorder
        self.recordingURL = url
        self.startedAt = Date()
        self.duration = 0
        self.capturedWaveform = []
        self.liveWaveform = Array(repeating: 0.12, count: 28)
        self.isRecording = true
        startMetering()
    }

    func stop() -> RecordedVoiceNoteDraft? {
        guard let recorder, let recordingURL else {
            cleanup()
            return nil
        }

        recorder.stop()
        let duration = recorder.currentTime
        let waveform = finalizedWaveform(from: capturedWaveform)
        cleanup()

        return RecordedVoiceNoteDraft(
            fileURL: recordingURL,
            duration: duration,
            waveform: waveform,
            mimeType: "audio/mp4"
        )
    }

    func cancel() {
        recorder?.stop()
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        cleanup()
    }

    private func cleanup() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder = nil
        recordingURL = nil
        startedAt = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: #selector(handleMeterTimer), userInfo: nil, repeats: true)
    }

    @objc
    private func handleMeterTimer() {
        guard let recorder else { return }
        recorder.updateMeters()
        duration = Date().timeIntervalSince(startedAt ?? Date())

        let power = recorder.averagePower(forChannel: 0)
        let normalized = Self.normalizePower(power)
        capturedWaveform.append(normalized)
        if capturedWaveform.count > 96 {
            capturedWaveform.removeFirst(capturedWaveform.count - 96)
        }
        liveWaveform = Self.compactWaveform(capturedWaveform, targetCount: 28)
    }

    private func requestMicrophonePermission() async throws {
        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }

        guard granted else {
            throw RecorderError.microphonePermissionDenied
        }
    }

    private func finalizedWaveform(from values: [Double]) -> [Double] {
        let compact = Self.compactWaveform(values, targetCount: 32)
        return compact.isEmpty ? Array(repeating: 0.16, count: 16) : compact
    }

    private static func compactWaveform(_ values: [Double], targetCount: Int) -> [Double] {
        guard !values.isEmpty else {
            return Array(repeating: 0.12, count: targetCount)
        }

        if values.count <= targetCount {
            let padding = max(0, targetCount - values.count)
            return Array(repeating: 0.12, count: padding) + values
        }

        let bucketSize = Double(values.count) / Double(targetCount)
        return (0..<targetCount).map { index in
            let start = Int(Double(index) * bucketSize)
            let end = min(values.count, Int(Double(index + 1) * bucketSize))
            let bucket = values[start..<max(start + 1, end)]
            return bucket.max() ?? 0.12
        }
    }

    private static func normalizePower(_ power: Float) -> Double {
        guard power.isFinite else { return 0.12 }
        let clamped = max(-50, min(0, power))
        return max(0.12, Double((clamped + 50) / 50))
    }

    private static func makeRecordingURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appending(path: "VoiceNotes", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "\(UUID().uuidString).m4a")
    }
}

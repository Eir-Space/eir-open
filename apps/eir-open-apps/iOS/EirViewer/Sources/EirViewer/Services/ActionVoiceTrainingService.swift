import AVFoundation
import Foundation

struct ActionVoiceExercise: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let summary: String
    let howTo: String
    let durationLabel: String
}

struct ActionVoiceAnalysisSummary: Equatable {
    let stabilityScore: Int
    let averagePitch: Int?
    let averageVolume: Int
    let durationSeconds: Int
    let voiceBreaks: Int
}

struct ActionVoicePitchMatchSummary: Equatable {
    let targetNote: String
    let accuracyPercent: Int
    let matches: Int
    let voicedSamples: Int
}

struct ActionVoiceReadingSummary: Equatable {
    let durationSeconds: Int
    let wordsPerMinute: Int
    let averageVolume: Int
}

enum ActionVoiceLibrary {
    static let readingPassage = "The quick brown fox jumps over the lazy dog. She sells seashells by the seashore. Unique New York, unique New York."

    static let guidedExercises: [ActionVoiceExercise] = [
        ActionVoiceExercise(
            id: "lip-trills",
            title: "Lip trills",
            category: "Warm up",
            summary: "Blow air through relaxed lips and let them flutter while you add a gentle pitch.",
            howTo: "Keep the jaw loose, start on an easy note, and glide up and down without forcing volume.",
            durationLabel: "1-2 min"
        ),
        ActionVoiceExercise(
            id: "straw-phonation",
            title: "Straw phonation",
            category: "Resonance",
            summary: "Hum through a small straw to balance pressure and reduce vocal fatigue.",
            howTo: "Use a comfortable mid-range pitch and aim for a smooth, steady tone rather than loudness.",
            durationLabel: "2 min"
        ),
        ActionVoiceExercise(
            id: "diaphragmatic-hiss",
            title: "Diaphragmatic hiss",
            category: "Breath support",
            summary: "Inhale low into the body, then exhale on a controlled \"tssss\" without collapsing the chest.",
            howTo: "Let the exhale stay even from start to finish. If the hiss pulses or drops, reset and shorten the rep.",
            durationLabel: "1 min"
        ),
        ActionVoiceExercise(
            id: "descending-glide",
            title: "Descending glide",
            category: "Cooldown",
            summary: "Start at a comfortable higher note and gently slide down to the bottom of your easy range.",
            howTo: "Use a soft \"whee\" or sighing glide. The goal is ease, not range pushing.",
            durationLabel: "1 min"
        )
    ]

    static let targetNotes = ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"]
}

@MainActor
final class ActionVoiceTrainingService: ObservableObject {
    enum RecorderError: LocalizedError {
        case microphonePermissionDenied
        case inputRouteUnavailable
        case unavailable

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access is required for voice exercises."
            case .inputRouteUnavailable:
                return "Voice capture is not available right now. Check that a microphone is connected, then try again."
            case .unavailable:
                return "Voice capture could not be started."
            }
        }
    }

    enum CaptureMode {
        case analysis
        case pitchMatch(targetNote: String)
        case reading(wordCount: Int)
    }

    @Published private(set) var isCapturing = false
    @Published private(set) var mode: CaptureMode?
    @Published private(set) var currentFrequency: Int = 0
    @Published private(set) var currentVolume: Int = 0
    @Published private(set) var currentNoteName = "--"
    @Published private(set) var durationSeconds = 0
    @Published private(set) var lastAnalysisSummary: ActionVoiceAnalysisSummary?
    @Published private(set) var lastPitchMatchSummary: ActionVoicePitchMatchSummary?
    @Published private(set) var lastReadingSummary: ActionVoiceReadingSummary?
    @Published var errorMessage: String?

    private let captureEngine = AVAudioEngine()
    private var captureAccumulator: VoiceCaptureAccumulator?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private var tonePlayer: ActionVoiceTonePlayer?

    nonisolated static var captureEnvironmentNote: String? {
#if targetEnvironment(simulator)
        return "Voice capture can be unreliable in Simulator. If recording does not start, use a physical iPhone for the full experience."
#else
        return nil
#endif
    }

    func startAnalysis() async {
        await startCapture(mode: .analysis)
    }

    func stopAnalysis() {
        stopCapture()
    }

    func startPitchMatch(targetNote: String) async {
        await startCapture(mode: .pitchMatch(targetNote: targetNote))
    }

    func stopPitchMatch() {
        stopCapture()
    }

    func startReadingPractice() async {
        let wordCount = ActionVoiceLibrary.readingPassage.split(whereSeparator: \.isWhitespace).count
        await startCapture(mode: .reading(wordCount: wordCount))
    }

    func stopReadingPractice() {
        stopCapture()
    }

    func playTargetNote(_ note: String) {
        let frequency = Self.noteToFrequency(note)
        tonePlayer?.stop()
        tonePlayer = ActionVoiceTonePlayer()
        tonePlayer?.play(frequency: frequency)
    }

    func stopTonePlayback() {
        tonePlayer?.stop()
        tonePlayer = nil
    }

    private func startCapture(mode: CaptureMode) async {
        stopCapture(resetLiveMetricsOnly: true)
        errorMessage = nil
        lastAnalysisSummary = nil
        lastPitchMatchSummary = nil
        lastReadingSummary = nil

        do {
            try await requestMicrophonePermission()

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            guard session.isInputAvailable else {
                throw RecorderError.inputRouteUnavailable
            }
            if let availableInputs = session.availableInputs, availableInputs.isEmpty {
                throw RecorderError.inputRouteUnavailable
            }

            let inputNode = captureEngine.inputNode
            let inputFormat = inputNode.inputFormat(forBus: 0)
            let outputFormat = inputNode.outputFormat(forBus: 0)
            guard outputFormat.sampleRate > 0,
                  (outputFormat.channelCount > 0 || inputFormat.channelCount > 0) else {
                throw RecorderError.inputRouteUnavailable
            }
            let accumulator = VoiceCaptureAccumulator(mode: mode)
            captureAccumulator = accumulator

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
                guard let self else { return }
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frameCount = Int(buffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                let sampleRate = buffer.format.sampleRate
                guard sampleRate > 0 else { return }
                let liveMetrics = accumulator.ingest(samples: samples, sampleRate: sampleRate)

                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.currentFrequency = liveMetrics.frequency
                    self.currentVolume = liveMetrics.volume
                    self.currentNoteName = liveMetrics.noteName
                }
            }

            captureEngine.prepare()
            try captureEngine.start()

            self.mode = mode
            isCapturing = true
            startedAt = Date()
            durationSeconds = 0
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
            stopCapture(resetLiveMetricsOnly: true)
        }
    }

    private func stopCapture(resetLiveMetricsOnly: Bool = false) {
        meterTimer?.invalidate()
        meterTimer = nil

        captureEngine.inputNode.removeTap(onBus: 0)
        captureEngine.stop()
        captureEngine.reset()

        if !resetLiveMetricsOnly, let accumulator = captureAccumulator, let mode {
            let elapsed = max(1, durationSeconds)
            switch mode {
            case .analysis:
                lastAnalysisSummary = accumulator.makeAnalysisSummary(durationSeconds: elapsed)
            case let .pitchMatch(targetNote):
                lastPitchMatchSummary = accumulator.makePitchMatchSummary(targetNote: targetNote)
            case let .reading(wordCount):
                lastReadingSummary = accumulator.makeReadingSummary(durationSeconds: elapsed, wordCount: wordCount)
            }
        }

        captureAccumulator = nil
        isCapturing = false
        mode = nil
        startedAt = nil

        if resetLiveMetricsOnly {
            currentFrequency = 0
            currentVolume = 0
            currentNoteName = "--"
            durationSeconds = 0
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.durationSeconds = Int(Date().timeIntervalSince(self.startedAt ?? Date()))
            }
        }
    }

    private func requestMicrophonePermission() async throws {
        let granted = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }

        guard granted else {
            throw RecorderError.microphonePermissionDenied
        }
    }

    nonisolated static func noteToFrequency(_ note: String) -> Double {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let a4 = 440.0
        guard let match = note.range(of: #"([A-G]#?)(\d)"#, options: .regularExpression) else {
            return a4
        }

        let value = String(note[match])
        let notePart = value.dropLast()
        guard let octave = Int(String(value.suffix(1))),
              let noteIndex = noteNames.firstIndex(of: String(notePart)) else {
            return a4
        }

        let semitonesFromA4 = (octave - 4) * 12 + (noteIndex - 9)
        return a4 * pow(2, Double(semitonesFromA4) / 12.0)
    }

    nonisolated static func noteName(for frequency: Double) -> String {
        guard frequency >= 80, frequency <= 1200 else { return "--" }
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let semitones = 12 * log2(frequency / 440.0)
        let noteNumber = Int(round(semitones)) + 57
        let noteIndex = ((noteNumber % 12) + 12) % 12
        let octave = noteNumber / 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

private struct VoiceLiveMetrics {
    let frequency: Int
    let volume: Int
    let noteName: String
}

private final class VoiceCaptureAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private let mode: ActionVoiceTrainingService.CaptureMode

    private var pitches: [Double] = []
    private var volumes: [Double] = []
    private var voicedSamples = 0
    private var pitchMatches = 0
    private var previousPitch: Double = 0
    private var voiceBreaks = 0

    init(mode: ActionVoiceTrainingService.CaptureMode) {
        self.mode = mode
    }

    func ingest(samples: [Float], sampleRate: Double) -> VoiceLiveMetrics {
        let rms = Self.rms(samples)
        let volume = min(Int(rms * 1000), 100)
        let pitch = Self.autoCorrelate(samples: samples, sampleRate: sampleRate)
        let noteName = ActionVoiceTrainingService.noteName(for: pitch)

        lock.lock()
        defer { lock.unlock() }

        if pitch > 80, pitch < 1200, volume > 5 {
            pitches.append(pitch)
            volumes.append(rms)
            voicedSamples += 1

            if previousPitch > 0 {
                let drop = (previousPitch - pitch) / previousPitch
                if drop > 0.5 {
                    voiceBreaks += 1
                }
            }
            previousPitch = pitch

            if case let .pitchMatch(targetNote) = mode {
                let targetFrequency = ActionVoiceTrainingService.noteToFrequency(targetNote)
                if Self.isPitchMatch(pitch, targetFrequency: targetFrequency) {
                    pitchMatches += 1
                }
            }
        } else if volume > 5, previousPitch > 0 {
            voiceBreaks += 1
            previousPitch = 0
        }

        return VoiceLiveMetrics(
            frequency: pitch > 0 ? Int(round(pitch)) : 0,
            volume: max(0, volume),
            noteName: noteName
        )
    }

    func makeAnalysisSummary(durationSeconds: Int) -> ActionVoiceAnalysisSummary {
        lock.lock()
        defer { lock.unlock() }

        let filteredPitches = Self.filteredPitchSample(from: pitches)
        let averagePitch = filteredPitches.isEmpty ? nil : Int(filteredPitches.reduce(0, +) / Double(filteredPitches.count))
        let averageVolume = volumes.isEmpty ? 0 : Int((volumes.reduce(0, +) / Double(volumes.count)) * 100)
        let score = Self.stabilityScore(for: filteredPitches)

        return ActionVoiceAnalysisSummary(
            stabilityScore: score,
            averagePitch: averagePitch,
            averageVolume: averageVolume,
            durationSeconds: durationSeconds,
            voiceBreaks: voiceBreaks
        )
    }

    func makePitchMatchSummary(targetNote: String) -> ActionVoicePitchMatchSummary {
        lock.lock()
        defer { lock.unlock() }

        let accuracy = voicedSamples == 0 ? 0 : Int((Double(pitchMatches) / Double(voicedSamples)) * 100)
        return ActionVoicePitchMatchSummary(
            targetNote: targetNote,
            accuracyPercent: accuracy,
            matches: pitchMatches,
            voicedSamples: voicedSamples
        )
    }

    func makeReadingSummary(durationSeconds: Int, wordCount: Int) -> ActionVoiceReadingSummary {
        lock.lock()
        defer { lock.unlock() }

        let averageVolume = volumes.isEmpty ? 0 : Int((volumes.reduce(0, +) / Double(volumes.count)) * 100)
        let wordsPerMinute = durationSeconds > 0 ? Int((Double(wordCount) / Double(durationSeconds)) * 60) : 0

        return ActionVoiceReadingSummary(
            durationSeconds: durationSeconds,
            wordsPerMinute: wordsPerMinute,
            averageVolume: averageVolume
        )
    }

    private static func rms(_ samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(0.0) { partial, value in
            partial + Double(value * value)
        }
        return sqrt(sum / Double(samples.count))
    }

    private static func isPitchMatch(_ pitch: Double, targetFrequency: Double) -> Bool {
        guard pitch > 80, targetFrequency > 80 else { return false }
        let cents = 1200 * log2(pitch / targetFrequency)
        return abs(cents) < 50
    }

    private static func filteredPitchSample(from pitches: [Double]) -> [Double] {
        guard pitches.count >= 4 else { return pitches }
        let sorted = pitches.sorted()
        let q1 = sorted[sorted.count / 4]
        let q3 = sorted[(sorted.count * 3) / 4]
        let iqr = q3 - q1
        return pitches.filter { $0 >= q1 - 1.5 * iqr && $0 <= q3 + 1.5 * iqr }
    }

    private static func stabilityScore(for pitches: [Double]) -> Int {
        guard pitches.count >= 4 else { return 0 }
        let mean = pitches.reduce(0, +) / Double(pitches.count)
        let variance = pitches.reduce(0) { partial, pitch in
            partial + pow(pitch - mean, 2)
        } / Double(pitches.count)
        let stddev = sqrt(variance)
        let score = max(0, min(100, 100 - (stddev * 10)))
        return Int(round(score))
    }

    private static func autoCorrelate(samples: [Float], sampleRate: Double) -> Double {
        guard samples.count > 32 else { return -1 }

        let rms = Self.rms(samples)
        if rms < 0.01 {
            return -1
        }

        let threshold = Float(0.2)
        var start = 0
        var end = samples.count - 1

        for index in 0 ..< samples.count / 2 {
            if abs(samples[index]) < threshold {
                start = index
                break
            }
        }

        for index in 1 ..< samples.count / 2 {
            if abs(samples[samples.count - index]) < threshold {
                end = samples.count - index
                break
            }
        }

        let trimmed = Array(samples[start..<max(start + 1, end)])
        guard trimmed.count > 32 else { return -1 }

        var correlations = Array(repeating: 0.0, count: trimmed.count)
        for offset in 0 ..< trimmed.count {
            var sum = 0.0
            for index in 0 ..< trimmed.count - offset {
                sum += Double(trimmed[index] * trimmed[index + offset])
            }
            correlations[offset] = sum
        }

        var dip = 0
        while dip + 1 < correlations.count && correlations[dip] > correlations[dip + 1] {
            dip += 1
        }

        var peakValue = -Double.infinity
        var peakIndex = -1
        for index in dip ..< correlations.count {
            if correlations[index] > peakValue {
                peakValue = correlations[index]
                peakIndex = index
            }
        }

        guard peakIndex > 0 else { return -1 }
        return sampleRate / Double(peakIndex)
    }
}

@MainActor
private final class ActionVoiceTonePlayer {
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var phase: Double = 0

    func play(frequency: Double) {
        stop()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            let sampleRate = format?.sampleRate ?? 44_100

            let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self else { return noErr }
                let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
                let increment = (2 * Double.pi * frequency) / sampleRate

                for frame in 0 ..< Int(frameCount) {
                    let sample = Float(sin(self.phase) * 0.24)
                    self.phase = (self.phase + increment).truncatingRemainder(dividingBy: 2 * Double.pi)

                    for bufferIndex in 0 ..< bufferList.count {
                        guard let pointer = bufferList[bufferIndex].mData?.assumingMemoryBound(to: Float.self) else { continue }
                        pointer[frame] = sample
                    }
                }
                return noErr
            }

            self.phase = 0
            self.engine = engine
            self.sourceNode = source

            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.75
            engine.prepare()
            try engine.start()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 550_000_000)
                self?.stop()
            }
        } catch {
            stop()
        }
    }

    func stop() {
        engine?.stop()
        engine?.reset()
        engine = nil
        sourceNode = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

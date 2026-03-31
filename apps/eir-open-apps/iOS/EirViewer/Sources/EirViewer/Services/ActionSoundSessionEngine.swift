import AVFoundation
import Foundation

struct ActionSoundCollection: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let symbolName: String
    let themeHex: String
    let helperText: String
    let presets: [ActionSoundPreset]

    var themeColor: String { themeHex }
}

struct ActionSoundPreset: Identifiable, Hashable {
    enum EngineMode: Hashable {
        case binaural(beatFrequency: Double)
        case isochronic(pulseFrequency: Double)
        case whiteNoise
        case pinkNoise
        case brownNoise
    }

    let id: String
    let title: String
    let subtitle: String
    let details: String
    let systemImage: String
    let themeHex: String
    let benefits: [String]
    let requiresHeadphones: Bool
    let engineMode: EngineMode
}

enum ActionSoundLibrary {
    static let durationOptions: [TimeInterval] = [5 * 60, 10 * 60, 20 * 60, 30 * 60]

    static let collections: [ActionSoundCollection] = [
        ActionSoundCollection(
            id: "binaural-beats",
            title: "Binaural beats",
            summary: "Stereo tones tuned for rest, meditation, or focus. Headphones matter here because each ear gets a slightly different signal.",
            symbolName: "waveform.path.ecg",
            themeHex: "5F4BB6",
            helperText: "Best used with headphones in a quiet space. Eir treats these as support tools, not treatment.",
            presets: [
                ActionSoundPreset(
                    id: "delta-binaural",
                    title: "Delta",
                    subtitle: "Deep sleep",
                    details: "A 2 Hz beat aimed at bedtime, rest, and downshifting late in the day.",
                    systemImage: "moon.stars.fill",
                    themeHex: "8B5CF6",
                    benefits: ["A gentle pre-sleep wind-down", "Useful when your system feels too activated to settle"],
                    requiresHeadphones: true,
                    engineMode: .binaural(beatFrequency: 2)
                ),
                ActionSoundPreset(
                    id: "theta-binaural",
                    title: "Theta",
                    subtitle: "Meditation and creativity",
                    details: "A 6 Hz beat for deeper reflective states, mindfulness, and slower work.",
                    systemImage: "sparkles",
                    themeHex: "6366F1",
                    benefits: ["Supports longer meditation blocks", "Good for sketching, writing, and reflective practice"],
                    requiresHeadphones: true,
                    engineMode: .binaural(beatFrequency: 6)
                ),
                ActionSoundPreset(
                    id: "alpha-binaural",
                    title: "Alpha",
                    subtitle: "Relaxation",
                    details: "A 10 Hz beat designed for calm focus, decompression, and lighter meditation.",
                    systemImage: "leaf.fill",
                    themeHex: "0EA5E9",
                    benefits: ["Brings the room down before the next task", "A good middle ground when silence feels too sharp"],
                    requiresHeadphones: true,
                    engineMode: .binaural(beatFrequency: 10)
                ),
                ActionSoundPreset(
                    id: "beta-binaural",
                    title: "Beta",
                    subtitle: "Focus and alertness",
                    details: "An 18 Hz beat for study blocks, admin work, and sharper attention.",
                    systemImage: "bolt.fill",
                    themeHex: "10B981",
                    benefits: ["Useful for short focused sessions", "Pairs well with planning, reading, or deep work"],
                    requiresHeadphones: true,
                    engineMode: .binaural(beatFrequency: 18)
                )
            ]
        ),
        ActionSoundCollection(
            id: "isochronic-tones",
            title: "Isochronic tones",
            summary: "Single pulsing tones with a distinct rhythmic envelope. Easier to use without headphones and better for open-room listening.",
            symbolName: "dot.radiowaves.left.and.right",
            themeHex: "175676",
            helperText: "Isochronic tones have a more obvious pulse. Start with a short session if you have not used them before.",
            presets: [
                ActionSoundPreset(
                    id: "delta-isochronic",
                    title: "Delta pulse",
                    subtitle: "Sleep support",
                    details: "A slow 2 Hz pulse for bedtime routines and nighttime downshifting.",
                    systemImage: "bed.double.fill",
                    themeHex: "8B5CF6",
                    benefits: ["Useful before sleep", "Can make breathwork feel more anchored"],
                    requiresHeadphones: false,
                    engineMode: .isochronic(pulseFrequency: 2)
                ),
                ActionSoundPreset(
                    id: "theta-isochronic",
                    title: "Theta pulse",
                    subtitle: "Meditation and slowing down",
                    details: "A 6 Hz pulse that creates a slower internal rhythm for meditation or quiet reflection.",
                    systemImage: "figure.mind.and.body",
                    themeHex: "6366F1",
                    benefits: ["Supports reflective journaling", "Good after high-input parts of the day"],
                    requiresHeadphones: false,
                    engineMode: .isochronic(pulseFrequency: 6)
                ),
                ActionSoundPreset(
                    id: "alpha-isochronic",
                    title: "Alpha pulse",
                    subtitle: "Calm clarity",
                    details: "A 10 Hz pulse to ease into lighter focus or decompression.",
                    systemImage: "drop.fill",
                    themeHex: "0EA5E9",
                    benefits: ["Smooth transition into reading or planning", "Less intense than silence when the mind is busy"],
                    requiresHeadphones: false,
                    engineMode: .isochronic(pulseFrequency: 10)
                ),
                ActionSoundPreset(
                    id: "beta-isochronic",
                    title: "Beta pulse",
                    subtitle: "Work blocks",
                    details: "An 18 Hz pulse for sharper task engagement and short bursts of concentration.",
                    systemImage: "timer",
                    themeHex: "10B981",
                    benefits: ["Designed for work sprints", "Useful when you want a clear start signal"],
                    requiresHeadphones: false,
                    engineMode: .isochronic(pulseFrequency: 18)
                )
            ]
        ),
        ActionSoundCollection(
            id: "colored-noise",
            title: "Colored noise",
            summary: "Simple noise layers to mask distraction, soften the room, and create a steadier sensory background.",
            symbolName: "speaker.wave.3.fill",
            themeHex: "A44A3F",
            helperText: "Colored noise can work in the background while you read, stretch, rest, or settle for sleep.",
            presets: [
                ActionSoundPreset(
                    id: "white-noise",
                    title: "White noise",
                    subtitle: "Attention and masking",
                    details: "Equal power across frequencies. Think fan noise or soft static.",
                    systemImage: "circle.grid.3x3.fill",
                    themeHex: "3B82F6",
                    benefits: ["Masks sudden environmental sounds", "Can support attention when the room feels too interruptive"],
                    requiresHeadphones: false,
                    engineMode: .whiteNoise
                ),
                ActionSoundPreset(
                    id: "pink-noise",
                    title: "Pink noise",
                    subtitle: "Rest and softer sleep",
                    details: "More energy in the lower range, closer to rainfall or steady natural ambience.",
                    systemImage: "cloud.drizzle.fill",
                    themeHex: "EC4899",
                    benefits: ["A softer sleep backdrop than white noise", "Good when you want sound without sharp edges"],
                    requiresHeadphones: false,
                    engineMode: .pinkNoise
                ),
                ActionSoundPreset(
                    id: "brown-noise",
                    title: "Brown noise",
                    subtitle: "Grounding and deep calm",
                    details: "A lower, heavier rumble that can feel more cocooning than white or pink noise.",
                    systemImage: "mountain.2.fill",
                    themeHex: "F59E0B",
                    benefits: ["Works well for overstimulation and racing thoughts", "Pairs naturally with stretching or journaling"],
                    requiresHeadphones: false,
                    engineMode: .brownNoise
                )
            ]
        )
    ]
}

@MainActor
final class ActionSoundSessionEngine: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var activePresetID: String?
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var errorMessage: String?
    @Published var selectedDuration: TimeInterval = ActionSoundLibrary.durationOptions[1]
    @Published var volume: Double = 0.58 {
        didSet {
            let clamped = min(max(volume, 0.05), 1)
            if clamped != volume {
                volume = clamped
                return
            }
            engine?.mainMixerNode.outputVolume = Float(clamped)
        }
    }

    private let sampleRate: Double = 44_100
    private let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)

    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var renderState = ActionSoundRenderState()
    private var timer: Timer?
    private var activePreset: ActionSoundPreset?

    func togglePlayback(for preset: ActionSoundPreset) {
        if activePresetID == preset.id, isPlaying {
            stop()
            return
        }
        play(preset: preset, duration: selectedDuration)
    }

    func play(preset: ActionSoundPreset, duration: TimeInterval) {
        stop()

        do {
            try configureAudioSession()

            let audioEngine = AVAudioEngine()
            let renderFormat = stereoFormat ?? audioEngine.mainMixerNode.outputFormat(forBus: 0)

            renderState.configure(for: preset.engineMode, sampleRate: renderFormat.sampleRate)

            let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self else { return noErr }
                let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0 ..< Int(frameCount) {
                    let sample = self.renderState.nextSample()
                    for bufferIndex in 0 ..< bufferList.count {
                        guard let pointer = bufferList[bufferIndex].mData?.assumingMemoryBound(to: Float.self) else { continue }
                        pointer[frame] = bufferIndex == 0 ? sample.left : sample.right
                    }
                }
                return noErr
            }

            audioEngine.attach(source)
            audioEngine.connect(source, to: audioEngine.mainMixerNode, format: renderFormat)
            audioEngine.mainMixerNode.outputVolume = Float(volume)
            audioEngine.prepare()
            try audioEngine.start()

            engine = audioEngine
            sourceNode = source
            activePreset = preset
            activePresetID = preset.id
            isPlaying = true
            errorMessage = nil

            startTimer(duration: duration)
        } catch {
            errorMessage = "Sound session could not start."
            stop(deactivateSession: false)
        }
    }

    func stop() {
        stop(deactivateSession: true)
    }

    private func stop(deactivateSession: Bool) {
        timer?.invalidate()
        timer = nil

        sourceNode = nil
        engine?.stop()
        engine?.reset()
        engine = nil

        activePreset = nil
        activePresetID = nil
        isPlaying = false
        remainingSeconds = 0

        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startTimer(duration: TimeInterval) {
        remainingSeconds = Int(duration)
        let deadline = Date().addingTimeInterval(duration)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded(.down)))
                self.remainingSeconds = remaining

                if remaining <= 0 {
                    self.stop()
                }
            }
        }
    }
}

private struct ActionSoundRenderState {
    private struct StereoSample {
        let left: Float
        let right: Float
    }

    private enum Mode {
        case silence
        case binaural(beatFrequency: Double)
        case isochronic(pulseFrequency: Double)
        case whiteNoise
        case pinkNoise
        case brownNoise
    }

    private var mode: Mode = .silence
    private var sampleRate: Double = 44_100
    private var leftPhase: Double = 0
    private var rightPhase: Double = 0
    private var pulsePhase: Double = 0
    private var rngState: UInt64 = 0x1234ABCD
    private var brownSample: Double = 0
    private var pinkB0: Double = 0
    private var pinkB1: Double = 0
    private var pinkB2: Double = 0
    private var pinkB3: Double = 0
    private var pinkB4: Double = 0
    private var pinkB5: Double = 0
    private var pinkB6: Double = 0

    mutating func configure(for mode: ActionSoundPreset.EngineMode, sampleRate: Double) {
        self.sampleRate = sampleRate
        leftPhase = 0
        rightPhase = 0
        pulsePhase = 0
        brownSample = 0
        pinkB0 = 0
        pinkB1 = 0
        pinkB2 = 0
        pinkB3 = 0
        pinkB4 = 0
        pinkB5 = 0
        pinkB6 = 0

        switch mode {
        case let .binaural(beatFrequency):
            self.mode = .binaural(beatFrequency: beatFrequency)
        case let .isochronic(pulseFrequency):
            self.mode = .isochronic(pulseFrequency: pulseFrequency)
        case .whiteNoise:
            self.mode = .whiteNoise
        case .pinkNoise:
            self.mode = .pinkNoise
        case .brownNoise:
            self.mode = .brownNoise
        }
    }

    mutating func nextSample() -> (left: Float, right: Float) {
        let sample: StereoSample
        switch mode {
        case .silence:
            sample = StereoSample(left: 0, right: 0)
        case let .binaural(beatFrequency):
            sample = nextBinauralSample(beatFrequency: beatFrequency)
        case let .isochronic(pulseFrequency):
            sample = nextIsochronicSample(pulseFrequency: pulseFrequency)
        case .whiteNoise:
            sample = nextWhiteNoiseSample()
        case .pinkNoise:
            sample = nextPinkNoiseSample()
        case .brownNoise:
            sample = nextBrownNoiseSample()
        }

        return (sample.left, sample.right)
    }

    private mutating func nextBinauralSample(beatFrequency: Double) -> StereoSample {
        let baseFrequency = 200.0
        let leftIncrement = (2 * Double.pi * baseFrequency) / sampleRate
        let rightIncrement = (2 * Double.pi * (baseFrequency + beatFrequency)) / sampleRate

        let left = sin(leftPhase) * 0.16
        let right = sin(rightPhase) * 0.16

        leftPhase = (leftPhase + leftIncrement).truncatingRemainder(dividingBy: 2 * Double.pi)
        rightPhase = (rightPhase + rightIncrement).truncatingRemainder(dividingBy: 2 * Double.pi)

        return StereoSample(left: Float(left), right: Float(right))
    }

    private mutating func nextIsochronicSample(pulseFrequency: Double) -> StereoSample {
        let baseFrequency = 200.0
        let toneIncrement = (2 * Double.pi * baseFrequency) / sampleRate
        let pulseIncrement = pulseFrequency / sampleRate

        let cyclePosition = pulsePhase.truncatingRemainder(dividingBy: 1)
        let envelope = cyclePosition < 0.48 ? 1.0 : 0.12
        let sample = sin(leftPhase) * envelope * 0.18

        leftPhase = (leftPhase + toneIncrement).truncatingRemainder(dividingBy: 2 * Double.pi)
        pulsePhase = (pulsePhase + pulseIncrement).truncatingRemainder(dividingBy: 1)

        return StereoSample(left: Float(sample), right: Float(sample))
    }

    private mutating func nextWhiteNoiseSample() -> StereoSample {
        let sample = randomUnitSample() * 0.18
        return StereoSample(left: Float(sample), right: Float(sample))
    }

    private mutating func nextPinkNoiseSample() -> StereoSample {
        let white = randomUnitSample()
        pinkB0 = 0.99886 * pinkB0 + white * 0.0555179
        pinkB1 = 0.99332 * pinkB1 + white * 0.0750759
        pinkB2 = 0.96900 * pinkB2 + white * 0.1538520
        pinkB3 = 0.86650 * pinkB3 + white * 0.3104856
        pinkB4 = 0.55000 * pinkB4 + white * 0.5329522
        pinkB5 = -0.7616 * pinkB5 - white * 0.0168980
        let output = (pinkB0 + pinkB1 + pinkB2 + pinkB3 + pinkB4 + pinkB5 + pinkB6 + white * 0.5362) * 0.08
        pinkB6 = white * 0.115926
        return StereoSample(left: Float(output), right: Float(output))
    }

    private mutating func nextBrownNoiseSample() -> StereoSample {
        let white = randomUnitSample() * 0.05
        brownSample = (brownSample + white) / 1.02
        let output = max(-1, min(1, brownSample * 3.5)) * 0.14
        return StereoSample(left: Float(output), right: Float(output))
    }

    private mutating func randomUnitSample() -> Double {
        rngState = 2862933555777941757 &* rngState &+ 3037000493
        let upper = Double((rngState >> 33) & 0xFFFF_FFFF)
        let normalized = upper / Double(UInt32.max)
        return normalized * 2 - 1
    }
}

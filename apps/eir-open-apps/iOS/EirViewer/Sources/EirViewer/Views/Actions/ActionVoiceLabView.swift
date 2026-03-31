import SwiftUI

struct ActionVoiceLabView: View {
    @StateObject private var service = ActionVoiceTrainingService()
    @State private var selectedTargetNote = "A4"

    private let accent = Color(hex: "C2410C")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHero(
                    eyebrow: "Voice",
                    title: "Voice Lab",
                    summary: "Train pitch control, steadier speech, and vocal ease with a microphone-led practice space.",
                    accent: accent,
                    durationLabel: "3 exercises",
                    symbolName: "mic.fill",
                    gradient: [
                        accent.opacity(0.96),
                        Color(hex: "EA580C").opacity(0.74),
                        Color.white
                    ]
                )

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Why it matters")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        Text("Your voice is part of everyday function. Small, repeatable exercises can support clearer speech, steadier projection, and less strain over time.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            voiceChip("Strengthen")
                            voiceChip("Clarity")
                            voiceChip("Protect")
                        }
                    }
                }

                if let environmentNote = ActionVoiceTrainingService.captureEnvironmentNote {
                    FloatingSheetSection {
                        Label(environmentNote, systemImage: "info.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let errorMessage = service.errorMessage, !errorMessage.isEmpty {
                    FloatingSheetSection {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(
                            title: "Sustained voice analysis",
                            summary: "Hold a comfortable \"ah\" for a few seconds. Eir tracks pitch stability, average volume, and obvious voice breaks."
                        )

                        HStack(spacing: 12) {
                            liveMetric(title: "Pitch", value: service.currentFrequency > 0 ? "\(service.currentFrequency) Hz" : "--")
                            liveMetric(title: "Volume", value: "\(service.currentVolume)%")
                            liveMetric(title: "Note", value: service.currentNoteName)
                        }

                        HStack(spacing: 12) {
                            primaryActionButton(
                                title: isAnalysisActive ? "Stop & score" : "Start analysis",
                                systemImage: isAnalysisActive ? "stop.fill" : "play.fill",
                                fill: isAnalysisActive ? AppColors.red : accent
                            ) {
                                if isAnalysisActive {
                                    service.stopAnalysis()
                                } else {
                                    Task { await service.startAnalysis() }
                                }
                            }

                            secondaryPill("Live \(service.durationSeconds)s")
                        }

                        if let summary = service.lastAnalysisSummary {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    resultMetric(title: "Stability", value: "\(summary.stabilityScore)%", tint: accent)
                                    resultMetric(title: "Avg volume", value: "\(summary.averageVolume)%", tint: accent)
                                }

                                HStack(spacing: 10) {
                                    if let averagePitch = summary.averagePitch {
                                        resultMetric(title: "Avg pitch", value: "\(averagePitch) Hz", tint: accent)
                                    }
                                    resultMetric(title: "Voice breaks", value: "\(summary.voiceBreaks)", tint: accent)
                                }

                                Text(analysisReflection(for: summary))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(
                            title: "Pitch matching",
                            summary: "Play a note, then sing it back. This is the simplest way to build pitch awareness and vocal control."
                        )

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(ActionVoiceLibrary.targetNotes, id: \.self) { note in
                                Button(note) {
                                    selectedTargetNote = note
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selectedTargetNote == note ? Color.white : AppColors.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedTargetNote == note ? accent : Color.white)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedTargetNote == note ? accent : AppColors.border, lineWidth: 1)
                                )
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 12) {
                            secondaryActionButton(title: "Play target", systemImage: "speaker.wave.2.fill") {
                                service.playTargetNote(selectedTargetNote)
                            }

                            primaryActionButton(
                                title: isPitchActive ? "Stop matching" : "Start matching",
                                systemImage: isPitchActive ? "stop.fill" : "mic.fill",
                                fill: isPitchActive ? AppColors.red : accent
                            ) {
                                if isPitchActive {
                                    service.stopPitchMatch()
                                } else {
                                    Task { await service.startPitchMatch(targetNote: selectedTargetNote) }
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            liveMetric(title: "Live pitch", value: service.currentFrequency > 0 ? "\(service.currentFrequency) Hz" : "--")
                            liveMetric(title: "Current note", value: service.currentNoteName)
                        }

                        if let summary = service.lastPitchMatchSummary {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    resultMetric(title: "Target", value: summary.targetNote, tint: accent)
                                    resultMetric(title: "Accuracy", value: "\(summary.accuracyPercent)%", tint: accent)
                                }
                                Text(pitchReflection(for: summary))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader(
                            title: "Reading and articulation",
                            summary: "Read the passage aloud at a natural pace. Eir tracks duration, speaking pace, and average vocal steadiness."
                        )

                        Text(ActionVoiceLibrary.readingPassage)
                            .font(.body)
                            .foregroundStyle(AppColors.text)
                            .lineSpacing(6)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.backgroundMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                        HStack(spacing: 12) {
                            primaryActionButton(
                                title: isReadingActive ? "Stop reading" : "Start reading",
                                systemImage: isReadingActive ? "stop.fill" : "play.fill",
                                fill: isReadingActive ? AppColors.red : accent
                            ) {
                                if isReadingActive {
                                    service.stopReadingPractice()
                                } else {
                                    Task { await service.startReadingPractice() }
                                }
                            }

                            secondaryPill("\(service.durationSeconds)s")
                        }

                        if isReadingActive {
                            HStack(spacing: 12) {
                                liveMetric(title: "Live note", value: service.currentNoteName)
                                liveMetric(title: "Volume", value: "\(service.currentVolume)%")
                            }
                        }

                        if let summary = service.lastReadingSummary {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    resultMetric(title: "Time", value: "\(summary.durationSeconds)s", tint: accent)
                                    resultMetric(title: "Words/min", value: "\(summary.wordsPerMinute)", tint: accent)
                                    resultMetric(title: "Avg volume", value: "\(summary.averageVolume)%", tint: accent)
                                }
                                Text(readingReflection(for: summary))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionHeader(
                            title: "Guided voice exercises",
                            summary: "Short practices for warming up, easing strain, and building steady support."
                        )

                        ForEach(ActionVoiceLibrary.guidedExercises) { exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(exercise.category.uppercased())
                                        .font(.caption.weight(.bold))
                                        .tracking(1)
                                        .foregroundStyle(accent)
                                    Spacer()
                                    Text(exercise.durationLabel)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Text(exercise.title)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.text)

                                Text(exercise.summary)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(exercise.howTo)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.backgroundMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(voiceBackground.ignoresSafeArea())
        .navigationTitle("Voice Lab")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            service.stopAnalysis()
            service.stopPitchMatch()
            service.stopReadingPractice()
            service.stopTonePlayback()
        }
    }

    private var isAnalysisActive: Bool {
        if case .analysis? = service.mode {
            return service.isCapturing
        }
        return false
    }

    private var isPitchActive: Bool {
        if case .pitchMatch? = service.mode {
            return service.isCapturing
        }
        return false
    }

    private var isReadingActive: Bool {
        if case .reading? = service.mode {
            return service.isCapturing
        }
        return false
    }

    private var voiceBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    accent.opacity(0.12),
                    Color.white.opacity(0.92),
                    Color(hex: "FFF7ED")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func sectionHeader(title: String, summary: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Text(summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func liveMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func resultMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func voiceChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(accent.opacity(0.12))
            .clipShape(Capsule())
    }

    private func secondaryPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.backgroundMuted)
            .clipShape(Capsule())
    }

    private func primaryActionButton(title: String, systemImage: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func secondaryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func analysisReflection(for summary: ActionVoiceAnalysisSummary) -> String {
        if summary.stabilityScore > 80 {
            return "Strong stability. Your pitch stayed fairly even through the sample, which usually means the voice was well-supported and not working too hard."
        }
        if summary.stabilityScore > 50 {
            return "Moderate stability. Try a softer onset, smaller volume, and one minute of straw phonation before repeating the exercise."
        }
        return "Low stability. That often shows up when the voice is tired, pressed, or under-supported. Keep the next rep shorter and gentler."
    }

    private func pitchReflection(for summary: ActionVoicePitchMatchSummary) -> String {
        if summary.accuracyPercent > 70 {
            return "You were close to the target most of the time. Move up or down one note and repeat to widen control."
        }
        if summary.accuracyPercent > 40 {
            return "You are finding the note part of the time. Play the target again, sing more softly, and aim for steadiness over loudness."
        }
        return "The target note was hard to settle into. Start from a comfortable hum and slide slowly toward the note before trying again."
    }

    private func readingReflection(for summary: ActionVoiceReadingSummary) -> String {
        if summary.wordsPerMinute >= 150, summary.wordsPerMinute <= 180 {
            return "That pace is in a clear conversational range. Keep the same tempo and focus on cleaner consonants."
        }
        if summary.wordsPerMinute < 150 {
            return "You read on the slower side. That can be useful for precision, but try slightly more flow if you want a more natural speaking pace."
        }
        return "You read quickly. If clarity drops, back off the pace a little and let phrase endings land fully."
    }
}

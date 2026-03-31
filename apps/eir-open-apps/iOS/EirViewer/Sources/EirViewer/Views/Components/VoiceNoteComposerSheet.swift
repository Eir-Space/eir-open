import SwiftUI

struct VoiceNoteComposerSheet: View {
    let title: String
    let onSubmit: (RecordedVoiceNoteDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var recordedDraft: RecordedVoiceNoteDraft?

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(AppColors.auraSubtle)
                        .frame(width: 180, height: 180)

                    if let draft = recordedDraft {
                        WaveformCapsule(values: draft.waveform, accent: AppColors.aiStrong, isAnimated: false)
                            .frame(width: 120, height: 72)
                    } else {
                        WaveformCapsule(values: recorder.liveWaveform, accent: AppColors.aiStrong, isAnimated: recorder.isRecording)
                            .frame(width: 120, height: 72)
                    }
                }

                Text(formattedDuration)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(AppColors.text)
                    .monospacedDigit()

                if let errorMessage = recorder.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(AppColors.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 18) {
                    Button {
                        discardDraftIfNeeded()
                        recorder.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 50, height: 50)
                            .background(AppColors.backgroundMuted)
                            .clipShape(Circle())
                    }

                    if recorder.isRecording {
                        Button {
                            recordedDraft = recorder.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 82, height: 82)
                                .background(AppColors.aiStrong)
                                .clipShape(Circle())
                        }
                    } else if let recordedDraft {
                        Button {
                            onSubmit(recordedDraft)
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 82, height: 82)
                                .background(AppColors.primaryStrong)
                                .clipShape(Circle())
                        }

                        Button {
                            discardDraftIfNeeded()
                            recorder.cancel()
                            Task {
                                try? await recorder.start()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.headline.weight(.bold))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 50, height: 50)
                                .background(AppColors.backgroundMuted)
                                .clipShape(Circle())
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(AppColors.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") {
                        discardDraftIfNeeded()
                        recorder.cancel()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .task {
            guard !recorder.isRecording, recordedDraft == nil else { return }
            try? await recorder.start()
        }
    }

    private var formattedDuration: String {
        let totalSeconds = Int((recordedDraft?.duration ?? recorder.duration).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func discardDraftIfNeeded() {
        if let recordedDraft {
            try? FileManager.default.removeItem(at: recordedDraft.fileURL)
            self.recordedDraft = nil
        }
    }
}

struct WaveformCapsule: View {
    let values: [Double]
    let accent: Color
    let isAnimated: Bool

    @State private var phase = 0.0

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(indexedColor(index))
                    .frame(width: 4, height: barHeight(for: value, index: index))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard isAnimated else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func barHeight(for value: Double, index: Int) -> CGFloat {
        let base = max(10, min(54, value * 54))
        guard isAnimated else { return base }
        let ripple = sin((phase + Double(index) * 0.18) * .pi) * 4
        return max(10, base + ripple)
    }

    private func indexedColor(_ index: Int) -> Color {
        index.isMultiple(of: 4) ? accent.opacity(0.55) : accent
    }
}

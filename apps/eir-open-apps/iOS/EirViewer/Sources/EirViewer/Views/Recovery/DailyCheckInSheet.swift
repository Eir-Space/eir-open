import SwiftUI

struct DailyCheckInSheet: View {
    let profileID: UUID
    let existingCheckIn: DailyCheckIn?
    let onSave: (DailyCheckIn) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sleepRating: Int
    @State private var stressRating: Int
    @State private var energyRating: Int
    @State private var selectedSymptoms: Set<DailyCheckInSymptom>
    @State private var notes: String

    init(
        profileID: UUID,
        existingCheckIn: DailyCheckIn? = nil,
        onSave: @escaping (DailyCheckIn) -> Void
    ) {
        self.profileID = profileID
        self.existingCheckIn = existingCheckIn
        self.onSave = onSave
        _sleepRating = State(initialValue: existingCheckIn?.sleepRating ?? 3)
        _stressRating = State(initialValue: existingCheckIn?.stressRating ?? 3)
        _energyRating = State(initialValue: existingCheckIn?.energyRating ?? 3)
        _selectedSymptoms = State(initialValue: Set(existingCheckIn?.symptoms ?? []))
        _notes = State(initialValue: existingCheckIn?.freeText ?? "")
    }

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    RatingSection(
                        title: "How did you sleep?",
                        subtitle: "A rough self-rating is enough.",
                        selection: $sleepRating,
                        labels: ["Very poor", "Poor", "Mixed", "Good", "Great"]
                    )

                    RatingSection(
                        title: "How stressed do you feel right now?",
                        subtitle: "This should reflect your body today, not your whole week.",
                        selection: $stressRating,
                        labels: ["Very low", "Low", "Medium", "High", "Very high"]
                    )

                    RatingSection(
                        title: "How is your energy?",
                        subtitle: "Pick the one that feels most true right now.",
                        selection: $energyRating,
                        labels: ["Very low", "Low", "Okay", "Good", "High"]
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Any symptoms today?")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        Text("Choose any that feel relevant. Skip if nothing stands out.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(DailyCheckInSymptom.allCases) { symptom in
                                Button {
                                    if selectedSymptoms.contains(symptom) {
                                        selectedSymptoms.remove(symptom)
                                    } else {
                                        selectedSymptoms.insert(symptom)
                                    }
                                } label: {
                                    Text(symptom.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedSymptoms.contains(symptom) ? .white : AppColors.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                        .background(selectedSymptoms.contains(symptom) ? AppColors.primary : AppColors.backgroundMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Anything else?")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        Text("Optional. A short line is enough.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)

                        TextEditor(text: $notes)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(14)
                            .background(AppColors.backgroundMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle(existingCheckIn == nil ? "Daily Check-In" : "Update Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            DailyCheckIn(
                                id: existingCheckIn?.id ?? UUID(),
                                profileID: profileID,
                                createdAt: existingCheckIn?.createdAt ?? Date(),
                                sleepRating: sleepRating,
                                stressRating: stressRating,
                                energyRating: energyRating,
                                symptoms: DailyCheckInSymptom.allCases.filter { selectedSymptoms.contains($0) },
                                freeText: notes,
                                voiceNoteAttachmentID: existingCheckIn?.voiceNoteAttachmentID,
                                adaptivePromptID: existingCheckIn?.adaptivePromptID ?? .defaultSymptoms
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Give Eir a quick read on today.")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.text)

            Text("This check-in sharpens the next action and helps Eir learn what actually improves your day.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

private struct RatingSection: View {
    let title: String
    let subtitle: String
    @Binding var selection: Int
    let labels: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.text)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 10) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    let value = index + 1
                    Button {
                        selection = value
                    } label: {
                        VStack(spacing: 8) {
                            Text("\(value)")
                                .font(.headline.weight(.bold))
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .foregroundStyle(selection == value ? .white : AppColors.text)
                        .frame(maxWidth: .infinity, minHeight: 78)
                        .padding(.horizontal, 8)
                        .background(selection == value ? AppColors.primaryStrong : AppColors.backgroundMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

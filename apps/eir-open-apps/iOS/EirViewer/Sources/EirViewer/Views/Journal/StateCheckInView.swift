import SwiftUI

enum StateDimensionGroup: String, CaseIterable, Identifiable {
    case body = "Body"
    case mind = "Mind"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .body:
            return "Body"
        case .mind:
            return "Mind"
        }
    }

    var summary: String {
        switch self {
        case .body:
            return "Physical fuel, comfort, and body load."
        case .mind:
            return "Mood, clarity, and drive."
        }
    }
}

struct StateCheckInView: View {
    @EnvironmentObject private var actionsVM: ActionsViewModel
    @EnvironmentObject private var documentVM: DocumentViewModel
    @EnvironmentObject private var nextBestActionVM: NextBestHealthActionViewModel
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var stateActionVM: StateActionRecommendationViewModel

    @ObservedObject var store: StateCheckInStore

    @State private var draft = StateSnapshotDraft()
    @State private var note = ""
    @State private var justSavedID: UUID?
    @State private var isGuideExpanded = false
    @State private var lastSavedFingerprint: String?
    @State private var showSaveCelebration = false
    @State private var saveAnimationToken = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overviewHero

                if !store.records.isEmpty {
                    recentStatesSection
                }

                adaptiveActionSection
                interpretationGuideSection
                wheelStudioSection
                noteSection
                reflectionSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(stateBackground.ignoresSafeArea())
        .navigationTitle("State")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .top) {
            if showSaveCelebration {
                saveCelebrationBanner
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
            }
        }
        .sensoryFeedback(.success, trigger: saveAnimationToken)
        .onAppear {
            store.load(for: profileStore.selectedProfileID)
            loadDraftFromLatest()
            syncAdaptiveRecommendation()
        }
        .onChange(of: profileStore.selectedProfileID) {
            store.load(for: profileStore.selectedProfileID)
            loadDraftFromLatest()
            syncAdaptiveRecommendation()
        }
        .onChange(of: draft) {
            syncAdaptiveRecommendation()
        }
        .onChange(of: note) {
            syncAdaptiveRecommendation()
        }
        .onChange(of: store.records.count) {
            syncAdaptiveRecommendation()
        }
    }

    private var overviewHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Tune into right now.")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)

            Text("Use the wheels the same way you would use a timer. Scroll each one until the current state feels right, then save the moment into your journal.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                heroMetric(
                    value: overallDescriptor.title,
                    label: "Current feel",
                    tint: overallDescriptor.tint
                )
                heroMetric(
                    value: latestTimestampLabel,
                    label: "Latest",
                    tint: Color(hex: "7C3AED")
                )
                heroMetric(
                    value: profileStore.selectedProfile?.displayName ?? "Profile",
                    label: "Active",
                    tint: Color(hex: "C2410C")
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "FFFBEB"),
                        Color(hex: "F0FDFA"),
                        Color.white
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color(hex: "99F6E4").opacity(0.4))
                    .frame(width: 200, height: 200)
                    .offset(x: 136, y: -56)

                Circle()
                    .fill(Color(hex: "FDE68A").opacity(0.35))
                    .frame(width: 180, height: 180)
                    .offset(x: -124, y: 92)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        )
    }

    private func heroMetric(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var recentStatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent states")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text("Tap a saved snapshot to restore those wheels.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text("\(min(store.records.count, 5)) shown")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(store.records.prefix(5))) { record in
                        Button {
                            loadDraft(from: record)
                        } label: {
                            RecentStateCard(
                                record: record,
                                isHighlighted: justSavedID == record.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var wheelStudioSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("State studio")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text("Scroll each wheel until the center state feels true.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text(overallDescriptor.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(overallDescriptor.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(overallDescriptor.tint.opacity(0.12))
                    .clipShape(Capsule())
            }

            groupSection(.body)
            groupSection(.mind)

            HStack(spacing: 12) {
                Button {
                    resetDraft()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.white.opacity(0.88))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    saveSnapshot()
                } label: {
                    Label(saveButtonTitle, systemImage: saveButtonSystemImage)
                        .font(.headline)
                        .foregroundStyle(canSaveCurrentState ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            canSaveCurrentState
                            ? Color(hex: "0F766E")
                            : Color.white.opacity(0.92)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    canSaveCurrentState ? Color.clear : AppColors.border,
                                    lineWidth: 1
                                )
                        )
                        .symbolEffect(.bounce, value: saveAnimationToken)
                }
                .buttonStyle(.plain)
                .disabled(!canSaveCurrentState)
                .opacity(canSaveCurrentState ? 1 : 0.82)
            }

            if !canSaveCurrentState {
                Label("This state is already saved. Change a wheel or note to save a new snapshot.", systemImage: "checkmark.seal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(22)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var adaptiveActionSection: some View {
        if let recommendation = stateActionVM.recommendation,
           let action = recommendedAction {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best next action")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColors.text)
                        Text("Chosen on-device from your current state and past follow-ups.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(stateActionVM.summary.learningLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: "0F766E"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: "0F766E").opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(action.category.softTint)
                                .frame(width: 56, height: 56)

                            Image(systemName: action.category.systemImage)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(action.category.tint)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(recommendation.headline)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(AppColors.text)
                            Text(recommendation.summary)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recommendation.whyItFits, id: \.self) { item in
                            Label(item, systemImage: "sparkles")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    HStack(spacing: 8) {
                        recommendationChip("\(Int(recommendation.confidence * 100))% confidence")
                        recommendationChip(stateActionVM.summary.statusLine)
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(action.category.tint.opacity(0.16), lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Button {
                        NotificationCenter.default.post(name: .navigateToAction, object: nil)
                    } label: {
                        Label("Open Action", systemImage: "arrow.right.circle")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.white.opacity(0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        completeRecommendedAction(action)
                    } label: {
                        Label(
                            actionsVM.isCompletedToday(action) ? "Done today" : "I did this",
                            systemImage: actionsVM.isCompletedToday(action) ? "checkmark.seal.fill" : "checkmark.circle.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(actionsVM.isCompletedToday(action) ? AppColors.textSecondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(actionsVM.isCompletedToday(action) ? Color.white.opacity(0.88) : action.category.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(actionsVM.isCompletedToday(action) ? AppColors.border : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(actionsVM.isCompletedToday(action))
                    .opacity(actionsVM.isCompletedToday(action) ? 0.82 : 1)
                }
            }
            .padding(22)
            .background(Color.white.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
        }
    }

    private func recommendationChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(hex: "F8FAFC"))
            .clipShape(Capsule())
    }

    private var interpretationGuideSection: some View {
        DisclosureGroup(isExpanded: $isGuideExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Use these as orientation cues, not as diagnosis. Neurotransmitters and body patterns are simplified here to help the user notice tendencies, not to explain the whole biology.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(StateDimensionDefinition.catalog) { dimension in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(dimension.color)
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(dimension.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppColors.text)
                                Text(dimension.detail)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            guideRow(title: "0-3", text: dimension.lowRangeDescription)
                            guideRow(title: "4-6", text: dimension.midRangeDescription)
                            guideRow(title: "7-10", text: dimension.highRangeDescription)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            guideTagBlock(
                                title: "Often linked with",
                                items: dimension.relatedSystems
                            )
                            guideTagBlock(
                                title: "Body signs",
                                items: dimension.bodySignals
                            )
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.86))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(dimension.color.opacity(0.16), lineWidth: 1)
                    )
                }
            }
            .padding(.top, 14)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.headline)
                    .foregroundStyle(Color(hex: "0F766E"))

                VStack(alignment: .leading, spacing: 4) {
                    Text("How to read the wheels")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text("Descriptions for low, middle, and high states, plus simplified biology cues.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(AppColors.text)
        .padding(22)
        .background(Color.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
    }

    private func guideRow(title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: 38, alignment: .leading)

            Text(text)
                .font(.caption)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func guideTagBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupSection(_ group: StateDimensionGroup) -> some View {
        let dimensions = StateDimensionDefinition.catalog.filter { $0.group == group }

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text(group.summary)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(alignment: .top, spacing: 12) {
                ForEach(dimensions) { dimension in
                    StateDimensionWheel(
                        dimension: dimension,
                        value: wheelBinding(for: dimension)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(18)
        .background(groupBackground(for: group))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
        )
    }

    private func groupBackground(for group: StateDimensionGroup) -> LinearGradient {
        switch group {
        case .body:
            return LinearGradient(
                colors: [Color(hex: "FFF7ED"), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mind:
            return LinearGradient(
                colors: [Color(hex: "EEF2FF"), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional note")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            TextField("What is shaping this state right now?", text: $note, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(AppColors.text)
                .padding(16)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .lineLimit(2 ... 4)
        }
    }

    private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Reflection")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            Text(StateInsightGenerator.describe(draft: draft, note: note))
                .font(.subheadline)
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(StateInsightGenerator.highlights(for: draft), id: \.self) { item in
                    Text(item)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "F8FAFC"),
                    Color(hex: "EFF6FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.86), lineWidth: 1)
        )
    }

    private var latestTimestampLabel: String {
        guard let latest = store.records.first else { return "None yet" }
        return latest.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var recommendationStateRecord: StateCheckInRecord {
        StateCheckInRecord(
            id: justSavedID ?? UUID(),
            createdAt: store.records.first?.createdAt ?? Date(),
            scores: draft.scores,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            reflection: StateInsightGenerator.describe(draft: draft, note: note)
        )
    }

    private var recommendedAction: HealthAction? {
        guard let actionID = stateActionVM.recommendation?.actionID else { return nil }
        return actionsVM.actions.first(where: { $0.id == actionID })
    }

    private var currentFingerprint: String {
        snapshotFingerprint(scores: draft.scores, note: note)
    }

    private var canSaveCurrentState: Bool {
        guard profileStore.selectedProfileID != nil else { return false }
        return currentFingerprint != lastSavedFingerprint
    }

    private var saveButtonTitle: String {
        canSaveCurrentState ? "Save state" : "Saved"
    }

    private var saveButtonSystemImage: String {
        canSaveCurrentState ? "checkmark.circle.fill" : "checkmark.seal.fill"
    }

    private var overallDescriptor: StateOverallDescriptor {
        StateInsightGenerator.overallDescriptor(for: draft)
    }

    private var saveCelebrationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color(hex: "0F766E"))

            VStack(alignment: .leading, spacing: 2) {
                Text("State saved")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text("Your latest snapshot is now part of the journal.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }

    private var stateBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    Color(hex: "FFFBEB").opacity(0.84),
                    Color(hex: "F8FAFC"),
                    Color(hex: "EEF2FF").opacity(0.74)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "FDE68A").opacity(0.24))
                .frame(width: 320, height: 320)
                .blur(radius: 24)
                .offset(x: -150, y: -250)

            Circle()
                .fill(Color(hex: "BFDBFE").opacity(0.26))
                .frame(width: 340, height: 340)
                .blur(radius: 24)
                .offset(x: 150, y: 260)
        }
    }

    private func wheelBinding(for dimension: StateDimensionDefinition) -> Binding<Int> {
        Binding(
            get: { Int(round(draft.score(for: dimension.id) * 10)) },
            set: { newValue in
                draft.setScore(Double(newValue) / 10.0, for: dimension.id)
            }
        )
    }

    private func resetDraft() {
        draft = StateSnapshotDraft.neutral
        note = ""
        justSavedID = nil
        syncAdaptiveRecommendation()
    }

    private func loadDraftFromLatest() {
        guard let latest = store.records.first else {
            lastSavedFingerprint = nil
            resetDraft()
            return
        }
        lastSavedFingerprint = snapshotFingerprint(record: latest)
        loadDraft(from: latest)
    }

    private func loadDraft(from record: StateCheckInRecord) {
        draft = StateSnapshotDraft(scores: record.scores)
        note = record.note
        justSavedID = record.id
        syncAdaptiveRecommendation()
    }

    private func saveSnapshot() {
        guard canSaveCurrentState else { return }
        guard let record = store.save(draft: draft, note: note) else { return }
        justSavedID = record.id
        lastSavedFingerprint = snapshotFingerprint(record: record)
        saveAnimationToken += 1
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            showSaveCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                showSaveCelebration = false
            }
        }
        loadDraft(from: record)
        syncAdaptiveRecommendation()
    }

    private func syncAdaptiveRecommendation() {
        actionsVM.sync(profileID: profileStore.selectedProfileID, document: documentVM.document)
        stateActionVM.sync(
            profileID: profileStore.selectedProfileID,
            actions: actionsVM.actions,
            state: recommendationStateRecord
        )
    }

    private func completeRecommendedAction(_ action: HealthAction) {
        guard !actionsVM.isCompletedToday(action) else { return }

        actionsVM.toggleCompletedToday(action)
        Task {
            await nextBestActionVM.saveOutcome(
                RecoveryActionOutcome(actionID: action.id, completed: true),
                document: documentVM.document,
                actions: actionsVM.actions
            )
        }
        syncAdaptiveRecommendation()
    }

    private func snapshotFingerprint(scores: [String: Double], note: String) -> String {
        let scorePart = StateDimensionDefinition.catalog
            .map { dimension in
                let value = scores[dimension.id] ?? 0.5
                return "\(dimension.id)=\(Int(round(value * 10)))"
            }
            .joined(separator: "|")

        let normalizedNote = note
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")

        return "\(scorePart)|note=\(normalizedNote)"
    }

    private func snapshotFingerprint(record: StateCheckInRecord) -> String {
        snapshotFingerprint(scores: record.scores, note: record.note)
    }
}

private struct StateDimensionWheel: View {
    let dimension: StateDimensionDefinition
    @Binding var value: Int

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(dimension.shortTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(dimension.color)

                Text(dimension.descriptor(for: Double(value) / 10))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 38)
            }

            Picker(dimension.title, selection: $value) {
                ForEach(0 ... 10, id: \.self) { level in
                    Text("\(level)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .tag(level)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
            .sensoryFeedback(.selection, trigger: value)

            Text("\(dimension.lowLabel) -> \(dimension.highLabel)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(dimension.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(dimension.color.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RecentStateCard: View {
    let record: StateCheckInRecord
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(StateInsightGenerator.overallDescriptor(for: record).title)
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                }

                Spacer()

                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isHighlighted ? Color(hex: "0F766E") : AppColors.textSecondary)
            }

            Text(record.reflection)
                .font(.subheadline)
                .foregroundStyle(AppColors.text)
                .lineLimit(3)

            HStack(spacing: 8) {
                ForEach(Array(record.topHighlights.prefix(2)), id: \.self) { item in
                    Text(item)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .frame(width: 260, alignment: .leading)
        .background(Color.white.opacity(isHighlighted ? 0.96 : 0.84))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighlighted ? Color(hex: "0F766E").opacity(0.28) : AppColors.border, lineWidth: 1)
        )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

struct StateCheckInRecord: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let scores: [String: Double]
    let note: String
    let reflection: String

    func score(for dimensionID: String) -> Double {
        scores[dimensionID] ?? 0.5
    }

    var topHighlights: [String] {
        StateDimensionDefinition.catalog
            .map { dimension -> (String, Double) in
                let score = score(for: dimension.id)
                let adjusted = dimension.highIsPositive ? score : (1 - score)
                return (dimension.shortTitle.lowercased(), adjusted)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map(\.0)
    }
}

struct StateSnapshotDraft: Equatable {
    var scores: [String: Double]

    init(scores: [String: Double] = StateDimensionDefinition.catalog.reduce(into: [:]) { partial, dimension in
        partial[dimension.id] = 0.5
    }) {
        self.scores = scores
    }

    static let neutral = StateSnapshotDraft()

    func score(for dimensionID: String) -> Double {
        scores[dimensionID] ?? 0.5
    }

    mutating func setScore(_ score: Double, for dimensionID: String) {
        scores[dimensionID] = max(0, min(1, score))
    }
}

struct StateDimensionDefinition: Identifiable {
    let id: String
    let group: StateDimensionGroup
    let title: String
    let shortTitle: String
    let angleDegrees: Double
    let color: Color
    let lowLabel: String
    let highLabel: String
    let detail: String
    let highIsPositive: Bool
    let lowRangeDescription: String
    let midRangeDescription: String
    let highRangeDescription: String
    let relatedSystems: [String]
    let bodySignals: [String]

    var angleRadians: Double {
        angleDegrees * .pi / 180
    }

    var unitVector: CGVector {
        CGVector(dx: cos(angleRadians), dy: sin(angleRadians))
    }

    func descriptor(for score: Double) -> String {
        switch score {
        case ..<0.2:
            return lowLabel.capitalized
        case ..<0.4:
            return "Low \(title.lowercased())"
        case ..<0.6:
            return "Balanced"
        case ..<0.8:
            return "Strong \(title.lowercased())"
        default:
            return highLabel.capitalized
        }
    }

    static let catalog: [StateDimensionDefinition] = [
        StateDimensionDefinition(
            id: "physical_energy",
            group: .body,
            title: "Physical energy",
            shortTitle: "Physical",
            angleDegrees: -90,
            color: Color(hex: "EA580C"),
            lowLabel: "depleted",
            highLabel: "charged",
            detail: "How much physical fuel feels available in your body right now.",
            highIsPositive: true,
            lowRangeDescription: "The body may feel heavy, underpowered, slow to start, or effortful to move.",
            midRangeDescription: "Enough fuel for basic tasks, but pacing still matters and reserve feels limited.",
            highRangeDescription: "The body feels fueled, mobile, and more willing to initiate effort.",
            relatedSystems: ["dopamine", "orexin", "circadian rhythm"],
            bodySignals: ["heaviness", "slower movement", "yawning", "wanting rest"]
        ),
        StateDimensionDefinition(
            id: "mental_energy",
            group: .mind,
            title: "Mental energy",
            shortTitle: "Mental",
            angleDegrees: -30,
            color: Color(hex: "4F46E5"),
            lowLabel: "foggy",
            highLabel: "engaged",
            detail: "How ready your mind feels for thinking, deciding, and staying with a task.",
            highIsPositive: true,
            lowRangeDescription: "Thinking may feel slow, scattered, or hard to hold onto for long.",
            midRangeDescription: "You can think and respond, but sustained focus may still drift.",
            highRangeDescription: "The mind feels awake, connected, and easier to direct on purpose.",
            relatedSystems: ["acetylcholine", "dopamine", "sleep pressure"],
            bodySignals: ["brain fog", "slowed recall", "easier distraction", "mental fatigue"]
        ),
        StateDimensionDefinition(
            id: "mood",
            group: .mind,
            title: "Mood",
            shortTitle: "Mood",
            angleDegrees: 30,
            color: Color(hex: "059669"),
            lowLabel: "heavy",
            highLabel: "lifted",
            detail: "The emotional tone of the moment, from compressed to more open and steady.",
            highIsPositive: true,
            lowRangeDescription: "The emotional tone may feel tight, flat, low, or harder to carry lightly.",
            midRangeDescription: "Emotionally mixed or neutral, with some steadiness but not much lift.",
            highRangeDescription: "Mood feels lighter, warmer, or more open to connection and movement.",
            relatedSystems: ["serotonin", "dopamine", "social safety"],
            bodySignals: ["facial tension", "tearfulness", "withdrawal", "easier smiling"]
        ),
        StateDimensionDefinition(
            id: "motivation",
            group: .mind,
            title: "Motivation",
            shortTitle: "Drive",
            angleDegrees: 90,
            color: Color(hex: "0F766E"),
            lowLabel: "flat",
            highLabel: "ready",
            detail: "How much momentum you feel to start, continue, or finish something useful.",
            highIsPositive: true,
            lowRangeDescription: "Starting feels hard, effort feels costly, and even simple actions may feel far away.",
            midRangeDescription: "You can get going with structure, but the engine does not run on its own yet.",
            highRangeDescription: "There is a noticeable pull toward doing, finishing, or moving forward.",
            relatedSystems: ["dopamine", "reward expectation", "goal salience"],
            bodySignals: ["procrastination", "stalling", "task avoidance", "urge to begin"]
        ),
        StateDimensionDefinition(
            id: "body_comfort",
            group: .body,
            title: "Body comfort",
            shortTitle: "Body",
            angleDegrees: 150,
            color: Color(hex: "DB2777"),
            lowLabel: "tight",
            highLabel: "settled",
            detail: "How comfortable, grounded, and physically at ease your body feels.",
            highIsPositive: true,
            lowRangeDescription: "The body may feel tense, achy, braced, restless, or difficult to inhabit.",
            midRangeDescription: "Some parts feel okay while others still hold tension or irritation.",
            highRangeDescription: "The body feels more settled, grounded, and less demanding of attention.",
            relatedSystems: ["parasympathetic tone", "muscle tension", "pain load"],
            bodySignals: ["jaw tension", "shoulder tightness", "aches", "easier breathing"]
        ),
        StateDimensionDefinition(
            id: "stress_load",
            group: .body,
            title: "Stress load",
            shortTitle: "Stress",
            angleDegrees: 210,
            color: Color(hex: "7C3AED"),
            lowLabel: "calm",
            highLabel: "maxed",
            detail: "How much internal pressure, urgency, or overload you are carrying.",
            highIsPositive: false,
            lowRangeDescription: "The system feels relatively calm, with more room between stimulus and reaction.",
            midRangeDescription: "Some pressure is present, but it still feels workable and containable.",
            highRangeDescription: "The system feels activated, overloaded, or primed for urgency and threat scanning.",
            relatedSystems: ["cortisol", "adrenaline", "sympathetic activation"],
            bodySignals: ["fast thoughts", "shallow breathing", "clenched body", "urge to rush"]
        )
    ]
}

struct StateOverallDescriptor {
    let title: String
    let tint: Color
}

final class StateCheckInStore: ObservableObject {
    @Published private(set) var records: [StateCheckInRecord] = []

    private var activeProfileID: UUID?

    func load(for profileID: UUID?) {
        activeProfileID = profileID
        guard let profileID else {
            records = []
            return
        }

        records = (EncryptedStore.load([StateCheckInRecord].self, forKey: storageKey(for: profileID)) ?? [])
            .sorted { $0.createdAt > $1.createdAt }
    }

    func save(draft: StateSnapshotDraft, note: String) -> StateCheckInRecord? {
        guard let profileID = activeProfileID else { return nil }

        let record = StateCheckInRecord(
            id: UUID(),
            createdAt: Date(),
            scores: draft.scores,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            reflection: StateInsightGenerator.describe(draft: draft, note: note)
        )

        records.insert(record, at: 0)
        EncryptedStore.save(records, forKey: storageKey(for: profileID))
        StateActionLearningEngine.resolvePendingInterventions(profileID: profileID, with: record)
        load(for: profileID)
        return records.first(where: { $0.id == record.id }) ?? record
    }

    private func storageKey(for profileID: UUID) -> String {
        "state_check_in_history_\(profileID.uuidString)"
    }
}

private enum StateInsightGenerator {
    static func overallDescriptor(for draft: StateSnapshotDraft) -> StateOverallDescriptor {
        let score = balancedScore(for: draft)

        switch score {
        case ..<0.33:
            return StateOverallDescriptor(title: "Strained", tint: Color(hex: "B91C1C"))
        case ..<0.55:
            return StateOverallDescriptor(title: "Mixed", tint: Color(hex: "C2410C"))
        case ..<0.75:
            return StateOverallDescriptor(title: "Steady", tint: Color(hex: "0F766E"))
        default:
            return StateOverallDescriptor(title: "Open", tint: Color(hex: "047857"))
        }
    }

    static func overallDescriptor(for record: StateCheckInRecord) -> StateOverallDescriptor {
        overallDescriptor(for: StateSnapshotDraft(scores: record.scores))
    }

    static func describe(draft: StateSnapshotDraft, note: String) -> String {
        let physical = draft.score(for: "physical_energy")
        let mental = draft.score(for: "mental_energy")
        let mood = draft.score(for: "mood")
        let motivation = draft.score(for: "motivation")
        let comfort = draft.score(for: "body_comfort")
        let stress = draft.score(for: "stress_load")

        let opener: String
        if physical < 0.35 && mental < 0.4 {
            opener = "This snapshot leans depleted. Your physical and mental energy both look low, so today probably needs less volume and more protection around recovery."
        } else if stress > 0.72 && mood < 0.52 {
            opener = "Pressure is carrying a lot of the picture right now. The combination of higher stress load and a heavier mood suggests keeping plans tighter and simpler."
        } else if motivation > 0.62 && mental > 0.58 {
            opener = "There is usable momentum here. Your mental energy and motivation look available enough to support one meaningful task without forcing it."
        } else if comfort > 0.66 && mood > 0.6 {
            opener = "Your state looks relatively settled. The body and emotional tone both read more open, which is usually a good base for a steady day."
        } else {
            opener = "Your state looks mixed rather than one-note. A few parts of you are available, but not everything is moving in the same direction."
        }

        let brightest = topAvailableDimensions(for: draft)
        let anchorLine: String
        if brightest.isEmpty {
            anchorLine = "There is not a strong surplus area showing up, so the best move may be to reduce friction and aim for gentle wins."
        } else {
            anchorLine = "What still looks available: \(brightest.joined(separator: " and ")). Use that as the anchor instead of expecting the whole system to feel great."
        }

        let noteLine: String
        if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            noteLine = ""
        } else {
            noteLine = " You noted: \(note.trimmingCharacters(in: .whitespacesAndNewlines))."
        }

        return opener + " " + anchorLine + noteLine
    }

    static func highlights(for draft: StateSnapshotDraft) -> [String] {
        let topTwo = topAvailableDimensions(for: draft)
        let pressure = draft.score(for: "stress_load")
        var items = topTwo

        if pressure > 0.7 {
            items.append("high pressure")
        } else if pressure < 0.3 {
            items.append("low pressure")
        }

        return Array(items.prefix(3))
    }

    private static func balancedScore(for draft: StateSnapshotDraft) -> Double {
        let contributions = StateDimensionDefinition.catalog.map { dimension in
            let score = draft.score(for: dimension.id)
            return dimension.highIsPositive ? score : (1 - score)
        }
        return contributions.reduce(0, +) / Double(contributions.count)
    }

    private static func topAvailableDimensions(for draft: StateSnapshotDraft) -> [String] {
        StateDimensionDefinition.catalog
            .map { dimension -> (String, Double) in
                let score = draft.score(for: dimension.id)
                let adjusted = dimension.highIsPositive ? score : (1 - score)
                return (dimension.shortTitle.lowercased(), adjusted)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .filter { $0.1 > 0.55 }
            .map(\.0)
    }
}

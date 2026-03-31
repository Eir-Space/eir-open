import SwiftUI
import UIKit

struct ForYouView: View {
    @EnvironmentObject var actionsVM: ActionsViewModel
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var forYouVM: ForYouViewModel
    @EnvironmentObject var nextBestActionVM: NextBestHealthActionViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @EnvironmentObject var localModelManager: LocalModelManager

    @State private var selectedCard: ForYouCard?
    @State private var selectedCareSuggestion: CareSuggestion?
    @State private var showingCheckInSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let snapshot = nextBestActionVM.snapshot {
                    NextBestHealthActionCard(
                        snapshot: snapshot,
                        recommendedAction: recommendedAction,
                        latestCheckIn: nextBestActionVM.latestCheckIn,
                        isActionCompletedToday: recommendedAction.map(actionsVM.isCompletedToday) ?? false,
                        isCheckInDue: !nextBestActionVM.hasCheckInToday,
                        showConnectHealth: nextBestActionVM.measuredSignalCount == 0,
                        onStartCheckIn: {
                            showingCheckInSheet = true
                        },
                        onCompleteAction: {
                            completeRecommendedAction()
                        },
                        onTalkToEir: {
                            talkToEirAboutRecommendation(snapshot: snapshot)
                        },
                        onOpenCareOptions: {
                            openCareOptions(for: snapshot)
                        },
                        onConnectHealth: {
                            connectRecoverySignals()
                        }
                    )
                }

                LazyVStack(spacing: 16) {
                    ForEach(Array(forYouVM.cards.enumerated()), id: \.element.id) { index, card in
                        ForYouFeedCard(
                            card: card,
                            prominence: prominence(for: index),
                            isFavorite: forYouVM.isFavorite(card),
                            actionState: actionState(for: card)
                        )
                        .gesture(cardGesture(for: card))
                        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: forYouVM.favoriteIDs)
                    }

                    loadMoreSentinel
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(feedBackground.ignoresSafeArea())
        .navigationTitle("For You")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $selectedCareSuggestion) { careSuggestion in
            FindCareView(careSuggestion: careSuggestion)
        }
        .sheet(item: $selectedCard) { card in
            ForYouSheet(card: card)
                .environmentObject(actionsVM)
                .environmentObject(forYouVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingCheckInSheet) {
            if let profileID = profileStore.selectedProfileID {
                DailyCheckInSheet(
                    profileID: profileID,
                    existingCheckIn: nextBestActionVM.hasCheckInToday ? nextBestActionVM.latestCheckIn : nil
                ) { checkIn in
                    Task {
                        await nextBestActionVM.saveCheckIn(
                            checkIn,
                            document: documentVM.document,
                            actions: actionsVM.actions
                        )
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            syncFeed()
        }
        .alert(
            "Share Data with \(forYouVM.pendingCloudConsent?.displayName ?? "Cloud Provider")?",
            isPresented: Binding(
                get: { forYouVM.pendingCloudConsent != nil },
                set: { if !$0 { forYouVM.consentDenied() } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                forYouVM.consentDenied()
            }
            Button("I Agree") {
                Task {
                    await forYouVM.consentGrantedAndLoadMore(
                        settingsVM: settingsVM,
                        localModelManager: localModelManager
                    )
                }
            }
        } message: {
            Text("Your records will be sent to \(forYouVM.pendingCloudConsent?.displayName ?? "the selected provider") to generate more cards for For You. This data may include health information. On-device models keep everything on your phone.")
        }
        .onChange(of: profileStore.selectedProfileID) {
            syncFeed()
        }
        .onChange(of: documentSignature) {
            syncFeed()
        }
        .onChange(of: actionsSignature) {
            syncFeed()
        }
    }

    @ViewBuilder
    private var loadMoreSentinel: some View {
        if forYouVM.isLoadingMore {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(AppColors.text)
                Text("Bringing in five more")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else if let error = forYouVM.loadMoreError {
            Button {
                Task {
                    await forYouVM.retryLoadMore(
                        settingsVM: settingsVM,
                        localModelManager: localModelManager
                    )
                }
            } label: {
                VStack(spacing: 6) {
                    Text("Try again")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.text)
                    Text(error)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task {
                        await forYouVM.loadMoreIfNeeded(
                            settingsVM: settingsVM,
                            localModelManager: localModelManager
                        )
                    }
                }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(dayLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 10) {
                    feedMetric(value: "\(actionsVM.completedTodayCount)", label: "Done")
                    feedMetric(value: "\(actionsVM.scheduledActions.count)", label: "Later")
                }
            }

            Spacer()

            if let snapshot = nextBestActionVM.snapshot {
                Text(snapshot.state.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(stateChipTextColor(for: snapshot.state))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(stateChipFillColor(for: snapshot.state))
                    .clipShape(Capsule())
            }

            if !forYouVM.favoriteIDs.isEmpty {
                Label("\(forYouVM.favoriteIDs.count)", systemImage: "heart.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.78))
                    .clipShape(Capsule())
            }
        }
    }

    private var feedBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    Color(hex: "FFF4E8").opacity(0.55),
                    Color.clear,
                    Color(hex: "EEF2FF").opacity(0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: Date())
    }

    private var documentSignature: String {
        guard let document = documentVM.document else { return "none" }
        return "\(document.entries.count)-\(document.entries.first?.id ?? "none")"
    }

    private var actionsSignature: String {
        actionsVM.actions.map(\.id).joined(separator: "|")
    }

    private var recommendedAction: HealthAction? {
        guard let recommendedID = nextBestActionVM.snapshot?.recommendedActionID else { return nil }
        return actionsVM.actions.first(where: { $0.id == recommendedID })
    }

    private func syncFeed() {
        actionsVM.sync(profileID: profileStore.selectedProfileID, document: documentVM.document)
        forYouVM.sync(
            profileID: profileStore.selectedProfileID,
            document: documentVM.document,
            actions: actionsVM.actions
        )
        Task {
            await nextBestActionVM.sync(
                profileID: profileStore.selectedProfileID,
                document: documentVM.document,
                actions: actionsVM.actions
            )
        }
    }

    private func completeRecommendedAction() {
        guard let action = recommendedAction else { return }
        guard !actionsVM.isCompletedToday(action) else { return }

        actionsVM.toggleCompletedToday(action)

        Task {
            await nextBestActionVM.saveOutcome(
                RecoveryActionOutcome(actionID: action.id, completed: true),
                document: documentVM.document,
                actions: actionsVM.actions
            )
        }
    }

    private func talkToEirAboutRecommendation(snapshot: NextBestHealthActionSnapshot) {
        let driverSummary = snapshot.drivers
            .map(\.title)
            .joined(separator: "; ")

        let prompt = """
        Help me understand my next best health action today.

        State: \(snapshot.state.title)
        Headline: \(snapshot.headline)
        Drivers: \(driverSummary)
        """

        chatVM.inputText = prompt
        NotificationCenter.default.post(name: .navigateToChat, object: nil)
    }

    private func connectRecoverySignals() {
        Task {
            do {
                try await HealthKitService.shared.requestRecoveryAuthorization()
                await nextBestActionVM.sync(
                    profileID: profileStore.selectedProfileID,
                    document: documentVM.document,
                    actions: actionsVM.actions
                )
            } catch {
                nextBestActionVM.errorMessage = error.localizedDescription
            }
        }
    }

    private func openCareOptions(for snapshot: NextBestHealthActionSnapshot) {
        selectedCareSuggestion = snapshot.careSuggestion
    }

    private func stateChipFillColor(for state: NextBestHealthActionState) -> Color {
        switch state {
        case .recoverToday:
            return AppColors.primarySoft
        case .steadyToday:
            return AppColors.green.opacity(0.14)
        case .watchClosely:
            return AppColors.orange.opacity(0.14)
        }
    }

    private func stateChipTextColor(for state: NextBestHealthActionState) -> Color {
        switch state {
        case .recoverToday:
            return AppColors.primary
        case .steadyToday:
            return AppColors.green
        case .watchClosely:
            return AppColors.orange
        }
    }

    private func feedMetric(value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.78))
        .clipShape(Capsule())
    }

    private func cardGesture(for card: ForYouCard) -> some Gesture {
        ExclusiveGesture(TapGesture(count: 2), TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        forYouVM.toggleFavorite(card)
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                case .second:
                    selectedCard = card
                }
            }
    }

    private func prominence(for index: Int) -> ForYouCardProminence {
        if nextBestActionVM.snapshot != nil {
            if index < 3 { return .feature }
            return .compact
        }
        if index == 0 { return .hero }
        if index < 4 { return .feature }
        return .compact
    }

    private func actionState(for card: ForYouCard) -> ForYouActionCardState? {
        guard let action = card.action else { return nil }
        let state = actionsVM.state(for: action)
        return ForYouActionCardState(
            isCompletedToday: actionsVM.isCompletedToday(action),
            isScheduled: state.schedule != nil,
            statusLine: state.schedule.map(scheduleLine)
        )
    }

    private func scheduleLine(_ schedule: HealthActionSchedule) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = schedule.cadence == .once ? .medium : .none
        return "\(schedule.cadence.title) • \(formatter.string(from: schedule.date))"
    }
}

private struct ForYouActionCardState {
    let isCompletedToday: Bool
    let isScheduled: Bool
    let statusLine: String?
}

private enum ForYouCardProminence {
    case hero
    case feature
    case compact

    var minHeight: CGFloat {
        switch self {
        case .hero: return 330
        case .feature: return 270
        case .compact: return 220
        }
    }

    var titleFont: Font {
        switch self {
        case .hero: return .system(size: 31, weight: .bold, design: .rounded)
        case .feature: return .system(size: 25, weight: .bold, design: .rounded)
        case .compact: return .system(size: 21, weight: .bold, design: .rounded)
        }
    }

    var summaryLimit: Int {
        switch self {
        case .hero: return 3
        case .feature: return 3
        case .compact: return 2
        }
    }
}

private struct ForYouFeedCard: View {
    let card: ForYouCard
    let prominence: ForYouCardProminence
    let isFavorite: Bool
    let actionState: ForYouActionCardState?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cardBackground

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    Text(card.eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(card.theme.accent)

                    Spacer()

                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(card.theme.accent)
                            .padding(10)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text(card.title)
                        .font(prominence.titleFont)
                        .foregroundStyle(card.theme.textColor)
                        .multilineTextAlignment(.leading)

                    Text(card.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(card.theme.textColor.opacity(0.82))
                        .lineLimit(prominence.summaryLimit)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        metaChip(card.kind.label)
                        if let durationLabel = card.durationLabel {
                            metaChip(durationLabel)
                        }
                        if let actionState, actionState.isCompletedToday {
                            metaChip("Done")
                        } else if let actionState, actionState.isScheduled {
                            metaChip("Later")
                        }
                    }

                    if let actionState, let statusLine = actionState.statusLine, prominence != .compact {
                        Text(statusLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(card.theme.textColor.opacity(0.72))
                    }
                }
            }
            .padding(22)
        }
        .frame(minHeight: prominence.minHeight)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: card.theme.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(card.theme.accent.opacity(0.30))
                .frame(width: prominence == .hero ? 240 : 180, height: prominence == .hero ? 240 : 180)
                .blur(radius: 32)
                .offset(x: 110, y: -100)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: prominence == .hero ? 190 : 140, height: prominence == .hero ? 190 : 140)
                .blur(radius: 18)
                .offset(x: -120, y: -80)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(width: prominence == .hero ? 300 : 220, height: 120)
                .rotationEffect(.degrees(-18))
                .offset(x: 140, y: 70)

            Image(systemName: card.symbolName)
                .font(.system(size: prominence == .hero ? 120 : 88, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.09))
                .offset(x: prominence == .hero ? 126 : 106, y: -10)
        }
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(card.theme.textColor.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct ForYouSheet: View {
    let card: ForYouCard
    @EnvironmentObject var actionsVM: ActionsViewModel
    @EnvironmentObject var forYouVM: ForYouViewModel

    var body: some View {
        switch card.kind {
        case .action:
            ForYouActionSheet(card: card)
                .environmentObject(actionsVM)
        case .meditation:
            BreathingCardSheet(card: card)
        case .quiz:
            QuizCardSheet(card: card)
        case .reading:
            ReadingCardSheet(card: card)
        case .reflection:
            ReflectionCardSheet(card: card)
                .environmentObject(forYouVM)
        case .soundscape:
            ReadingCardSheet(card: card)
        }
    }
}

private struct ForYouActionSheet: View {
    let card: ForYouCard
    @EnvironmentObject var actionsVM: ActionsViewModel
    @State private var showSchedule = false

    var body: some View {
        if let action = card.action {
            ActionDetailSheet(
                theme: card.theme,
                action: action,
                state: actionsVM.state(for: action),
                isCompletedToday: actionsVM.isCompletedToday(action),
                onToggleComplete: { actionsVM.toggleCompletedToday(action) },
                onTogglePin: { actionsVM.togglePinned(action) },
                onSchedule: { showSchedule = true },
                onClearSchedule: {
                    Task { await actionsVM.clearSchedule(for: action) }
                }
            )
            .sheet(isPresented: $showSchedule) {
                ActionScheduleSheet(
                    theme: card.theme,
                    action: action,
                    existingSchedule: actionsVM.state(for: action).schedule
                ) { date, cadence, notificationsEnabled, calendarEnabled in
                    Task {
                        await actionsVM.applySchedule(
                            for: action,
                            date: date,
                            cadence: cadence,
                            notificationsEnabled: notificationsEnabled,
                            calendarEnabled: calendarEnabled
                        )
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct ActionDetailSheet: View {
    let theme: ForYouCardTheme
    let action: HealthAction
    let state: HealthActionState
    let isCompletedToday: Bool
    let onToggleComplete: () -> Void
    let onTogglePin: () -> Void
    let onSchedule: () -> Void
    let onClearSchedule: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        eyebrow: action.category.title,
                        title: action.title,
                        summary: action.summary,
                        accent: theme.accent,
                        durationLabel: action.durationLabel,
                        symbolName: action.category.systemImage,
                        gradient: theme.gradient
                    )

                    FloatingSheetSection(theme: theme) {
                        VStack(alignment: .leading, spacing: 10) {
                        Text("Why")
                            .font(.headline)
                        ForEach(action.benefits, id: \.self) { benefit in
                            Label(benefit, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppColors.text)
                        }
                    }
                    }

                    FloatingSheetSection(theme: theme) {
                        VStack(alignment: .leading, spacing: 12) {
                        Text("Steps")
                            .font(.headline)
                        ForEach(Array(action.steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(idx + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(theme.deepTone)
                                    .clipShape(Circle())
                                Text(step)
                                    .foregroundStyle(AppColors.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    }

                    FloatingSheetSection(theme: theme) {
                        VStack(spacing: 12) {
                        actionButton(
                            title: isCompletedToday ? "Done today" : "Done",
                            systemImage: "checkmark.circle.fill",
                            fill: theme.deepTone,
                            foreground: .white,
                            action: onToggleComplete
                        )
                        actionButton(
                            title: state.schedule == nil ? "Later" : "Edit time",
                            systemImage: "calendar.badge.plus",
                            fill: Color.white,
                            foreground: AppColors.text,
                            action: onSchedule
                        )
                        actionButton(
                            title: state.isPinned ? "Unpin" : "Pin",
                            systemImage: state.isPinned ? "pin.slash" : "pin.fill",
                            fill: Color.white,
                            foreground: AppColors.text,
                            action: onTogglePin
                        )
                        if state.schedule != nil {
                            actionButton(
                                title: "Remove schedule",
                                systemImage: "bell.slash",
                                fill: Color.white,
                                foreground: AppColors.red,
                                action: onClearSchedule
                            )
                        }
                    }
                    }
                }
                .padding(20)
            }
            .background(sheetBackground(theme: theme))
            .navigationTitle("Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func actionButton(title: String, systemImage: String, fill: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(fill)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.border, lineWidth: fill == .white ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BreathingCardSheet: View {
    let card: ForYouCard
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var remaining = 0
    @State private var phaseLabel = "Ready"
    @State private var phaseInstruction = "Let the circle set the pace."
    @State private var orbScale: CGFloat = 0.78
    @State private var ringProgress: Double = 0
    @State private var glowOpacity = 0.34
    @State private var currentRound = 0
    @State private var sessionTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SheetHero(
                        eyebrow: card.eyebrow,
                        title: card.title,
                        summary: card.summary,
                        accent: card.theme.accent,
                        durationLabel: card.durationLabel,
                        symbolName: card.symbolName,
                        gradient: card.theme.gradient
                    )

                    FloatingSheetSection(theme: card.theme) {
                        VStack(spacing: 20) {
                            breathingOrb
                                .padding(.top, 4)

                            VStack(spacing: 6) {
                                Text(phaseLabel)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(card.theme.deepTone)
                                Text(phaseInstruction)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(remaining > 0 ? "\(remaining)s left" : "\(breathing.totalSeconds)s total")
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.text)
                            }

                            HStack(spacing: 10) {
                                phaseChip("In", value: "\(breathing.inhaleSeconds)s")
                                phaseChip("Out", value: "\(breathing.exhaleSeconds)s")
                                phaseChip("Rounds", value: "\(breathing.rounds)")
                            }

                            Button(isRunning ? "Pause" : (remaining == breathing.totalSeconds ? "Start" : "Start over")) {
                                if isRunning {
                                    pause()
                                } else {
                                    start()
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(card.theme.deepTone)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .background(sheetBackground(theme: card.theme))
            .navigationTitle("Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                remaining = breathing.totalSeconds
            }
            .onDisappear {
                stopSession()
            }
        }
    }

    private var breathing: ForYouBreathing {
        card.breathing ?? ForYouBreathing(inhaleSeconds: 4, exhaleSeconds: 6, rounds: 6)
    }

    private var breathingOrb: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.48), lineWidth: 14)
                .frame(width: 250, height: 250)

            Circle()
                .trim(from: 0, to: max(ringProgress, 0.01))
                .stroke(
                    LinearGradient(
                        colors: [card.theme.accent, card.theme.deepTone],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(card.theme.accent.opacity(glowOpacity))
                .frame(width: 210, height: 210)
                .blur(radius: 18)
                .scaleEffect(orbScale)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            card.theme.accent.opacity(0.18)
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 100
                    )
                )
                .frame(width: 174, height: 174)
                .scaleEffect(orbScale)

            VStack(spacing: 6) {
                Text(isRunning ? phaseLabel : "Ready")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text(currentRound > 0 ? "Round \(currentRound) of \(breathing.rounds)" : "Find an easy seat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func phaseChip(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.text)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(card.theme.accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var phaseSequence: [BreathingPhase] {
        (0..<breathing.rounds).flatMap { round in
            [
                BreathingPhase(
                    kind: .inhale,
                    seconds: breathing.inhaleSeconds,
                    round: round + 1
                ),
                BreathingPhase(
                    kind: .exhale,
                    seconds: breathing.exhaleSeconds,
                    round: round + 1
                )
            ]
        }
    }

    private func start() {
        stopSession()
        isRunning = true
        remaining = breathing.totalSeconds
        ringProgress = 0
        currentRound = 1
        sessionTask = Task {
            let phases = phaseSequence
            let totalTicks = max(breathing.totalSeconds * 10, 1)
            var elapsedTicks = 0

            for phase in phases {
                if Task.isCancelled { return }

                await MainActor.run {
                    currentRound = phase.round
                    phaseLabel = phase.kind.title
                    phaseInstruction = phase.kind.instruction
                    withAnimation(.easeInOut(duration: Double(phase.seconds))) {
                        orbScale = phase.kind.scale
                        glowOpacity = phase.kind.glowOpacity
                    }
                }

                let phaseTicks = max(phase.seconds * 10, 1)
                for _ in 0..<phaseTicks {
                    if Task.isCancelled { return }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    elapsedTicks += 1
                    await MainActor.run {
                        ringProgress = min(Double(elapsedTicks) / Double(totalTicks), 1)
                        remaining = max(
                            breathing.totalSeconds - Int((Double(elapsedTicks) / 10.0).rounded(.toNearestOrAwayFromZero)),
                            0
                        )
                    }
                }
            }

            await MainActor.run {
                finish()
            }
        }
    }

    private func pause() {
        stopSession()
        phaseLabel = "Paused"
        phaseInstruction = "Take a moment, then start again when you want."
    }

    private func finish() {
        stopSession()
        remaining = 0
        ringProgress = 1
        phaseLabel = "Complete"
        phaseInstruction = "Nice. Keep that slower pace for the next few minutes."
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func stopSession() {
        sessionTask?.cancel()
        sessionTask = nil
        isRunning = false
    }

    private struct BreathingPhase {
        let kind: BreathingPhaseKind
        let seconds: Int
        let round: Int
    }

    private enum BreathingPhaseKind {
        case inhale
        case exhale

        var title: String {
            switch self {
            case .inhale: return "Inhale"
            case .exhale: return "Exhale"
            }
        }

        var instruction: String {
            switch self {
            case .inhale: return "Draw the breath in slowly through the nose."
            case .exhale: return "Let the exhale be long and unforced."
            }
        }

        var scale: CGFloat {
            switch self {
            case .inhale: return 1.06
            case .exhale: return 0.8
            }
        }

        var glowOpacity: Double {
            switch self {
            case .inhale: return 0.42
            case .exhale: return 0.24
            }
        }
    }
}

private struct QuizCardSheet: View {
    let card: ForYouCard
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOptionID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        eyebrow: card.eyebrow,
                        title: card.title,
                        summary: card.summary,
                        accent: card.theme.accent,
                        durationLabel: card.durationLabel,
                        symbolName: card.symbolName,
                        gradient: card.theme.gradient
                    )

                    FloatingSheetSection(theme: card.theme) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(quiz.question)
                                .font(.headline)
                                .foregroundStyle(AppColors.text)

                            VStack(spacing: 12) {
                                ForEach(quiz.options) { option in
                                    Button {
                                        selectedOptionID = option.id
                                    } label: {
                                        HStack {
                                            Text(option.title)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            if selectedOptionID == option.id {
                                                Image(systemName: option.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            }
                                        }
                                        .font(.headline)
                                        .foregroundStyle(AppColors.text)
                                        .padding(18)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(card.theme.accent.opacity(selectedOptionID == option.id ? 0.16 : 0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(
                                                    card.theme.accent.opacity(selectedOptionID == option.id ? 0.55 : 0.14),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let selected = quiz.options.first(where: { $0.id == selectedOptionID }) {
                        FloatingSheetSection(theme: card.theme) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(selected.isCorrect ? quiz.successTitle : "Try again")
                                    .font(.headline)
                                Text(selected.feedback)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(sheetBackground(theme: card.theme))
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var quiz: ForYouQuiz {
        card.quiz ?? ForYouQuiz(question: "", options: [], successTitle: "")
    }
}

private struct ReadingCardSheet: View {
    let card: ForYouCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        eyebrow: card.eyebrow,
                        title: card.title,
                        summary: card.summary,
                        accent: card.theme.accent,
                        durationLabel: card.durationLabel,
                        symbolName: card.symbolName,
                        gradient: card.theme.gradient
                    )

                    FloatingSheetSection(theme: card.theme) {
                        VStack(alignment: .leading, spacing: 14) {
                            if let kicker = card.reading?.kicker {
                                Text(kicker)
                                    .font(.headline)
                                    .foregroundStyle(AppColors.text)
                            }

                            ForEach(card.reading?.paragraphs ?? [], id: \.self) { paragraph in
                                Text(paragraph)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(sheetBackground(theme: card.theme))
            .navigationTitle("Read")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ReflectionCardSheet: View {
    let card: ForYouCard
    @EnvironmentObject var forYouVM: ForYouViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        eyebrow: card.eyebrow,
                        title: card.title,
                        summary: card.summary,
                        accent: card.theme.accent,
                        durationLabel: card.durationLabel,
                        symbolName: card.symbolName,
                        gradient: card.theme.gradient
                    )

                    FloatingSheetSection(theme: card.theme) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(reflection.prompt)
                                .font(.headline)
                                .foregroundStyle(AppColors.text)

                            TextEditor(text: $draft)
                                .padding(14)
                                .frame(minHeight: 220)
                                .background(card.theme.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(card.theme.accent.opacity(0.18), lineWidth: 1)
                                )

                            Button("Save") {
                                forYouVM.saveReflection(draft, for: card.id)
                                dismiss()
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(card.theme.deepTone)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
                .padding(20)
            }
            .background(sheetBackground(theme: card.theme))
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                draft = forYouVM.reflectionText(for: card.id)
            }
        }
    }

    private var reflection: ForYouReflection {
        card.reflection ?? ForYouReflection(prompt: "", placeholder: "")
    }
}

private struct ActionScheduleSheet: View {
    let theme: ForYouCardTheme
    let action: HealthAction
    let existingSchedule: HealthActionSchedule?
    let onSave: (Date, HealthActionCadence, Bool, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var cadence: HealthActionCadence
    @State private var notificationsEnabled: Bool
    @State private var calendarEnabled: Bool

    init(
        theme: ForYouCardTheme,
        action: HealthAction,
        existingSchedule: HealthActionSchedule?,
        onSave: @escaping (Date, HealthActionCadence, Bool, Bool) -> Void
    ) {
        self.theme = theme
        self.action = action
        self.existingSchedule = existingSchedule
        self.onSave = onSave
        _date = State(initialValue: existingSchedule?.date ?? Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date())
        _cadence = State(initialValue: existingSchedule?.cadence ?? .daily)
        _notificationsEnabled = State(initialValue: existingSchedule?.notificationsEnabled ?? true)
        _calendarEnabled = State(initialValue: existingSchedule?.calendarEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SheetHero(
                        eyebrow: "Later",
                        title: action.title,
                        summary: "Choose when this should come back into your day.",
                        accent: theme.accent,
                        durationLabel: action.durationLabel,
                        symbolName: "calendar.badge.clock",
                        gradient: theme.gradient
                    )

                    FloatingSheetSection(theme: theme) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("When")
                                .font(.headline)
                            DatePicker("Start", selection: $date)
                            Picker("Repeat", selection: $cadence) {
                                ForEach(HealthActionCadence.allCases) { cadence in
                                    Text(cadence.title).tag(cadence)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    FloatingSheetSection(theme: theme) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Remind me")
                                .font(.headline)
                            Toggle("Notification", isOn: $notificationsEnabled)
                            Toggle("Calendar", isOn: $calendarEnabled)
                        }
                    }

                    Button("Save") {
                        onSave(date, cadence, notificationsEnabled, calendarEnabled)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.deepTone)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(20)
            }
            .background(sheetBackground(theme: theme))
            .navigationTitle("Later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct SheetHero: View {
    let eyebrow: String
    let title: String
    let summary: String
    let accent: Color
    let durationLabel: String?
    let symbolName: String
    var gradient: [Color]? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient ?? [
                            accent.opacity(0.92),
                            accent.opacity(0.54),
                            Color.white
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 180, height: 180)
                .blur(radius: 12)
                .offset(x: 120, y: -70)

            Image(systemName: symbolName)
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.08))
                .offset(x: 120, y: -20)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.white.opacity(0.84))
                    Spacer()
                    if let durationLabel {
                        Text(durationLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .frame(minHeight: 220)
    }
}

struct FloatingSheetSection<Content: View>: View {
    var theme: ForYouCardTheme? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke((theme?.accent ?? Color.white).opacity(0.14), lineWidth: 1)
        )
    }
}

private func sheetBackground(theme: ForYouCardTheme) -> some View {
    ZStack {
        AppColors.background
        LinearGradient(
            colors: [
                theme.gradient[0].opacity(0.30),
                theme.gradient[1].opacity(0.14),
                Color.white.opacity(0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        Circle()
            .fill(theme.accent.opacity(0.16))
            .frame(width: 320, height: 320)
            .blur(radius: 60)
            .offset(x: 150, y: -170)
    }
}

private enum ActionLibraryMode: String, CaseIterable, Identifiable {
    case quickStarts = "Quick Starts"
    case everyday = "Everyday"
    case sound = "Sound"
    case voice = "Voice"
    case programs = "Programs"
    case brainTraining = "Brain Training"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .quickStarts: return "sparkles"
        case .everyday: return "checklist"
        case .sound: return "waveform"
        case .voice: return "mic.fill"
        case .programs: return "book.closed.fill"
        case .brainTraining: return "brain.head.profile"
        }
    }

    var heroTitle: String {
        switch self {
        case .quickStarts: return "Start with something small."
        case .everyday: return "Choose a concrete next action."
        case .sound: return "Use sound as a reset tool."
        case .voice: return "Train your voice deliberately."
        case .programs: return "Work through a structured program."
        case .brainTraining: return "Sharpen one cognitive skill."
        }
    }

    var heroSummary: String {
        switch self {
        case .quickStarts: return "Low-friction options for moments when you want to do something useful right away."
        case .everyday: return "Actions generated from your context that you can complete now or schedule for later."
        case .sound: return "Offline sound sessions for focus, regulation, and simple daily recovery rituals."
        case .voice: return "A focused microphone-based practice area for pitch, breath-supported speech, and clarity."
        case .programs: return "Longer guided journeys that save progress and give you a structure to return to."
        case .brainTraining: return "Short repeatable drills with progress tracking, so the practice stays lightweight."
        }
    }

    var emptyTitle: String {
        switch self {
        case .quickStarts: return "No quick starts available"
        case .everyday: return "No everyday actions yet"
        case .sound: return "No sound sessions available"
        case .voice: return "Voice Lab is ready"
        case .programs: return "No programs available"
        case .brainTraining: return "No trainers available"
        }
    }

    var emptySummary: String {
        switch self {
        case .quickStarts: return "Try another section while Eir surfaces more immediate suggestions."
        case .everyday: return "As your records and check-ins grow, Eir will surface more concrete actions here."
        case .sound: return "Try another section for now."
        case .voice: return "Open Voice Lab to start a practice session."
        case .programs: return "Try another section while we add more structured journeys."
        case .brainTraining: return "Try another section while we add more self-contained drills."
        }
    }
}

private struct ActionLibraryCounts {
    let quickStarts: Int
    let everyday: Int
    let sound: Int
    let programs: Int
    let brainTraining: Int
}

struct ActionLibraryView: View {
    @EnvironmentObject private var actionsVM: ActionsViewModel
    @EnvironmentObject private var forYouVM: ForYouViewModel
    @EnvironmentObject private var profileStore: ProfileStore

    @StateObject private var progressStore = ActionLibraryProgressStore()
    @State private var mode: ActionLibraryMode = .everyday
    @State private var selectedAction: HealthAction?
    @State private var selectedQuickCard: ForYouCard?
    @State private var selectedSoundCollection: ActionSoundCollection?
    @State private var selectedProgram: ActionLibraryProgram?
    @State private var selectedTrainer: ActionLibraryTrainer?
    @State private var showVoiceLab = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                libraryHero
                currentModeSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(ActionLibraryBackground().ignoresSafeArea())
        .navigationTitle("Action")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                actionModeMenu
            }
        }
        .navigationDestination(item: $selectedProgram) { program in
            ActionLibraryProgramView(program: program)
                .environmentObject(progressStore)
        }
        .navigationDestination(item: $selectedSoundCollection) { collection in
            ActionSoundCollectionView(collection: collection)
        }
        .navigationDestination(isPresented: $showVoiceLab) {
            ActionVoiceLabView()
        }
        .navigationDestination(item: $selectedTrainer) { trainer in
            SpatialWorkingMemoryTrainerView(definition: trainer)
                .environmentObject(progressStore)
        }
        .sheet(item: $selectedAction) { action in
            LibraryActionDetailSheet(action: action)
                .environmentObject(actionsVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedQuickCard) { card in
            ForYouSheet(card: card)
                .environmentObject(actionsVM)
                .environmentObject(forYouVM)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !availableModes.contains(mode), let firstMode = availableModes.first {
                mode = firstMode
            }
            progressStore.sync(profileID: profileStore.selectedProfileID)
        }
        .onChange(of: profileStore.selectedProfileID) {
            progressStore.sync(profileID: profileStore.selectedProfileID)
        }
    }

    private var libraryHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(mode.heroTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)

            Text(mode.heroSummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                heroChip(primaryHeroChip)
                heroChip(secondaryHeroChip)
                if let tertiaryHeroChip {
                    heroChip(tertiaryHeroChip)
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.96),
                    Color(hex: "FFF4E8").opacity(0.84),
                    Color(hex: "EEF2FF").opacity(0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.68), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var currentModeSection: some View {
        switch mode {
        case .quickStarts:
            section(title: "Quick starts", subtitle: "Low-friction actions you can do right now.") {
                if ActionLibraryCatalog.quickExperiences.isEmpty {
                    modeEmptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(ActionLibraryCatalog.quickExperiences) { card in
                            Button {
                                selectedQuickCard = card
                            } label: {
                                quickExperienceCard(card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .everyday:
            section(title: "Everyday actions", subtitle: "Generated from your context and ready to schedule.") {
                if actionsVM.actions.isEmpty {
                    modeEmptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(actionsVM.actions) { action in
                            Button {
                                selectedAction = action
                            } label: {
                                actionRow(action)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .sound:
            section(title: "Sound sessions", subtitle: "Therapeutic soundscapes and focus tones inspired by Eir Journal's Listen feature.") {
                if ActionSoundLibrary.collections.isEmpty {
                    modeEmptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(ActionSoundLibrary.collections) { collection in
                            Button {
                                selectedSoundCollection = collection
                            } label: {
                                soundCollectionRow(collection)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .voice:
            section(title: "Voice", subtitle: "Train vocal clarity, pitch control, and breath-supported speech with native voice exercises.") {
                Button {
                    showVoiceLab = true
                } label: {
                    voiceRow
                }
                .buttonStyle(.plain)
            }
        case .programs:
            section(title: "CBT programs", subtitle: "Structured journeys imported from Eir Journal content.") {
                if ActionLibraryCatalog.programs.isEmpty {
                    modeEmptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(ActionLibraryCatalog.programs) { program in
                            Button {
                                selectedProgram = program
                            } label: {
                                programRow(program)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        case .brainTraining:
            section(title: "Brain training", subtitle: "Short, self-contained exercises with saved progress.") {
                if ActionLibraryCatalog.trainers.isEmpty {
                    modeEmptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(ActionLibraryCatalog.trainers) { trainer in
                            Button {
                                selectedTrainer = trainer
                            } label: {
                                trainerRow(trainer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var actionModeMenu: some View {
        Menu {
            ForEach(availableModes) { item in
                Button {
                    mode = item
                } label: {
                    Label(item.rawValue, systemImage: item.symbolName)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: mode.symbolName)
                    .font(.caption.weight(.bold))
                Text(mode.rawValue)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(AppColors.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.backgroundMuted)
            .clipShape(Capsule())
        }
    }

    private var availableModes: [ActionLibraryMode] {
        ActionLibraryMode.allCases.filter { item in
            switch item {
            case .quickStarts:
                !ActionLibraryCatalog.quickExperiences.isEmpty
            case .everyday:
                true
            case .sound:
                !ActionSoundLibrary.collections.isEmpty
            case .voice:
                true
            case .programs:
                !ActionLibraryCatalog.programs.isEmpty
            case .brainTraining:
                !ActionLibraryCatalog.trainers.isEmpty
            }
        }
    }

    private var primaryHeroChip: String {
        switch mode {
        case .quickStarts:
            return "\(ActionLibraryCatalog.quickExperiences.count) quick starts"
        case .everyday:
            return "\(actionsVM.actions.count) actions"
        case .sound:
            return "\(ActionSoundLibrary.collections.count) sound sets"
        case .voice:
            return "microphone-led"
        case .programs:
            return "\(ActionLibraryCatalog.programs.count) programs"
        case .brainTraining:
            return "\(ActionLibraryCatalog.trainers.count) trainers"
        }
    }

    private var secondaryHeroChip: String {
        switch mode {
        case .quickStarts:
            return "start now"
        case .everyday:
            return "\(actionsVM.completedTodayCount) done today"
        case .sound:
            return "offline playback"
        case .voice:
            return "3 exercises"
        case .programs:
            return savedPromptProgressChip
        case .brainTraining:
            return "saved progress"
        }
    }

    private var tertiaryHeroChip: String? {
        switch mode {
        case .quickStarts:
            return nil
        case .everyday:
            return "\(actionsVM.scheduledActions.count) scheduled"
        case .sound:
            return "focus + calm"
        case .voice:
            return "offline"
        case .programs:
            return "\(ActionLibraryCatalog.programs.count) paths"
        case .brainTraining:
            return "short sessions"
        }
    }

    private var savedPromptProgressChip: String {
        let completed = ActionLibraryCatalog.programs.reduce(0) { partial, program in
            partial + progressStore.completedPromptCount(for: program)
        }
        return "\(completed) prompts saved"
    }

    private var modeEmptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode.emptyTitle)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Text(mode.emptySummary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.text)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            content()
        }
    }

    private func heroChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.82))
            .clipShape(Capsule())
    }

    private func quickExperienceCard(_ card: ForYouCard) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [card.theme.gradient[0].opacity(0.92), card.theme.gradient[1].opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)

                Image(systemName: card.symbolName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(card.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Text(card.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let durationLabel = card.durationLabel {
                    Text(durationLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(card.theme.deepTone)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(card.theme.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private func actionRow(_ action: HealthAction) -> some View {
        let state = actionsVM.state(for: action)

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(action.category.softTint)
                    .frame(width: 56, height: 56)

                Image(systemName: action.category.systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(action.category.tint)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                        Text(action.summary)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 10)

                    Text(action.durationLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(action.category.tint)
                }

                HStack(spacing: 8) {
                    actionBadge(action.category.title, tint: action.category.tint.opacity(0.16), foreground: action.category.tint)

                    if actionsVM.isCompletedToday(action) {
                        actionBadge("Done today", tint: AppColors.green.opacity(0.14), foreground: AppColors.green)
                    }

                    if let schedule = state.schedule {
                        actionBadge(scheduleLine(for: schedule), tint: AppColors.primarySoft, foreground: AppColors.primary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(action.category.tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func programRow(_ program: ActionLibraryProgram) -> some View {
        let completion = progressStore.programCompletion(for: program)
        let completedPrompts = progressStore.completedPromptCount(for: program)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(program.theme.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(program.theme)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(program.title)
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text(program.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(3)
                    Text(program.duration)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(program.theme)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 4)
            }

            ProgressView(value: completion)
                .tint(program.theme)

            HStack(spacing: 8) {
                actionBadge("\(completedPrompts)/\(program.totalPromptCount) prompts", tint: program.theme.opacity(0.14), foreground: program.theme)

                if let focus = program.focusAreas.first {
                    actionBadge(focus, tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(program.theme.opacity(0.16), lineWidth: 1)
        )
    }

    private func soundCollectionRow(_ collection: ActionSoundCollection) -> some View {
        let theme = Color(hex: collection.themeHex)
        let presetLabel = "\(collection.presets.count) session\(collection.presets.count == 1 ? "" : "s")"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.opacity(0.16), theme.opacity(0.34)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: collection.symbolName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(collection.title)
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text(collection.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(collection.helperText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 5)
            }

            HStack(spacing: 8) {
                actionBadge(presetLabel, tint: theme.opacity(0.14), foreground: theme)

                if collection.id == "binaural-beats" {
                    actionBadge("Headphones", tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                } else if collection.id == "colored-noise" {
                    actionBadge("Background-friendly", tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                } else {
                    actionBadge("Pulsed audio", tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.opacity(0.16), lineWidth: 1)
        )
    }

    private var voiceRow: some View {
        let theme = Color(hex: "C2410C")

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.opacity(0.14), Color(hex: "FED7AA").opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Voice Lab")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text("Use your microphone to explore pitch stability, practice matching notes, and rehearse clear speech.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Live microphone practice with analysis, pitch matching, and reading drills.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.top, 5)
            }

            HStack(spacing: 8) {
                actionBadge("3 exercises", tint: theme.opacity(0.14), foreground: theme)
                actionBadge("Live microphone", tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                actionBadge("Offline", tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(theme.opacity(0.16), lineWidth: 1)
        )
    }

    private func trainerRow(_ trainer: ActionLibraryTrainer) -> some View {
        let best = progressStore.bestLevel(for: trainer)

        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(trainer.theme.opacity(0.14))
                    .frame(width: 56, height: 56)

                Image(systemName: trainer.symbolName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(trainer.theme)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(trainer.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Text(trainer.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    actionBadge(trainer.duration, tint: trainer.theme.opacity(0.14), foreground: trainer.theme)
                    actionBadge("Best \(max(best, trainer.minimumLevel))", tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(trainer.theme.opacity(0.16), lineWidth: 1)
        )
    }

    private func actionBadge(_ text: String, tint: Color, foreground: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint)
            .clipShape(Capsule())
    }

    private func scheduleLine(for schedule: HealthActionSchedule) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = schedule.cadence == .once ? .medium : .none
        return "\(schedule.cadence.title) • \(formatter.string(from: schedule.date))"
    }
}

private struct LibraryActionDetailSheet: View {
    let action: HealthAction
    @EnvironmentObject private var actionsVM: ActionsViewModel
    @State private var showSchedule = false

    var body: some View {
        let theme = theme(for: action.category)

        ActionDetailSheet(
            theme: theme,
            action: action,
            state: actionsVM.state(for: action),
            isCompletedToday: actionsVM.isCompletedToday(action),
            onToggleComplete: { actionsVM.toggleCompletedToday(action) },
            onTogglePin: { actionsVM.togglePinned(action) },
            onSchedule: { showSchedule = true },
            onClearSchedule: {
                Task { await actionsVM.clearSchedule(for: action) }
            }
        )
        .sheet(isPresented: $showSchedule) {
            ActionScheduleSheet(
                theme: theme,
                action: action,
                existingSchedule: actionsVM.state(for: action).schedule
            ) { date, cadence, notificationsEnabled, calendarEnabled in
                Task {
                    await actionsVM.applySchedule(
                        for: action,
                        date: date,
                        cadence: cadence,
                        notificationsEnabled: notificationsEnabled,
                        calendarEnabled: calendarEnabled
                    )
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func theme(for category: HealthActionCategory) -> ForYouCardTheme {
        switch category {
        case .movement: return .meadow
        case .breath: return .tide
        case .recovery: return .aurora
        case .hydration: return .tide
        case .focus: return .coral
        case .sleep: return .velvet
        case .planning: return .ember
        case .nutrition: return .meadow
        }
    }
}

private struct ActionLibraryProgramView: View {
    let program: ActionLibraryProgram
    @EnvironmentObject private var progressStore: ActionLibraryProgressStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                programHero

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Progress")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        ProgressView(value: progressStore.programCompletion(for: program))
                            .tint(program.theme)

                        Text("\(progressStore.completedPromptCount(for: program)) of \(program.totalPromptCount) prompts completed")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)

                        if !program.focusAreas.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(program.focusAreas, id: \.self) { area in
                                    Text(area)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(program.theme)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(program.theme.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                ForEach(Array(program.modules.enumerated()), id: \.offset) { index, module in
                    ActionLibraryProgramModuleCard(
                        program: program,
                        module: module,
                        moduleIndex: index
                    )
                    .environmentObject(progressStore)
                }

                if !program.resources.isEmpty {
                    FloatingSheetSection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resources")
                                .font(.headline)
                                .foregroundStyle(AppColors.text)

                            ForEach(program.resources) { resource in
                                if let url = resource.url {
                                    Link(destination: url) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(resource.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppColors.text)
                                                Text(url.absoluteString)
                                                    .font(.caption)
                                                    .foregroundStyle(AppColors.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.right.square")
                                                .foregroundStyle(program.theme)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(programBackground.ignoresSafeArea())
        .navigationTitle(program.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var programHero: some View {
        SheetHero(
            eyebrow: program.condition,
            title: program.title,
            summary: program.summary,
            accent: program.theme,
            durationLabel: program.duration,
            symbolName: "book.closed.fill",
            gradient: [
                program.theme.opacity(0.96),
                program.theme.opacity(0.72),
                Color.white
            ]
        )
    }

    private var programBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    program.theme.opacity(0.20),
                    Color.white.opacity(0.86),
                    Color(hex: "FFF9F2")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct ActionLibraryProgramModuleCard: View {
    let program: ActionLibraryProgram
    let module: ActionLibraryProgramModule
    let moduleIndex: Int

    var body: some View {
        FloatingSheetSection {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(moduleIndex + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(program.theme)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(module.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        if let summary = module.overview.first {
                            Text(summary)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if module.overview.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(module.overview.dropFirst().enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !module.takeaways.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key takeaways")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.text)

                        ForEach(Array(module.takeaways.enumerated()), id: \.offset) { _, takeaway in
                            Label(takeaway, systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !module.exercises.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercises")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.text)

                        ForEach(Array(module.exercises.enumerated()), id: \.offset) { promptIndex, prompt in
                            ActionLibraryProgramPromptCard(
                                program: program,
                                moduleIndex: moduleIndex,
                                promptIndex: promptIndex,
                                prompt: prompt,
                                type: .exercise
                            )
                        }
                    }
                }

                if !module.homework.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Homework")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.text)

                        ForEach(Array(module.homework.enumerated()), id: \.offset) { promptIndex, prompt in
                            ActionLibraryProgramPromptCard(
                                program: program,
                                moduleIndex: moduleIndex,
                                promptIndex: promptIndex,
                                prompt: prompt,
                                type: .homework
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct ActionLibraryProgramPromptCard: View {
    let program: ActionLibraryProgram
    let moduleIndex: Int
    let promptIndex: Int
    let prompt: String
    let type: ActionLibraryProgramPromptType

    @EnvironmentObject private var progressStore: ActionLibraryProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(type.title) \(promptIndex + 1)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(program.theme)
                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    progressStore.togglePromptCompletion(promptKey)
                } label: {
                    Label(
                        progressStore.isPromptCompleted(promptKey) ? "Done" : "Mark done",
                        systemImage: progressStore.isPromptCompleted(promptKey) ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(progressStore.isPromptCompleted(promptKey) ? program.theme : AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(program.theme.opacity(progressStore.isPromptCompleted(promptKey) ? 0.16 : 0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            TextEditor(text: responseBinding)
                .frame(minHeight: 110)
                .padding(10)
                .background(program.theme.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(program.theme.opacity(0.14), lineWidth: 1)
                )
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(program.theme.opacity(0.12), lineWidth: 1)
        )
    }

    private var promptKey: String {
        progressStore.promptKey(
            programID: program.id,
            moduleIndex: moduleIndex,
            type: type,
            promptIndex: promptIndex
        )
    }

    private var responseBinding: Binding<String> {
        Binding(
            get: { progressStore.response(for: promptKey) },
            set: { progressStore.saveResponse($0, for: promptKey) }
        )
    }
}

private struct SpatialWorkingMemoryTrainerView: View {
    let definition: ActionLibraryTrainer

    @EnvironmentObject private var progressStore: ActionLibraryProgressStore
    @State private var level = 3
    @State private var sequence: [Int] = []
    @State private var activeIndex: Int?
    @State private var isShowing = false
    @State private var selections: [Int] = []
    @State private var bestLevel = 3
    @State private var feedbackText = "Watch the pattern, then tap the same path back."
    @State private var feedbackTone: ActionLibraryFeedbackTone = .neutral
    @State private var roundTask: Task<Void, Never>?

    private let cells = Array(0..<9)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHero(
                    eyebrow: "Brain training",
                    title: definition.title,
                    summary: definition.summary,
                    accent: definition.theme,
                    durationLabel: definition.duration,
                    symbolName: definition.symbolName,
                    gradient: [
                        definition.theme.opacity(0.96),
                        definition.theme.opacity(0.68),
                        Color.white
                    ]
                )

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How it works")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        Text("Watch the glowing squares, then tap them back in the same order. The sequence gets longer when you succeed and shortens if you miss.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 8) {
                            trainerChip("Span \(sequence.isEmpty ? level : sequence.count)")
                            trainerChip("Best \(bestLevel)")
                        }
                    }
                }

                FloatingSheetSection(theme: .tide) {
                    VStack(spacing: 18) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                            ForEach(cells, id: \.self) { cell in
                                Button {
                                    handleCellSelection(cell)
                                } label: {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(tileFill(for: cell))
                                        .frame(height: 88)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(tileBorder(for: cell), lineWidth: 1)
                                        )
                                        .scaleEffect(activeIndex == cell ? 1.04 : 1)
                                        .animation(.easeInOut(duration: 0.18), value: activeIndex)
                                }
                                .buttonStyle(.plain)
                                .disabled(isShowing)
                            }
                        }

                        ProgressView(value: sequence.isEmpty ? 0 : Double(selections.count), total: sequence.isEmpty ? 1 : Double(sequence.count))
                            .tint(definition.theme)

                        Text(feedbackText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(feedbackTone.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(feedbackTone.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        HStack(spacing: 12) {
                            Button(sequence.isEmpty ? "Start round" : (isShowing ? "Watching..." : "Watch again")) {
                                startRound(length: level)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(definition.theme)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .disabled(isShowing)

                            Button("Reset") {
                                resetTrainer()
                            }
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(spatialTrainerBackground.ignoresSafeArea())
        .navigationTitle(definition.shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bestLevel = max(progressStore.bestLevel(for: definition), definition.minimumLevel)
            level = bestLevel
        }
        .onDisappear {
            roundTask?.cancel()
        }
    }

    private var spatialTrainerBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    definition.theme.opacity(0.18),
                    Color.white.opacity(0.88),
                    Color(hex: "F5FBFF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func startRound(length: Int) {
        roundTask?.cancel()
        sequence = shuffledCells(length: length)
        selections = []
        isShowing = true
        feedbackTone = .neutral
        feedbackText = "Watch the glowing tiles closely."

        roundTask = Task {
            for (index, cell) in sequence.enumerated() {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: UInt64(index == 0 ? 250_000_000 : 700_000_000))
                await MainActor.run {
                    activeIndex = cell
                }
                try? await Task.sleep(nanoseconds: 420_000_000)
                await MainActor.run {
                    activeIndex = nil
                }
            }

            try? await Task.sleep(nanoseconds: 220_000_000)
            await MainActor.run {
                isShowing = false
                feedbackTone = .neutral
                feedbackText = "Now tap the pattern back."
            }
        }
    }

    private func handleCellSelection(_ cell: Int) {
        guard !isShowing, !sequence.isEmpty else { return }
        guard !selections.contains(cell), selections.count < sequence.count else { return }

        selections.append(cell)

        if selections.count == sequence.count {
            let isCorrect = selections == sequence
            if isCorrect {
                let nextBest = max(bestLevel, level + 1)
                bestLevel = nextBest
                level = min(level + 1, definition.maximumLevel)
                progressStore.updateBestLevel(bestLevel, for: definition)
                feedbackTone = .success
                feedbackText = "Nice recall. The next round gets a little longer."
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                level = max(level - 1, definition.minimumLevel)
                feedbackTone = .warning
                feedbackText = "Close miss. Eir shortened the next round so you can rebuild rhythm."
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } else {
            let remaining = sequence.count - selections.count
            feedbackTone = .neutral
            feedbackText = "\(remaining) tile\(remaining == 1 ? "" : "s") left."
        }
    }

    private func resetTrainer() {
        roundTask?.cancel()
        level = definition.minimumLevel
        sequence = []
        selections = []
        activeIndex = nil
        isShowing = false
        feedbackTone = .neutral
        feedbackText = "Watch the pattern, then tap the same path back."
    }

    private func shuffledCells(length: Int) -> [Int] {
        Array(cells.shuffled().prefix(length))
    }

    private func tileFill(for cell: Int) -> Color {
        if activeIndex == cell {
            return definition.theme
        }
        if selections.contains(cell) {
            return definition.theme.opacity(0.38)
        }
        return Color.white
    }

    private func tileBorder(for cell: Int) -> Color {
        if activeIndex == cell {
            return definition.theme.opacity(0.8)
        }
        return definition.theme.opacity(0.16)
    }

    private func trainerChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(definition.theme)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(definition.theme.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct ActionSoundCollectionView: View {
    let collection: ActionSoundCollection

    @StateObject private var audioEngine = ActionSoundSessionEngine()

    private var theme: Color {
        Color(hex: collection.themeHex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHero(
                    eyebrow: "Sound sessions",
                    title: collection.title,
                    summary: collection.summary,
                    accent: theme,
                    durationLabel: durationLabel(for: audioEngine.selectedDuration),
                    symbolName: collection.symbolName,
                    gradient: [
                        theme.opacity(0.96),
                        theme.opacity(0.62),
                        Color.white
                    ]
                )

                FloatingSheetSection(theme: .tide) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Session setup")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Length")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textSecondary)

                            HStack(spacing: 8) {
                                ForEach(ActionSoundLibrary.durationOptions, id: \.self) { option in
                                    let isSelected = audioEngine.selectedDuration == option
                                    Button(durationLabel(for: option)) {
                                        audioEngine.selectedDuration = option
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(isSelected ? Color.white : AppColors.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(isSelected ? theme : Color.white)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(isSelected ? theme : AppColors.border, lineWidth: 1)
                                    )
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Volume")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                                Spacer()
                                Text("\(Int(audioEngine.volume * 100))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme)
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "speaker.wave.1.fill")
                                    .foregroundStyle(AppColors.textSecondary)
                                Slider(value: $audioEngine.volume, in: 0.1 ... 1)
                                    .tint(theme)
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        if audioEngine.isPlaying {
                            HStack(alignment: .center, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(theme.opacity(0.14))
                                        .frame(width: 42, height: 42)

                                    Image(systemName: "waveform")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(theme)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Now playing")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme)
                                    Text(activePresetTitle)
                                        .font(.headline)
                                        .foregroundStyle(AppColors.text)
                                }

                                Spacer()

                                Text(timeLabel(for: audioEngine.remainingSeconds))
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .foregroundStyle(theme)
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(theme.opacity(0.18), lineWidth: 1)
                            )
                        }
                    }
                }

                if let errorMessage = audioEngine.errorMessage, !errorMessage.isEmpty {
                    FloatingSheetSection {
                        Text(errorMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Choose a session")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)

                        ForEach(collection.presets) { preset in
                            soundPresetCard(preset)
                        }
                    }
                }

                FloatingSheetSection {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                        Text(collection.helperText)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("These sessions run locally on your device. Eir does not treat them as diagnosis or treatment.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
        }
        .background(soundBackground.ignoresSafeArea())
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            audioEngine.stop()
        }
    }

    private var soundBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    theme.opacity(0.12),
                    Color.white.opacity(0.92),
                    Color(hex: "F8FBFF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var activePresetTitle: String {
        collection.presets.first(where: { $0.id == audioEngine.activePresetID })?.title ?? collection.title
    }

    private func soundPresetCard(_ preset: ActionSoundPreset) -> some View {
        let accent = Color(hex: preset.themeHex)
        let isActive = audioEngine.activePresetID == preset.id && audioEngine.isPlaying

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(isActive ? 0.92 : 0.12),
                                    accent.opacity(isActive ? 0.72 : 0.22)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Image(systemName: preset.systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(isActive ? Color.white : accent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(preset.title)
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text(preset.subtitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    Text(preset.details)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button(isActive ? "Stop" : "Play") {
                    audioEngine.togglePlayback(for: preset)
                }
                .font(.headline)
                .foregroundStyle(isActive ? AppColors.text : Color.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(isActive ? Color.white : accent)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isActive ? accent.opacity(0.2) : accent, lineWidth: 1)
                )
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                if preset.requiresHeadphones {
                    soundBadge("Headphones", tint: accent.opacity(0.14), foreground: accent)
                }

                ForEach(Array(preset.benefits.prefix(2).enumerated()), id: \.offset) { _, benefit in
                    soundBadge(benefit, tint: AppColors.backgroundMuted, foreground: AppColors.textSecondary)
                }
            }

            if isActive {
                HStack {
                    Label("Playing now", systemImage: "waveform")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(timeLabel(for: audioEngine.remainingSeconds))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isActive ? accent.opacity(0.08) : Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(isActive ? 0.28 : 0.14), lineWidth: 1)
        )
    }

    private func soundBadge(_ text: String, tint: Color, foreground: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint)
            .clipShape(Capsule())
    }

    private func durationLabel(for duration: TimeInterval) -> String {
        "\(Int(duration / 60)) min"
    }

    private func timeLabel(for seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

private struct ActionLibraryBackground: View {
    var body: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    Color(hex: "FFF9F3"),
                    Color.white,
                    Color(hex: "F3F7FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(hex: "FFD8B8").opacity(0.26))
                .frame(width: 320, height: 320)
                .blur(radius: 50)
                .offset(x: 130, y: -190)
            Circle()
                .fill(Color(hex: "CFE5FF").opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 46)
                .offset(x: -140, y: 260)
        }
    }
}

private enum ActionLibraryProgramPromptType: String, Codable {
    case exercise
    case homework

    var title: String {
        switch self {
        case .exercise: return "Exercise"
        case .homework: return "Homework"
        }
    }
}

private enum ActionLibraryFeedbackTone {
    case neutral
    case success
    case warning

    var color: Color {
        switch self {
        case .neutral: return AppColors.textSecondary
        case .success: return AppColors.green
        case .warning: return AppColors.orange
        }
    }

    var fill: Color {
        switch self {
        case .neutral: return AppColors.backgroundMuted
        case .success: return AppColors.green.opacity(0.12)
        case .warning: return AppColors.orange.opacity(0.12)
        }
    }
}

private struct ActionLibraryProgram: Identifiable, Hashable {
    let id: String
    let title: String
    let condition: String
    let summary: String
    let duration: String
    let focusAreas: [String]
    let modules: [ActionLibraryProgramModule]
    let resources: [ActionLibraryResource]
    let theme: Color

    var shortTitle: String {
        title.replacingOccurrences(of: "CBT Program for ", with: "")
    }

    var totalPromptCount: Int {
        modules.reduce(0) { partialResult, module in
            partialResult + module.exercises.count + module.homework.count
        }
    }
}

private struct ActionLibraryProgramModule: Hashable {
    let title: String
    let overview: [String]
    let takeaways: [String]
    let exercises: [String]
    let homework: [String]
}

private struct ActionLibraryResource: Identifiable, Hashable {
    let title: String
    let urlString: String

    var id: String { "\(title)-\(urlString)" }

    var url: URL? {
        URL(string: urlString)
    }
}

private struct ActionLibraryTrainer: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let duration: String
    let symbolName: String
    let theme: Color
    let minimumLevel: Int
    let maximumLevel: Int

    var shortTitle: String {
        title
    }
}

private struct ActionLibraryProgressPayload: Codable {
    var responses: [String: String] = [:]
    var completedPromptKeys: [String] = []
    var trainerBestLevels: [String: Int] = [:]
}

@MainActor
private final class ActionLibraryProgressStore: ObservableObject {
    @Published private var payload = ActionLibraryProgressPayload()

    private var currentProfileID: UUID?

    func sync(profileID: UUID?) {
        guard profileID != currentProfileID else { return }
        currentProfileID = profileID
        payload = EncryptedStore.load(ActionLibraryProgressPayload.self, forKey: storageKey) ?? ActionLibraryProgressPayload()
    }

    func response(for key: String) -> String {
        payload.responses[key] ?? ""
    }

    func saveResponse(_ response: String, for key: String) {
        payload.responses[key] = response
        save()
    }

    func promptKey(
        programID: String,
        moduleIndex: Int,
        type: ActionLibraryProgramPromptType,
        promptIndex: Int
    ) -> String {
        "\(programID).module\(moduleIndex).\(type.rawValue).\(promptIndex)"
    }

    func isPromptCompleted(_ key: String) -> Bool {
        Set(payload.completedPromptKeys).contains(key)
    }

    func togglePromptCompletion(_ key: String) {
        var completed = Set(payload.completedPromptKeys)
        if completed.contains(key) {
            completed.remove(key)
        } else {
            completed.insert(key)
        }
        payload.completedPromptKeys = Array(completed).sorted()
        save()
    }

    func completedPromptCount(for program: ActionLibraryProgram) -> Int {
        let completed = Set(payload.completedPromptKeys)
        return program.modules.enumerated().reduce(into: 0) { partialResult, module in
            let moduleIndex = module.offset
            let value = module.element

            partialResult += value.exercises.enumerated().reduce(into: 0) { count, prompt in
                let key = promptKey(programID: program.id, moduleIndex: moduleIndex, type: .exercise, promptIndex: prompt.offset)
                if completed.contains(key) { count += 1 }
            }

            partialResult += value.homework.enumerated().reduce(into: 0) { count, prompt in
                let key = promptKey(programID: program.id, moduleIndex: moduleIndex, type: .homework, promptIndex: prompt.offset)
                if completed.contains(key) { count += 1 }
            }
        }
    }

    func programCompletion(for program: ActionLibraryProgram) -> Double {
        guard program.totalPromptCount > 0 else { return 0 }
        return Double(completedPromptCount(for: program)) / Double(program.totalPromptCount)
    }

    func bestLevel(for trainer: ActionLibraryTrainer) -> Int {
        payload.trainerBestLevels[trainer.id] ?? trainer.minimumLevel
    }

    func updateBestLevel(_ level: Int, for trainer: ActionLibraryTrainer) {
        let currentBest = bestLevel(for: trainer)
        guard level > currentBest else { return }
        payload.trainerBestLevels[trainer.id] = level
        save()
    }

    private var storageKey: String {
        if let currentProfileID {
            return "eir_action_library_\(currentProfileID.uuidString)"
        }
        return "eir_action_library_global"
    }

    private func save() {
        EncryptedStore.save(payload, forKey: storageKey)
    }
}

private enum ActionLibraryCatalog {
    static let quickExperiences: [ForYouCard] = [
        ForYouCard(
            id: "library-breath-reset",
            sortOrder: 0,
            kind: .meditation,
            theme: .tide,
            eyebrow: "Quick reset",
            title: "Guided breathing reset",
            summary: "One quiet minute to bring your pace down before the next task.",
            durationLabel: "1 min",
            symbolName: "wind",
            action: nil,
            quiz: nil,
            reading: nil,
            reflection: nil,
            breathing: ForYouBreathing(inhaleSeconds: 4, exhaleSeconds: 6, rounds: 6)
        ),
        ForYouCard(
            id: "library-write-line",
            sortOrder: 1,
            kind: .reflection,
            theme: .velvet,
            eyebrow: "Quick reflection",
            title: "Write one honest line",
            summary: "Capture what would make the next few hours feel a little easier.",
            durationLabel: "1 min",
            symbolName: "square.and.pencil",
            action: nil,
            quiz: nil,
            reading: nil,
            reflection: ForYouReflection(
                prompt: "What would make your body or mind feel 5% easier over the next few hours?",
                placeholder: "Write one honest line..."
            ),
            breathing: nil
        )
    ]

    static let trainers: [ActionLibraryTrainer] = [
        ActionLibraryTrainer(
            id: "spatial-working-memory",
            title: "Pattern Recall",
            summary: "A short spatial working-memory drill that adapts to how much sequence you can hold and replay.",
            duration: "4-8 min",
            symbolName: "square.grid.3x3.fill",
            theme: Color(hex: "386FA4"),
            minimumLevel: 3,
            maximumLevel: 8
        )
    ]

    static let programs: [ActionLibraryProgram] = [
        ActionLibraryProgram(
            id: "cbt-adhd-foundations",
            title: "Mastering Your Mind: CBT Program for ADHD",
            condition: "Attention-Deficit/Hyperactivity Disorder",
            summary: "A seven-module cognitive behavioral therapy workbook to help adults with ADHD build routines, shift thoughts into action, and care for emotional wellbeing.",
            duration: "7 modules • 4-6 weeks self-paced",
            focusAreas: [
                "Executive functioning",
                "Emotional regulation",
                "Daily structure",
                "Self-compassion"
            ],
            modules: [
                ActionLibraryProgramModule(
                    title: "Module 1 • Understanding Your ADHD",
                    overview: [
                        "Learn how ADHD shows up in your life, the role of intention versus action, and why practice matters more than perfection.",
                        "Clarify the goals that led you to this program while making room for self-compassion."
                    ],
                    takeaways: [
                        "Small commitments practiced daily strengthen the bridge between intention and action.",
                        "Your strengths and values are tools you can return to when routines feel difficult."
                    ],
                    exercises: [
                        "Choose one small action and name the exact time you will complete it today.",
                        "Write 1-3 SMART goals you want to explore during this program."
                    ],
                    homework: [
                        "Capture two specific situations where inattention, hyperactivity, or impulsivity showed up this week.",
                        "List the strengths and supports you already bring to this journey.",
                        "Draft a self-compassion pledge you can reread on hard days.",
                        "Schedule daily micro-intention practice and note what you completed."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 2 • Building Structure and Routine",
                    overview: [
                        "Design simple anchors for mornings, evenings, meals, and sleep so decisions cost less energy.",
                        "Practice estimating time and blocking your day to improve planning."
                    ],
                    takeaways: [
                        "Consistent anchors make it easier to slide into focus without bargaining with time."
                    ],
                    exercises: [
                        "Define a three-step morning routine and a three-step evening wind-down that feel realistic this week.",
                        "Pick one task today, estimate its duration, and compare your estimate with the actual time."
                    ],
                    homework: [
                        "Track target and actual wake and sleep times for the next seven days.",
                        "Plan tomorrow each evening using one Must-Do, one Should-Do, and one Want-To-Do.",
                        "Reflect on which routines stuck and where time estimates surprised you."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 3 • Overcoming Procrastination",
                    overview: [
                        "Break intimidating projects into tiny physical actions and use the five-minute rule to get moving.",
                        "Link less-preferred tasks to supportive cues or rewarding activities."
                    ],
                    takeaways: [
                        "Getting started counts more than finishing everything at once."
                    ],
                    exercises: [
                        "Choose a project and list the very first physical action you can take.",
                        "Schedule one five-minute start session for a task you have been avoiding."
                    ],
                    homework: [
                        "Break down two additional tasks into micro-steps and capture their first actions.",
                        "Log each five-minute sprint you attempt this week and whether you stopped or kept going.",
                        "Note which cues or rewards made it easier to return to difficult work."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 4 • Enhancing Focus",
                    overview: [
                        "Identify internal and external distractions, redesign your workspace, and practice gentle attention redirection.",
                        "Build a mindfulness habit that helps you notice wandering thoughts without judgment."
                    ],
                    takeaways: [
                        "Attention is a muscle. Short, consistent reps create lasting change."
                    ],
                    exercises: [
                        "List your top internal and external distractions and choose one you can adjust today.",
                        "Spend three minutes tracking your breath and jot what you noticed afterward."
                    ],
                    homework: [
                        "Implement one environmental tweak and record its impact.",
                        "Use a distraction pad during two focus sessions and review what surfaced.",
                        "Track a daily attention practice for one week and reflect on the results."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 5 • Organizing Your Life",
                    overview: [
                        "Reduce visual noise by giving frequent items a clear home and decluttering in short, repeatable bursts.",
                        "Create a simple inbox-action-file flow that keeps paperwork moving."
                    ],
                    takeaways: [
                        "Small, timed tidying sessions beat marathon organizing."
                    ],
                    exercises: [
                        "Choose one small surface or drawer to declutter for 15 minutes today.",
                        "Identify 3-5 items you misplace often and decide where each will live."
                    ],
                    homework: [
                        "Schedule two timed decluttering sessions for your target area and note what changed.",
                        "Process your paper inbox twice this week and capture outstanding actions.",
                        "Observe how the state of your space influenced mood or focus."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 6 • Challenges and Emotions",
                    overview: [
                        "Use a five-step problem-solving model to respond to recurring challenges thoughtfully.",
                        "Practice emotional regulation tools like grounding and self-soothing."
                    ],
                    takeaways: [
                        "Naming emotions and pausing before responding helps keep you aligned with your values."
                    ],
                    exercises: [
                        "Describe one recurring challenge in clear, specific terms.",
                        "Walk through a pause-and-reset sequence using a recent emotional surge."
                    ],
                    homework: [
                        "Brainstorm solutions for your chosen problem, pick one to test, and log the first step.",
                        "Track emotional triggers for a week and note which regulation strategy you tried.",
                        "Summarize what you learned about your reactions and supports."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 7 • Maintaining Momentum",
                    overview: [
                        "Celebrate progress, assemble your go-to strategy list, and design a relapse prevention plan.",
                        "Decide how you will revisit routines and call in support when life shifts."
                    ],
                    takeaways: [
                        "Progress grows from reviewing, refining, and recommitting with compassion."
                    ],
                    exercises: [
                        "List the skills from this program that helped most.",
                        "Identify triggers, early warning signs, and actions that bring you back on track."
                    ],
                    homework: [
                        "Write a commitment statement for the core routines you will maintain.",
                        "Schedule your next personal system review and note what you want to evaluate.",
                        "Create a quick-reference list titled My Go-To ADHD Strategies."
                    ]
                )
            ],
            resources: [
                ActionLibraryResource(
                    title: "ADHD self-compassion exercises",
                    urlString: "https://www.compassionfocusedtherapy.com/wp-content/uploads/2020/03/CFT-Exercise-Compassionate-Hand.pdf"
                ),
                ActionLibraryResource(
                    title: "Time estimation practice timer",
                    urlString: "https://tomato-timer.com/"
                )
            ],
            theme: Color(hex: "A44A3F")
        ),
        ActionLibraryProgram(
            id: "cbt-depression-mood",
            title: "Renew Your Energy: CBT Program for Depression",
            condition: "Depression",
            summary: "A seven-module CBT journey blending psychoeducation, cognitive skills, behavioral activation, mindfulness, and relapse planning to lift mood and restore engagement.",
            duration: "7 modules • 5-7 weeks self-paced",
            focusAreas: [
                "Mood monitoring",
                "Cognitive restructuring",
                "Behavioral activation",
                "Mindfulness practice"
            ],
            modules: [
                ActionLibraryProgramModule(
                    title: "Module 1 • Understanding Your Depression",
                    overview: [
                        "Clarify what depression is, how it shows up emotionally, cognitively, physically, and behaviorally, and why it deserves compassionate care.",
                        "Explore possible contributors to build context for change."
                    ],
                    takeaways: [
                        "Depression is a medical condition shaped by multiple factors.",
                        "Recognizing early signs across body and mind helps you respond sooner."
                    ],
                    exercises: [
                        "Categorize current or past symptoms into emotional, cognitive, physical, and behavioral columns.",
                        "Jot life events, stressors, or patterns you believe influence your mood."
                    ],
                    homework: [
                        "Capture two moments this week when you noticed depressive symptoms and describe what was happening.",
                        "List questions about depression you want to revisit with a clinician, coach, or support group.",
                        "Note any strengths or supports you already rely on when your mood dips."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 2 • Principles of CBT",
                    overview: [
                        "Learn the cognitive model linking situations, thoughts, emotions, and behaviors.",
                        "Identify automatic thoughts and common cognitive distortions that keep mood low."
                    ],
                    takeaways: [
                        "Interpretations, not events alone, shape emotional reactions.",
                        "Thoughts can be observed, questioned, and reshaped into balanced alternatives."
                    ],
                    exercises: [
                        "Capture a recent mood dip, the triggering situation, automatic thoughts, emotions, and behaviors.",
                        "Highlight which distortions show up most for you."
                    ],
                    homework: [
                        "Track automatic thoughts daily and note repeated themes.",
                        "For one challenging thought, gather evidence for and against it, then craft a more balanced statement.",
                        "Reflect on times when shifting perspective changed how you felt or acted."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 3 • Behavioral Activation Foundations",
                    overview: [
                        "Understand how avoidance and withdrawal reinforce depression and how small actions can shift momentum.",
                        "Design meaningful, manageable activities aligned with your values."
                    ],
                    takeaways: [
                        "Action often comes before motivation.",
                        "Tracking mood alongside activity reveals helpful patterns."
                    ],
                    exercises: [
                        "List 10 enjoyable, meaningful, or mastery-building activities.",
                        "Circle the activities that connect with core values like growth, connection, or creativity."
                    ],
                    homework: [
                        "Complete a daily activity and mood log, rating energy and mood before and after each entry.",
                        "Choose one or two doable activities for the coming week and schedule them with specific days and times.",
                        "Note how your mood shifts before, during, and after completing each activity."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 4 • Move Your Body, Support Your Mood",
                    overview: [
                        "Explore the mind-body connection, how movement influences brain chemistry, and why consistency matters more than intensity.",
                        "Experiment with brief physical activities that feel accessible right now."
                    ],
                    takeaways: [
                        "Even gentle movement can boost energy and mood stability.",
                        "Planning activity into your day increases follow-through."
                    ],
                    exercises: [
                        "Identify five forms of movement ranging from low to moderate effort that feel realistic.",
                        "After a short walk or stretch, write down physical sensations and emotional shifts you notice."
                    ],
                    homework: [
                        "Schedule at least three short physical activity sessions this week.",
                        "Track how you feel physically and emotionally before and after each session.",
                        "Reflect on which activities felt most doable and why."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 5 • Mindfulness and Present-Moment Awareness",
                    overview: [
                        "Introduce mindfulness as paying attention on purpose, in the present moment, without judgment.",
                        "Practice observing thoughts, emotions, and sensations with curiosity rather than criticism."
                    ],
                    takeaways: [
                        "Mindfulness creates space between experience and reaction.",
                        "Short, consistent practices build awareness that supports other CBT skills."
                    ],
                    exercises: [
                        "Spend five minutes following your breath and noting when the mind wanders.",
                        "Choose one snack or meal to experience with full sensory attention."
                    ],
                    homework: [
                        "Commit to a daily five to ten minute mindfulness practice using a timer.",
                        "Record observations after each practice, including mood shifts, sensations, and judgments you noticed.",
                        "Experiment with placing a mindful pause before one routine activity."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 6 • Mindful Behavioral Activation",
                    overview: [
                        "Blend mindfulness with activity planning to reduce avoidance and stay present during challenging tasks.",
                        "Bring sensory awareness into movement and daily routines to deepen engagement."
                    ],
                    takeaways: [
                        "Mindfulness helps you notice urges to avoid without automatically obeying them.",
                        "Staying present with bodily sensations can make activity more meaningful and less overwhelming."
                    ],
                    exercises: [
                        "Choose a daily activity and narrate the sensations step by step.",
                        "Select one task you have avoided and break it into mindful mini-steps."
                    ],
                    homework: [
                        "Complete one previously avoided activity using a mindful approach and journal what you observed.",
                        "Combine mindfulness with one planned behavioral activation activity and note changes in enjoyment or resistance.",
                        "Capture any shifts in mood or perspective after these mindful experiments."
                    ]
                ),
                ActionLibraryProgramModule(
                    title: "Module 7 • Relapse Prevention and Future Planning",
                    overview: [
                        "Identify early warning signs of returning depression and create a compassionate response plan.",
                        "Design routines, supports, and check-ins that sustain progress over time."
                    ],
                    takeaways: [
                        "Relapse signals are invitations to re-engage skills, not evidence of failure.",
                        "Intentional routines and supportive relationships protect your mood."
                    ],
                    exercises: [
                        "List personal warning signs across thoughts, emotions, behaviors, and body cues.",
                        "Identify people and resources you can reach out to when mood dips and note how each can help."
                    ],
                    homework: [
                        "Draft a mood maintenance plan including daily or weekly activities, mindfulness practices, and support contacts.",
                        "Schedule future self-checks to review mood, routines, and needs.",
                        "Write a compassionate letter to your future self about what to do when symptoms re-emerge."
                    ]
                )
            ],
            resources: [
                ActionLibraryResource(
                    title: "Mood and activity tracking worksheet",
                    urlString: "https://therapistaid.com/worksheets/behavioral-activation/homework"
                ),
                ActionLibraryResource(
                    title: "Free guided mindfulness practices",
                    urlString: "https://www.uclahealth.org/programs/marc/free-guided-meditations"
                )
            ],
            theme: Color(hex: "5F4BB6")
        )
    ]
}

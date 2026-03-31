import SwiftUI

struct NextBestHealthActionCard: View {
    let snapshot: NextBestHealthActionSnapshot
    let recommendedAction: HealthAction?
    let latestCheckIn: DailyCheckIn?
    let isActionCompletedToday: Bool
    let isCheckInDue: Bool
    let showConnectHealth: Bool
    let onStartCheckIn: () -> Void
    let onCompleteAction: () -> Void
    let onTalkToEir: () -> Void
    let onOpenCareOptions: () -> Void
    let onConnectHealth: () -> Void

    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topRow
            headlineBlock

            if isCheckInDue {
                dueBanner
            }

            if let recommendedAction {
                actionBlock(recommendedAction)
            }

            actionButtons

            if let careSuggestion = snapshot.careSuggestion {
                careSuggestionBlock(careSuggestion)
            }

            if showDetails {
                detailsBlock
            }
        }
        .padding(22)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 12)
    }

    private var topRow: some View {
        HStack(alignment: .center) {
            Label("Next Best Health Action", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.82))

            Spacer()

            Text(snapshot.state.title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(stateAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.headline)
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(snapshot.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dueBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's check-in is still open")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("A 10-second check-in sharpens the recommendation.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.74))
            }
            Spacer()
        }
        .padding(14)
        .background(.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func actionBlock(_ action: HealthAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Image(systemName: action.category.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(stateAccent)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Action for today")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(action.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(action.durationLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            Text(action.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                if isCheckInDue {
                    onStartCheckIn()
                } else if !isActionCompletedToday {
                    onCompleteAction()
                }
            } label: {
                HStack {
                    Text(primaryButtonTitle)
                        .font(.headline.weight(.bold))
                    Spacer()
                    Image(systemName: primaryButtonSymbol)
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(primaryButtonTextColor)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(primaryButtonFill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isCheckInDue && isActionCompletedToday)

            HStack(spacing: 10) {
                secondaryButton(
                    title: showDetails ? "Hide why" : "Why this?",
                    symbol: "waveform.path.ecg"
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        showDetails.toggle()
                    }
                }

                secondaryButton(title: "Talk to Eir", symbol: "bubble.left.and.bubble.right.fill") {
                    onTalkToEir()
                }
            }

            if showConnectHealth {
                Button(action: onConnectHealth) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.text.square")
                        Text("Connect Apple Health for a stronger signal")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func careSuggestionBlock(_ careSuggestion: CareSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label("If this keeps going", systemImage: "cross.case")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text("SOFT")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(stateAccent)
            }

            Text(careSuggestion.triggerReason)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onOpenCareOptions) {
                HStack {
                    Text("Find care options")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !snapshot.drivers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What drove this")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))

                    ForEach(snapshot.drivers) { driver in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(driver.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            if let detail = driver.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }

            if let recommendedAction, !recommendedAction.steps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to do it")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))

                    ForEach(Array(recommendedAction.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(stateAccent)
                                .frame(width: 22, height: 22)
                                .background(.white.opacity(0.12))
                                .clipShape(Circle())

                            Text(step)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                }
            }

            if let latestCheckIn {
                Text("Latest check-in: sleep \(latestCheckIn.sleepRating)/5, stress \(latestCheckIn.stressRating)/5, energy \(latestCheckIn.energyRating)/5")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func secondaryButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var primaryButtonTitle: String {
        if isCheckInDue {
            return "Start today's check-in"
        }
        if isActionCompletedToday {
            return "Marked as done"
        }
        return "Mark action done"
    }

    private var primaryButtonSymbol: String {
        if isCheckInDue {
            return "checklist"
        }
        return isActionCompletedToday ? "checkmark.circle.fill" : "checkmark.circle"
    }

    private var primaryButtonFill: Color {
        if isCheckInDue {
            return .white
        }
        return isActionCompletedToday ? .white.opacity(0.22) : stateAccent
    }

    private var primaryButtonTextColor: Color {
        if isCheckInDue {
            return cardDeepTone
        }
        return .white
    }

    private var stateAccent: Color {
        switch snapshot.state {
        case .recoverToday:
            return Color(hex: "FFD9A0")
        case .steadyToday:
            return Color(hex: "C8FFD8")
        case .watchClosely:
            return Color(hex: "FFD2B3")
        }
    }

    private var cardDeepTone: Color {
        switch snapshot.state {
        case .recoverToday:
            return Color(hex: "294180")
        case .steadyToday:
            return Color(hex: "174C39")
        case .watchClosely:
            return Color(hex: "6F2F1E")
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        switch snapshot.state {
        case .recoverToday:
            return [Color(hex: "0F172A"), Color(hex: "284B8E"), Color(hex: "7AA2FF")]
        case .steadyToday:
            return [Color(hex: "0D1F1A"), Color(hex: "1E6C4B"), Color(hex: "6FD2A4")]
        case .watchClosely:
            return [Color(hex: "23130F"), Color(hex: "8C3D25"), Color(hex: "F5A97F")]
        }
    }
}

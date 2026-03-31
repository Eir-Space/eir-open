import CoreLocation
import SwiftUI

struct SelfReferralClinicSheet: View {
    let careSuggestion: CareSuggestion

    @EnvironmentObject private var clinicStore: SelfReferralClinicStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMatch: SelfReferralClinicMatch?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchBar
                    suggestionChips

                    if let loadError = clinicStore.loadError {
                        errorBanner(loadError)
                    }

                    if clinicStore.isLoading {
                        loadingState
                    } else if !clinicStore.hasScope {
                        scopeState
                    } else if clinicStore.rankedResults.isEmpty {
                        emptyState
                    } else {
                        resultSection
                    }
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("Find Care")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            clinicStore.apply(careSuggestion: careSuggestion)
            clinicStore.loadIfNeeded()
        }
        .sheet(item: $selectedMatch) { match in
            SelfReferralClinicDetailView(
                match: match,
                careSuggestion: careSuggestion
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Soft Care Suggestion", systemImage: "cross.case.fill")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(AppColors.primary)

            Text("If this pattern keeps going, it may help to prepare for care.")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.text)

            Text(careSuggestion.triggerReason)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("A good opening question")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)

                Text(careSuggestion.questionPrompt)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.text)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.backgroundMuted)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.textSecondary)

                TextField("Search municipality, county, or clinic", text: $clinicStore.query)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(AppColors.backgroundMuted)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                clinicStore.requestLocation()
            } label: {
                HStack(spacing: 8) {
                    if clinicStore.isLocationLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: clinicStore.userLocation == nil ? "location" : "location.fill")
                    }

                    Text(clinicStore.userLocation == nil ? "Near me" : "Nearby")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested care types")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(careSuggestion.suggestedClinicTypes) { suggestedType in
                        SuggestionChip(
                            title: suggestedType.title,
                            isActive: clinicStore.selectedSuggestedTypes.contains(suggestedType)
                        ) {
                            clinicStore.toggle(suggestedType)
                        }
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(AppColors.primary)
            Text("Loading verified self-referral clinics...")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private var scopeState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Narrow the search first")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            Text("Use your location or search for a municipality, county, or clinic name. Results only include clinics with verified 1177 self-referral support.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No verified self-referral clinics matched")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            Text("Try a broader municipality or county, or turn on location so Eir can rank nearby options.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(clinicStore.rankedResults.count) verified options")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            ForEach(clinicStore.rankedResults) { match in
                Button {
                    selectedMatch = match
                } label: {
                    SelfReferralClinicRow(match: match)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColors.danger)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.danger.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SuggestionChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? .white : AppColors.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isActive ? AppColors.primaryStrong : AppColors.backgroundMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SelfReferralClinicRow: View {
    let match: SelfReferralClinicMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.clinic.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.text)
                        .multilineTextAlignment(.leading)

                    Text(match.clinic.displayLocationLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(match.clinic.type.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppColors.primarySoft)
                        .clipShape(Capsule())

                    if let distanceKm = match.distanceKm {
                        Text(distanceLabel(distanceKm))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            if let firstAction = match.clinic.firstActionLabel {
                Text(firstAction)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.green)
            }

            if !match.clinic.summary.isEmpty {
                Text(match.clinic.summary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func distanceLabel(_ distanceKm: Double) -> String {
        if distanceKm < 1 {
            return "\(Int(distanceKm * 1000)) m"
        }
        return String(format: "%.1f km", distanceKm)
    }
}

private struct SelfReferralClinicDetailView: View {
    let match: SelfReferralClinicMatch
    let careSuggestion: CareSuggestion

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    actionBlock
                    evidenceBlock

                    if !match.clinic.summary.isEmpty {
                        infoBlock(
                            title: "About this clinic",
                            text: match.clinic.summary
                        )
                    }

                    infoBlock(
                        title: "Question to bring",
                        text: careSuggestion.questionPrompt
                    )
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("Clinic Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(match.clinic.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.text)

            Text(match.clinic.displayLocationLine)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            if let phone = match.clinic.contact.phone {
                Text(phone)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primary)
            }
        }
    }

    private var actionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let profileURL = URL(string: match.clinic.links.profile1177) {
                actionButton(
                    title: "Open 1177 profile",
                    symbol: "safari.fill"
                ) {
                    openURL(profileURL)
                }
            }

            if let referralURL = match.clinic.firstEvidence?.url.flatMap(URL.init(string:)) {
                actionButton(
                    title: "Open self-referral form",
                    symbol: "square.and.arrow.up"
                ) {
                    openURL(referralURL)
                }
            }

            if let phoneURL = telephoneURL(match.clinic.contact.phone) {
                actionButton(
                    title: "Call clinic",
                    symbol: "phone.fill"
                ) {
                    openURL(phoneURL)
                }
            }
        }
    }

    private var evidenceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Why this is included")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            if let evidence = match.clinic.firstEvidence {
                Text(evidence.text)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.green)

                if let excerpt = evidence.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("This clinic has verified 1177 self-referral support.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.text)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColors.primaryStrong)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func telephoneURL(_ phone: String?) -> URL? {
        guard let phone else { return nil }
        let digits = phone.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

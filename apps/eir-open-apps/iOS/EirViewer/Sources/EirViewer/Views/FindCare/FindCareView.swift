import SwiftUI
import SafariServices
import MapKit
import UIKit

private enum FindCareLayoutMode: String, CaseIterable, Identifiable {
    case both = "Both"
    case map = "Map"
    case list = "List"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .both:
            return "square.split.2x1"
        case .map:
            return "map"
        case .list:
            return "list.bullet"
        }
    }
}

private enum FindCareFocusedField: Hashable {
    case issueDescription
    case searchQuery
}

struct FindCareView: View {
    let careSuggestion: CareSuggestion?

    @EnvironmentObject private var settingsVM: SettingsViewModel
    @EnvironmentObject private var localModelManager: LocalModelManager

    @StateObject private var clinicStore = SelfReferralClinicStore()
    @State private var layoutMode: FindCareLayoutMode = .both
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedMapClinicID: String?
    @State private var issueDescription = ""
    @State private var issueAnalysis: FindCareIssueAnalysis?
    @State private var isAISearching = false
    @State private var isTranscribingIssue = false
    @State private var aiSearchError: String?
    @State private var issueTranscriptionError: String?
    @State private var showVoiceComposer = false
    @State private var pendingCloudConsent: PendingCloudConsent?
    @FocusState private var focusedField: FindCareFocusedField?

    init(careSuggestion: CareSuggestion? = nil) {
        self.careSuggestion = careSuggestion
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                issueSearchSection
                searchBar
                layoutToggle
                suggestionChips

                if let loadError = clinicStore.loadError {
                    errorBanner(loadError)
                }

                if clinicStore.isLoading {
                    loadingState
                } else if clinicStore.rankedResults.isEmpty {
                    emptyState
                } else {
                    if showsMap {
                        mapSection
                    }

                    if showsList {
                        resultsSection
                    }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColors.background)
        .navigationTitle("Find Care")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .navigationDestination(for: SelfReferralClinicMatch.self) { match in
            FindCareClinicDetailView(
                match: match,
                careSuggestion: careSuggestion,
                issueAnalysis: issueAnalysis
            )
        }
        .task {
            clinicStore.apply(careSuggestion: careSuggestion)
            clinicStore.loadIfNeeded()
            updateMapViewport()
        }
        .onChange(of: mapSignature) {
            updateMapViewport()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
            }
        )
        .alert(
            "Share Data with \(pendingCloudConsent?.provider.displayName ?? "Cloud Provider")?",
            isPresented: Binding(
                get: { pendingCloudConsent != nil },
                set: { if !$0 { pendingCloudConsent = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                pendingCloudConsent = nil
            }
            Button("I Agree") {
                Task {
                    await handleGrantedCloudConsent()
                }
            }
        } message: {
            Text(pendingCloudConsentMessage)
        }
        .sheet(isPresented: $showVoiceComposer) {
            VoiceNoteComposerSheet(title: "Describe Your Issue") { draft in
                Task {
                    await transcribeIssueVoiceNote(draft)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let careSuggestion {
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

                detailBlock(
                    title: "A good opening question",
                    text: careSuggestion.questionPrompt
                )
            } else {
                Label("Verified 1177 Clinics", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.primary)

                Text("Find clinics with verified egenremiss support on 1177.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.text)

                Text("Browse the verified list, search by municipality or county, and jump straight into the clinic’s 1177 egenremiss flow.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Link(destination: guideURL) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                    Text("Open Eir Guide")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppColors.text)
                .padding(14)
                .background(AppColors.backgroundMuted)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
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
                    .focused($focusedField, equals: .searchQuery)
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

    private var issueSearchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Describe what you need help with")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)

                    Text("Eir can turn your description into a clinic match, rank nearby options, and draft text for an egen vårdbegäran.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if clinicStore.userLocation != nil {
                    Label("Near you", systemImage: "location.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppColors.primarySoft)
                        .clipShape(Capsule())
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.backgroundMuted)

                TextEditor(text: $issueDescription)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: 116)
                    .focused($focusedField, equals: .issueDescription)

                if issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Example: I keep waking up exhausted and stressed, and I want help finding the right clinic close to me.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 116)

            HStack(spacing: 10) {
                Button {
                    showVoiceComposer = true
                } label: {
                    HStack(spacing: 8) {
                        if isTranscribingIssue {
                            ProgressView()
                                .tint(AppColors.text)
                        } else {
                            Image(systemName: "mic.fill")
                        }

                        Text(isTranscribingIssue ? "Transcribing..." : "Talk")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppColors.backgroundMuted)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isTranscribingIssue || isAISearching)

                Button {
                    requestAISearch()
                } label: {
                    HStack(spacing: 8) {
                        if isAISearching {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isAISearching ? "Searching..." : "AI Search")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppColors.primaryStrong)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isAISearching || isTranscribingIssue)

                if issueAnalysis != nil {
                    Button {
                        clearAIAnalysis()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColors.backgroundMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if let aiSearchError {
                errorBanner(aiSearchError)
            }

            if let issueTranscriptionError {
                errorBanner(issueTranscriptionError)
            }

            if let issueAnalysis {
                aiSummaryCard(issueAnalysis)
            }
        }
        .padding(18)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggested care types")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SuggestedClinicType.allCases) { suggestedType in
                        Button {
                            clinicStore.toggle(suggestedType)
                        } label: {
                            Text(suggestedType.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(clinicStore.selectedSuggestedTypes.contains(suggestedType) ? .white : AppColors.text)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(clinicStore.selectedSuggestedTypes.contains(suggestedType) ? AppColors.primaryStrong : AppColors.backgroundMuted)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var layoutToggle: some View {
        HStack(spacing: 8) {
            ForEach(FindCareLayoutMode.allCases) { item in
                Button {
                    layoutMode = item
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: item.symbolName)
                            .font(.caption.weight(.bold))
                        Text(item.rawValue)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(layoutMode == item ? .white : AppColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(layoutMode == item ? AppColors.primaryStrong : AppColors.backgroundMuted)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No verified clinics matched")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            Text("Try a broader municipality, county, or care type. Results only include clinics with verified egenremiss support on 1177.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(resultsTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            ForEach(clinicStore.rankedResults) { match in
                NavigationLink(value: match) {
                    FindCareClinicRow(match: match)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Clinic map")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                Text("\(mapMatches.count) pins")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            if mapMatches.isEmpty {
                Text("No clinic coordinates are available for the current filter.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.backgroundMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                Map(position: $mapPosition, selection: $selectedMapClinicID) {
                    ForEach(mapMatches) { match in
                        if let coordinate = match.clinic.coordinate {
                            Marker(match.clinic.name, coordinate: coordinate)
                                .tint(AppColors.primary)
                                .tag(match.id)
                        }
                    }
                }
                .frame(height: layoutMode == .map ? 360 : 240)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.border, lineWidth: 1)
                )

                if let selectedMatch = selectedMapMatch {
                    NavigationLink(value: selectedMatch) {
                        selectedMapCallout(for: selectedMatch)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var resultsTitle: String {
        if clinicStore.hasScope {
            return "\(clinicStore.rankedResults.count) verified options"
        }
        return "\(clinicStore.rankedResults.count) verified clinics to browse"
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

    private func aiSummaryCard(_ analysis: FindCareIssueAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI match")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)

                    Text(analysis.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                }

                Spacer()

                Label("Draft ready", systemImage: "doc.text.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppColors.green.opacity(0.14))
                    .clipShape(Capsule())
            }

            if !analysis.resolvedSuggestedTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(analysis.resolvedSuggestedTypes) { suggestedType in
                            Text(suggestedType.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.text)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(AppColors.backgroundMuted)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if !analysis.searchQuery.isEmpty {
                Text("Search focus: \(analysis.searchQuery)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            if !analysis.recommendedQuestion.isEmpty {
                detailBlock(title: "Question to bring", text: analysis.recommendedQuestion)
            }

            if let topMatch = clinicStore.rankedResults.first {
                NavigationLink(value: topMatch) {
                    aiTopMatchCard(topMatch)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func aiTopMatchCard(_ match: SelfReferralClinicMatch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Best match right now")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.primary)

                    Text(match.clinic.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColors.text)

                    Text(match.clinic.displayLocationLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(match.clinic.type.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(AppColors.backgroundMuted)
                        .clipShape(Capsule())

                    if let distanceKm = match.distanceKm {
                        Text(distanceLabel(distanceKm))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text("Add location for distance")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            Text("Open this clinic to review the 1177 page and use the draft in the egen vårdbegäran flow.")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func detailBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)

            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.text)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var guideURL: URL {
        URL(string: "https://guide.eir.space")!
    }

    private var pendingCloudConsentMessage: String {
        guard let pendingCloudConsent else {
            return "Your data will be sent to the selected provider."
        }

        switch pendingCloudConsent.purpose {
        case .aiSearch:
            return "Your issue description will be sent to \(pendingCloudConsent.provider.displayName) to generate a care match and draft self-referral text. On-device models keep everything on your phone."
        }
    }

    private var showsMap: Bool {
        layoutMode == .both || layoutMode == .map
    }

    private var showsList: Bool {
        layoutMode == .both || layoutMode == .list
    }

    private var mapMatches: [SelfReferralClinicMatch] {
        Array(clinicStore.rankedResults.filter { $0.clinic.coordinate != nil }.prefix(24))
    }

    private var selectedMapMatch: SelfReferralClinicMatch? {
        guard let selectedMapClinicID else { return nil }
        return mapMatches.first(where: { $0.id == selectedMapClinicID })
    }

    private var mapSignature: String {
        mapMatches.map(\.id).joined(separator: "|")
    }

    private func selectedMapCallout(for match: SelfReferralClinicMatch) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(match.clinic.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.text)

                Text(match.clinic.displayLocationLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(AppColors.primary)
        }
        .padding(14)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func updateMapViewport() {
        guard !mapMatches.isEmpty else { return }

        let coordinates = mapMatches.compactMap(\.clinic.coordinate)
        let allCoordinates = coordinates + (clinicStore.userLocation.map { [$0.coordinate] } ?? [])
        guard !allCoordinates.isEmpty else { return }

        mapPosition = .region(region(for: allCoordinates))

        if let selectedMapClinicID, mapMatches.contains(where: { $0.id == selectedMapClinicID }) {
            return
        }

        selectedMapClinicID = mapMatches.first?.id
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)

        let minLatitude = latitudes.min() ?? 59.3293
        let maxLatitude = latitudes.max() ?? minLatitude
        let minLongitude = longitudes.min() ?? 18.0686
        let maxLongitude = longitudes.max() ?? minLongitude

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.45, 0.16)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.45, 0.16)

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private func distanceLabel(_ distanceKm: Double) -> String {
        if distanceKm < 1 {
            return "\(Int(distanceKm * 1000)) m"
        }
        return String(format: "%.1f km", distanceKm)
    }

    private func requestAISearch() {
        let trimmed = issueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            aiSearchError = "Describe the main issue first so Eir knows what kind of care to look for."
            return
        }

        aiSearchError = nil

        if clinicStore.userLocation == nil && !clinicStore.isLocationLoading {
            clinicStore.requestLocation()
        }

        guard let config = settingsVM.activeProvider else {
            applyIssueAnalysis(Self.fallbackIssueAnalysis(from: trimmed))
            return
        }

        if !config.type.isLocal && !ChatViewModel.hasCloudConsent(for: config.type) {
            pendingCloudConsent = PendingCloudConsent(provider: config.type, purpose: .aiSearch)
            return
        }

        Task {
            await runAISearch(using: config)
        }
    }

    private func handleGrantedCloudConsent() async {
        guard let consentRequest = pendingCloudConsent else { return }
        let provider = consentRequest.provider
        let purpose = consentRequest.purpose

        ChatViewModel.grantCloudConsent(for: provider)
        pendingCloudConsent = nil

        guard let config = settingsVM.providers.first(where: { $0.type == provider }) else {
            applyIssueAnalysis(Self.fallbackIssueAnalysis(from: issueDescription))
            return
        }

        do {
            if provider.usesManagedTrialAccess {
                _ = try await settingsVM.provisionManagedAccess(for: config)
            }

            switch purpose {
            case .aiSearch:
                await runAISearch(using: config)
            }
        } catch {
            switch purpose {
            case .aiSearch:
                aiSearchError = error.localizedDescription
            }
        }
    }

    private func transcribeIssueVoiceNote(_ draft: RecordedVoiceNoteDraft) async {
        var shouldDeleteRecording = true
        defer {
            if shouldDeleteRecording {
                try? FileManager.default.removeItem(at: draft.fileURL)
            }
        }

        issueTranscriptionError = nil

        isTranscribingIssue = true
        defer { isTranscribingIssue = false }

        do {
            let transcript = try await VoiceNoteTranscriptionService.transcribe(draft: draft, settingsVM: settingsVM)
            guard !transcript.isEmpty else {
                throw LLMError.requestFailed("The voice note could not be turned into text.")
            }

            applyIssueTranscript(transcript)
        } catch {
            issueTranscriptionError = error.localizedDescription
        }
    }

    private func applyIssueTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issueDescription = trimmed
        } else {
            issueDescription = "\(issueDescription.trimmingCharacters(in: .whitespacesAndNewlines))\n\(trimmed)"
        }

        issueAnalysis = nil
        aiSearchError = nil
    }

    private func runAISearch(using config: LLMProviderConfig) async {
        let trimmed = issueDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isAISearching = true
        defer { isAISearching = false }

        do {
            let analysis: FindCareIssueAnalysis
            if config.type.isLocal {
                guard localModelManager.isReady else {
                    analysis = Self.fallbackIssueAnalysis(from: trimmed)
                    applyIssueAnalysis(analysis)
                    return
                }

                analysis = try await analyzeIssueLocally(trimmed)
            } else {
                analysis = try await analyzeIssueInCloud(trimmed, config: config)
            }

            applyIssueAnalysis(analysis)
        } catch {
            applyIssueAnalysis(Self.fallbackIssueAnalysis(from: trimmed))
            aiSearchError = "AI search was not available, so Eir used a fast match from your description."
        }
    }

    private func analyzeIssueLocally(_ issue: String) async throws -> FindCareIssueAnalysis {
        let prompt = Self.issueAnalysisPrompt(issue: issue)
        let response = try await localModelManager.service.streamResponse(
            userMessage: prompt,
            systemPrompt: Self.issueAnalysisSystemPrompt,
            conversationId: UUID()
        ) { _ in }
        return try Self.decodeIssueAnalysis(from: response)
    }

    private func analyzeIssueInCloud(_ issue: String, config: LLMProviderConfig) async throws -> FindCareIssueAnalysis {
        let credential = try await settingsVM.resolvedCredential(for: config)
        let service = LLMService(config: config, apiKey: credential)
        let response = try await service.completeChat(messages: [
            (role: "system", content: Self.issueAnalysisSystemPrompt),
            (role: "user", content: Self.issueAnalysisPrompt(issue: issue))
        ])
        return try Self.decodeIssueAnalysis(from: response)
    }

    private func applyIssueAnalysis(_ analysis: FindCareIssueAnalysis) {
        issueAnalysis = analysis

        let combinedQuery = ([analysis.searchQuery] + analysis.specialtyKeywords)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        if !combinedQuery.isEmpty {
            clinicStore.query = combinedQuery
        }

        let suggestedTypes = Set(analysis.resolvedSuggestedTypes)
        if !suggestedTypes.isEmpty {
            clinicStore.selectedSuggestedTypes = suggestedTypes
        }

        layoutMode = .both
        updateMapViewport()
    }

    private func clearAIAnalysis() {
        issueAnalysis = nil
        aiSearchError = nil
        issueDescription = ""
        clinicStore.query = ""
        clinicStore.selectedSuggestedTypes = []
    }

    private static let issueAnalysisSystemPrompt = """
    You route Swedish care seekers to verified 1177 self-referral clinics.
    Never diagnose. Never recommend unverified clinics. Use the same language as the user.
    Return strict JSON only with this shape:
    {
      "summary": "short explanation",
      "searchQuery": "short clinic search query",
      "suggestedTypes": ["primaryCare", "psychiatry", "psychology", "rehab"],
      "specialtyKeywords": ["keyword"],
      "recommendedQuestion": "one short question to ask a clinic",
      "selfReferralDraft": "2-4 sentence first-person draft for an egen vardbegaran"
    }
    Keep suggestedTypes to at most 2 values.
    Keep searchQuery short and practical.
    selfReferralDraft must be factual, first-person, and avoid diagnoses.
    """

    private static func issueAnalysisPrompt(issue: String) -> String {
        """
        User issue:
        \(issue)

        Turn this into clinic search intent for Sweden and a reusable self-referral draft.
        """
    }

    private static func decodeIssueAnalysis(from response: String) throws -> FindCareIssueAnalysis {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let jsonString: String
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            jsonString = String(cleaned[start...end])
        } else {
            jsonString = cleaned
        }

        guard let data = jsonString.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        return try JSONDecoder().decode(FindCareIssueAnalysis.self, from: data)
    }

    private static func fallbackIssueAnalysis(from issue: String) -> FindCareIssueAnalysis {
        let normalized = issue
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        var suggestedTypes: [SuggestedClinicType] = [.primaryCare]

        if normalized.contains("stress")
            || normalized.contains("anxiety")
            || normalized.contains("angest")
            || normalized.contains("panic")
            || normalized.contains("depression")
            || normalized.contains("adhd") {
            suggestedTypes = [.psychiatry, .psychology]
        } else if normalized.contains("therapy")
            || normalized.contains("therap")
            || normalized.contains("sleep")
            || normalized.contains("burnout") {
            suggestedTypes = [.psychology, .primaryCare]
        } else if normalized.contains("pain")
            || normalized.contains("back")
            || normalized.contains("neck")
            || normalized.contains("shoulder")
            || normalized.contains("knee")
            || normalized.contains("fysio")
            || normalized.contains("rehab") {
            suggestedTypes = [.rehab, .primaryCare]
        }

        let query = suggestedTypes.map(\.title).joined(separator: " ")
        let draft = """
        I am seeking care for \(issue.trimmingCharacters(in: .whitespacesAndNewlines)).
        These symptoms are affecting my daily life and I would like an assessment and advice on what support or treatment is appropriate.
        """

        return FindCareIssueAnalysis(
            summary: "Eir matched your description to \(suggestedTypes.map(\.title).joined(separator: " and ")).",
            searchQuery: query,
            suggestedTypes: suggestedTypes.map(\.id),
            specialtyKeywords: [],
            recommendedQuestion: "Could you help me understand whether this clinic is the right starting point for my symptoms?",
            selfReferralDraft: draft
        )
    }
}

private struct FindCareClinicRow: View {
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

private struct FindCareClinicDetailView: View {
    let match: SelfReferralClinicMatch
    let careSuggestion: CareSuggestion?
    let issueAnalysis: FindCareIssueAnalysis?

    @Environment(\.openURL) private var openURL
    @State private var inAppSafariDestination: InAppSafariDestination?
    @State private var copiedDraft = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock
                flowBlock
                actionBlock
                evidenceBlock

                if !match.clinic.summary.isEmpty {
                    infoBlock(title: "About this clinic", text: match.clinic.summary)
                }

                if let careSuggestion {
                    infoBlock(title: "Question to bring", text: careSuggestion.questionPrompt)
                }

                if let issueAnalysis {
                    aiDraftBlock(issueAnalysis)
                }
            }
            .padding(20)
        }
        .background(AppColors.background)
        .navigationTitle("Clinic Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $inAppSafariDestination) { destination in
            InAppSafariView(url: destination.url)
                .ignoresSafeArea()
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

    private var flowBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Egenremiss flow")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            flowStep(number: 1, title: "Open the clinic on 1177", text: "Read the clinic page and confirm that it matches the type of care you need.")
            flowStep(number: 2, title: match.clinic.selfReferralButtonTitle, text: "Start the clinic’s verified egenremiss or egen vårdbegäran flow directly on 1177.")
            flowStep(number: 3, title: "Use Eir Guide if you want help writing it", text: "guide.eir.space can help you prepare the wording before you send the request.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let referralURL = match.clinic.selfReferralURL {
                actionButton(
                    title: issueAnalysis == nil ? match.clinic.selfReferralButtonTitle : "Copy draft & open \(match.clinic.selfReferralButtonTitle)",
                    symbol: "square.and.arrow.up"
                ) {
                    if let draft = issueAnalysis?.selfReferralDraft, !draft.isEmpty {
                        UIPasteboard.general.string = draft
                        copiedDraft = true
                    }
                    inAppSafariDestination = InAppSafariDestination(url: referralURL)
                }
            }

            actionButton(
                title: "Open 1177 clinic page",
                symbol: "safari.fill"
            ) {
                openURL(URL(string: match.clinic.links.profile1177)!)
            }

            actionButton(
                title: "Open Eir Guide",
                symbol: "sparkles.rectangle.stack"
            ) {
                openURL(URL(string: "https://guide.eir.space")!)
            }

            if let phoneURL = telephoneURL(match.clinic.contact.phone) {
                actionButton(
                    title: "Call clinic",
                    symbol: "phone.fill"
                ) {
                    openURL(phoneURL)
                }
            }

            if copiedDraft {
                Text("The AI draft was copied so you can paste it into the 1177 form.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var evidenceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verified 1177 evidence")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            if match.clinic.selfReferral.evidence.isEmpty {
                Text("This clinic has verified 1177 self-referral support.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                ForEach(Array(match.clinic.selfReferral.evidence.prefix(3).enumerated()), id: \.offset) { _, evidence in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(evidence.text)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppColors.green)

                        if let excerpt = evidence.excerpt, !excerpt.isEmpty {
                            Text(excerpt)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
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

    private func aiDraftBlock(_ analysis: FindCareIssueAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI draft for egen vårdbegäran")
                .font(.headline)
                .foregroundStyle(AppColors.text)

            Text(analysis.selfReferralDraft)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIPasteboard.general.string = analysis.selfReferralDraft
                copiedDraft = true
            } label: {
                Label("Copy draft", systemImage: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.background)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.backgroundMuted)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func flowStep(number: Int, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.text)

                Text(text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

private struct InAppSafariDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct FindCareIssueAnalysis: Codable {
    let summary: String
    let searchQuery: String
    let suggestedTypes: [String]
    let specialtyKeywords: [String]
    let recommendedQuestion: String
    let selfReferralDraft: String

    var resolvedSuggestedTypes: [SuggestedClinicType] {
        suggestedTypes.compactMap(SuggestedClinicType.init(id:))
    }
}

private struct PendingCloudConsent {
    enum Purpose {
        case aiSearch
    }

    let provider: LLMProviderType
    let purpose: Purpose
}

private extension SuggestedClinicType {
    init?(id: String) {
        switch id {
        case SuggestedClinicType.primaryCare.id:
            self = .primaryCare
        case SuggestedClinicType.psychiatry.id:
            self = .psychiatry
        case SuggestedClinicType.psychology.id:
            self = .psychology
        case SuggestedClinicType.rehab.id:
            self = .rehab
        default:
            return nil
        }
    }
}

private struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = UIColor(AppColors.primary)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

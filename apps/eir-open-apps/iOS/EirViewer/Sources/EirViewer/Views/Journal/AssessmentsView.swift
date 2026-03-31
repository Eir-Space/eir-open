import SwiftUI
import UIKit
import Yams

struct AssessmentsView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var settingsVM: SettingsViewModel
    @EnvironmentObject private var localModelManager: LocalModelManager

    @ObservedObject var store: AssessmentHistoryStore

    @State private var selectedCategory = "All"

    private let library = AssessmentLibrary.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                overviewHero

                if !completedSummaries.isEmpty {
                    takenAssessmentsSection
                } else if let latest = store.records.first,
                          let form = library.form(id: latest.assessmentID) {
                    NavigationLink {
                        AssessmentResultView(
                            form: form,
                            record: latest,
                            store: store
                        )
                    } label: {
                        latestResultCard(record: latest, form: form)
                    }
                    .buttonStyle(.plain)
                }

                categoryRail

                if library.forms.isEmpty {
                    emptyLibraryState
                } else if selectedCategory == "All" {
                    ForEach(displayCategories, id: \.self) { category in
                        assessmentSection(category: category, forms: forms(for: category))
                    }
                } else {
                    assessmentSection(category: selectedCategory, forms: filteredForms)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(assessmentBackground.ignoresSafeArea())
        .navigationTitle("Assessments")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            store.load(for: profileStore.selectedProfileID)
        }
    }

    private var overviewHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Structured self-checks")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.text)

            Text("Take a guided assessment, keep the result in your journal, and get a short reflection from Eir when a model is available.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 10) {
                heroMetric(value: "\(library.forms.count)", label: "Assessments")
                heroMetric(value: "\(store.records.count)", label: "Saved results")
                heroMetric(value: profileStore.selectedProfile?.displayName ?? "Profile", label: "Active")
            }

            if let error = library.loadError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppColors.orange)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(14)
                .background(Color.white.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "FFF7ED"),
                    Color(hex: "FEF3C7"),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color(hex: "FED7AA"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func heroMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func latestResultCard(record: AssessmentRecord, form: AssessmentForm) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Latest result")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(hex: form.themeColorHex))
                    Text(form.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    if let overall = record.overall {
                        Text(overall.band.label)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(10)
                    .background(AppColors.backgroundMuted)
                    .clipShape(Circle())
            }

            Text(record.completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            if let storedInsight = record.insightText, !storedInsight.isEmpty {
                Text(storedInsight)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.text)
                    .lineLimit(3)
            } else if let overall = record.overall {
                Text(overall.band.resolvedDescription)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.text)
                    .lineLimit(3)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(["All"] + displayCategories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedCategory == category ? Color.white : AppColors.text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(
                                selectedCategory == category
                                    ? Color(hex: "C2410C")
                                    : Color.white.opacity(0.82)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(
                                        selectedCategory == category ? Color.clear : AppColors.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var takenAssessmentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Taken assessments")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text("Retake completed tests to compare how things shift over time.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text("\(completedSummaries.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.82))
                    .clipShape(Capsule())
            }

            ForEach(completedSummaries) { summary in
                if let form = library.form(id: summary.record.assessmentID) {
                    NavigationLink {
                        AssessmentDetailView(form: form, store: store)
                    } label: {
                        CompletedAssessmentRow(
                            form: form,
                            record: summary.record,
                            shouldRetake: summary.shouldRetake
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func assessmentSection(category: String, forms: [AssessmentForm]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            ForEach(forms) { form in
                NavigationLink {
                    AssessmentDetailView(form: form, store: store)
                } label: {
                    AssessmentRow(
                        form: form,
                        latestRecord: store.latest(for: form.id)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyLibraryState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No assessments available")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)
            Text("The assessment catalog could not be loaded. Once the content file is available, this screen will populate automatically.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var filteredForms: [AssessmentForm] {
        forms(for: selectedCategory)
    }

    private var displayCategories: [String] {
        let preferredOrder = [
            "Mental", "Neuro", "Sleep", "Physical", "Stress",
            "Substance", "Wellbeing", "Personality"
        ]
        let available = Set(library.forms.map(\.category))
        let ordered = preferredOrder.filter { available.contains($0) }
        let remainder = available.subtracting(preferredOrder).sorted()
        return ordered + remainder
    }

    private func forms(for category: String) -> [AssessmentForm] {
        let forms = library.forms.filter { category == "All" || $0.category == category }
        return forms.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                return lhs.title < rhs.title
            }
            return lhs.category < rhs.category
        }
    }

    private var completedSummaries: [CompletedAssessmentSummary] {
        library.forms.compactMap { form in
            guard let latest = store.latest(for: form.id) else { return nil }
            return CompletedAssessmentSummary(
                id: form.id,
                record: latest,
                shouldRetake: store.shouldRetake(formID: form.id)
            )
        }
        .sorted { $0.record.completedAt > $1.record.completedAt }
    }

    private var assessmentBackground: some View {
        ZStack {
            AppColors.background
            LinearGradient(
                colors: [
                    Color(hex: "FFF7ED").opacity(0.65),
                    Color(hex: "FFFBEB").opacity(0.35),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color(hex: "FED7AA").opacity(0.32))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: 140, y: -180)
            Circle()
                .fill(Color(hex: "FDE68A").opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -140, y: 160)
        }
    }
}

private struct AssessmentRow: View {
    let form: AssessmentForm
    let latestRecord: AssessmentRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: form.themeColorHex).opacity(0.18))
                    Image(systemName: iconName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(hex: form.themeColorHex))
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text(form.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text(form.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(form.description)
                .font(.subheadline)
                .foregroundStyle(AppColors.text)
                .lineLimit(2)

            HStack(spacing: 8) {
                metaChip("\(form.questions.count) questions")
                metaChip(form.estimatedDurationLabel)
                if let latestRecord, let overall = latestRecord.overall {
                    metaChip(overall.band.label, tint: overall.band.color, emphasized: true)
                    metaChip("Retake", tint: Color(hex: "C2410C"), emphasized: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func metaChip(_ title: String, tint: Color = AppColors.backgroundMuted, emphasized: Bool = false) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(emphasized ? Color.white : AppColors.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint)
            .clipShape(Capsule())
    }

    private var iconName: String {
        switch form.category {
        case "Mental": return "brain.head.profile"
        case "Neuro": return "sparkles.square.filled.on.square"
        case "Sleep": return "moon.stars.fill"
        case "Physical": return "figure.walk"
        case "Stress": return "bolt.heart.fill"
        case "Substance": return "drop.fill"
        case "Wellbeing": return "sun.max.fill"
        case "Personality": return "person.crop.circle.badge.questionmark"
        default: return "checklist"
        }
    }
}

private struct CompletedAssessmentSummary: Identifiable {
    let id: String
    let record: AssessmentRecord
    let shouldRetake: Bool
}

private struct CompletedAssessmentRow: View {
    let form: AssessmentForm
    let record: AssessmentRecord
    let shouldRetake: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: form.themeColorHex).opacity(0.16))
                Image(systemName: iconName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: form.themeColorHex))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                Text(form.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.text)

                if let overall = record.overall {
                    Text(overall.band.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(overall.band.color)
                }

                Text("Taken \(record.completedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(shouldRetake ? "Retake recommended" : "Recently taken")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(shouldRetake ? Color(hex: "C2410C") : AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        shouldRetake
                            ? Color(hex: "FFEDD5")
                            : AppColors.backgroundMuted
                    )
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch form.category {
        case "Mental": return "brain.head.profile"
        case "Neuro": return "sparkles.square.filled.on.square"
        case "Sleep": return "moon.stars.fill"
        case "Physical": return "figure.walk"
        case "Stress": return "bolt.heart.fill"
        case "Substance": return "drop.fill"
        case "Wellbeing": return "sun.max.fill"
        case "Personality": return "person.crop.circle.badge.questionmark"
        default: return "checklist"
        }
    }
}

private struct AssessmentDetailView: View {
    let form: AssessmentForm

    @ObservedObject var store: AssessmentHistoryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerCard
                instructionCard
                dimensionCard

                if !history.isEmpty {
                    historyCard
                }

                NavigationLink {
                    AssessmentRunnerView(form: form, store: store)
                } label: {
                    Text(history.isEmpty ? "Start assessment" : "Retake assessment")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: form.themeColorHex))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(form.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(form.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: form.themeColorHex))
            Text(form.description)
                .font(.body)
                .foregroundStyle(AppColors.text)

            HStack(spacing: 10) {
                detailStat("\(form.questions.count)", "Questions")
                detailStat(form.scale.label, "Scale")
                detailStat(form.estimatedDurationLabel, "Time")
            }

            if let latest = history.first, let overall = latest.overall {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last result")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(overall.band.label)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Text(latest.completedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: form.themeColorHex).opacity(0.16),
                    Color.white,
                    Color(hex: "FFF7ED")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private func detailStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to answer")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            ForEach(form.instructions, id: \.self) { instruction in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color(hex: form.themeColorHex))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    Text(instruction)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.text)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var dimensionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What this explores")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            FlowLayout(spacing: 10) {
                ForEach(form.scoring.dimensions) { dimension in
                    Text(dimension.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.backgroundMuted)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent results")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            ForEach(history.prefix(3)) { record in
                NavigationLink {
                    AssessmentResultView(form: form, record: record, store: store)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.completedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.text)
                            if let overall = record.overall {
                                Text(overall.band.label)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(14)
                    .background(AppColors.backgroundMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var history: [AssessmentRecord] {
        store.history(for: form.id)
    }
}

private struct AssessmentRunnerView: View {
    @EnvironmentObject private var profileStore: ProfileStore

    let form: AssessmentForm

    @ObservedObject var store: AssessmentHistoryStore

    @State private var currentIndex = 0
    @State private var responses: [String: Int] = [:]
    @State private var completedRecord: AssessmentRecord?

    var body: some View {
        VStack(spacing: 0) {
            runnerHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    questionCard
                    optionStack
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }

            bottomBar
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Assessment")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $completedRecord) { record in
            AssessmentResultView(form: form, record: record, store: store)
        }
    }

    private var runnerHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Question \(currentIndex + 1) of \(form.questions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Text(progressLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: form.themeColorHex))
            }

            ProgressView(value: Double(currentIndex + 1), total: Double(form.questions.count))
                .tint(Color(hex: form.themeColorHex))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(currentQuestion.dimension)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: form.themeColorHex))

            Text(currentQuestion.text)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppColors.text)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var optionStack: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(form.scale.label)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            ForEach(form.scale.options, id: \.value) { option in
                Button {
                    selectOption(option.value)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(
                                    selectedValue == option.value ? Color(hex: form.themeColorHex) : AppColors.border,
                                    lineWidth: 2
                                )
                                .frame(width: 24, height: 24)

                            if selectedValue == option.value {
                                Circle()
                                    .fill(Color(hex: form.themeColorHex))
                                    .frame(width: 12, height: 12)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.label)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppColors.text)
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(selectedValue == option.value ? Color(hex: form.themeColorHex).opacity(0.1) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                selectedValue == option.value ? Color(hex: form.themeColorHex) : AppColors.border,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                if currentIndex > 0 {
                    currentIndex -= 1
                }
            } label: {
                Text("Back")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(currentIndex > 0 ? AppColors.text : AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(AppColors.backgroundMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(currentIndex == 0)

            Button {
                submitCurrentSelection()
            } label: {
                Text(currentIndex == form.questions.count - 1 ? "Finish" : "Next")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(selectedValue == nil ? AppColors.textSecondary : Color(hex: form.themeColorHex))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedValue == nil)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Color.white.opacity(0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.border)
                .frame(height: 1)
        }
    }

    private var currentQuestion: AssessmentQuestion {
        form.questions[currentIndex]
    }

    private var selectedValue: Int? {
        responses[currentQuestion.id]
    }

    private var progressLabel: String {
        "\(Int((Double(currentIndex + 1) / Double(form.questions.count)) * 100))%"
    }

    private func selectOption(_ value: Int) {
        responses[currentQuestion.id] = value
    }

    private func submitCurrentSelection() {
        guard selectedValue != nil else { return }

        if currentIndex == form.questions.count - 1 {
            guard let record = store.save(form: form, responses: responses) else { return }
            completedRecord = record
        } else {
            currentIndex += 1
        }
    }
}

private struct AssessmentResultView: View {
    @EnvironmentObject private var settingsVM: SettingsViewModel
    @EnvironmentObject private var localModelManager: LocalModelManager

    let form: AssessmentForm
    let record: AssessmentRecord

    @ObservedObject var store: AssessmentHistoryStore

    @State private var displayedInsight: String = ""
    @State private var insightSource: AssessmentInsightSource = .ruleBased
    @State private var isGeneratingInsight = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                resultHero
                safetyCard
                dimensionsCard
                insightCard
                backToAssessmentsButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: record.id) {
            await loadInsight()
        }
    }

    @ViewBuilder
    private var resultHero: some View {
        if let overall = record.overall {
            VStack(alignment: .leading, spacing: 14) {
                Text(form.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Text(overall.band.label)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(overall.band.color)

                Text(form.scoring.overall.label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.text)

                Text(overall.band.resolvedDescription)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Text("Saved \(record.completedAt.formatted(date: .long, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        overall.band.color.opacity(0.16),
                        Color.white,
                        Color(hex: "FFF7ED")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var safetyCard: some View {
        if let warning = safetyMessage {
            VStack(alignment: .leading, spacing: 10) {
                Text("Important")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.red)
                Text(warning)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.text)
                Text("This assessment is not a diagnosis. If you feel unsafe or at risk, contact local emergency services or a crisis line immediately.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "FEF2F2"))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "FECACA"), lineWidth: 1)
            )
        }
    }

    private var dimensionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.text)

            ForEach(record.dimensions) { dimension in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(dimension.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.text)
                            if let description = dimension.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        Text(dimension.band.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dimension.band.color)
                    }

                    ProgressView(value: dimension.normalizedScore)
                        .tint(dimension.band.color)

                    if let description = dimension.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(14)
                .background(AppColors.backgroundMuted)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Feedback")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.text)

                Spacer()

                if isGeneratingInsight {
                    ProgressView()
                        .tint(AppColors.textSecondary)
                        .scaleEffect(0.8)
                }

                Text(insightSource.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppColors.backgroundMuted)
                    .clipShape(Capsule())
            }

            Text(displayedInsight)
                .font(.subheadline)
                .foregroundStyle(AppColors.text)

            Text("Use this result as a reflection aid and a journaled snapshot, not as a diagnosis.")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    private var backToAssessmentsButton: some View {
        Button {
            AssessmentNavigation.popToAssessmentsRoot()
        } label: {
            Text("Back to Journal")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.primaryStrong)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var safetyMessage: String? {
        guard form.id == "depression" else { return nil }
        if let safetyDimension = record.dimensions.first(where: { $0.id == "Safety" }),
           safetyDimension.score >= 1 {
            return "You indicated at least some safety-related symptoms on this check-in."
        }
        return nil
    }

    private func loadInsight() async {
        if let stored = record.insightText, !stored.isEmpty {
            displayedInsight = stored
            insightSource = record.insightSource ?? .ruleBased
            return
        }

        let fallback = AssessmentInsightGenerator.fallback(for: form, record: record)
        displayedInsight = fallback
        insightSource = .ruleBased

        guard !isGeneratingInsight else { return }
        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        do {
            if let generated = try await AssessmentInsightGenerator.generate(
                for: form,
                record: record,
                settingsVM: settingsVM,
                localModelManager: localModelManager
            ) {
                displayedInsight = generated.text
                insightSource = generated.source
                store.updateInsight(for: record.id, text: generated.text, source: generated.source)
            }
        } catch {
            displayedInsight = fallback
            insightSource = .ruleBased
        }
    }
}

@MainActor
final class AssessmentHistoryStore: ObservableObject {
    @Published private(set) var records: [AssessmentRecord] = []

    private var activeProfileID: UUID?

    func load(for profileID: UUID?) {
        activeProfileID = profileID
        guard let profileID else {
            records = []
            return
        }

        records = (EncryptedStore.load([AssessmentRecord].self, forKey: storageKey(for: profileID)) ?? [])
            .sorted { $0.completedAt > $1.completedAt }
    }

    func history(for assessmentID: String) -> [AssessmentRecord] {
        records
            .filter { $0.assessmentID == assessmentID }
            .sorted { $0.completedAt > $1.completedAt }
    }

    func latest(for assessmentID: String) -> AssessmentRecord? {
        history(for: assessmentID).first
    }

    func save(form: AssessmentForm, responses: [String: Int]) -> AssessmentRecord? {
        guard let profileID = activeProfileID else { return nil }

        let result = AssessmentScorer.compute(form: form, responses: responses)
        let record = AssessmentRecord(
            id: UUID(),
            assessmentID: form.id,
            completedAt: Date(),
            overall: result.overall,
            dimensions: result.dimensions,
            responses: responses
        )

        records.insert(record, at: 0)
        EncryptedStore.save(records, forKey: storageKey(for: profileID))
        load(for: profileID)
        return records.first(where: { $0.id == record.id }) ?? record
    }

    func updateInsight(for recordID: UUID, text: String, source: AssessmentInsightSource) {
        guard let profileID = activeProfileID,
              let index = records.firstIndex(where: { $0.id == recordID }) else {
            return
        }

        records[index].insightText = text
        records[index].insightSource = source
        EncryptedStore.save(records, forKey: storageKey(for: profileID))
    }

    private func storageKey(for profileID: UUID) -> String {
        "assessment_history_\(profileID.uuidString)"
    }

    func shouldRetake(formID: String) -> Bool {
        guard let latest = latest(for: formID) else { return false }
        return Calendar.current.dateComponents([.day], from: latest.completedAt, to: Date()).day ?? 0 >= 14
    }
}

@MainActor
private enum AssessmentInsightGenerator {
    struct GeneratedInsight {
        let text: String
        let source: AssessmentInsightSource
    }

    static func fallback(for form: AssessmentForm, record: AssessmentRecord) -> String {
        let dimensionSummary = record.dimensions
            .sorted { $0.normalizedScore > $1.normalizedScore }
            .prefix(2)
            .map { "\($0.label.lowercased()) (\($0.band.label.lowercased()))" }
            .joined(separator: " and ")

        let overallLine = record.overall.map {
            "\($0.band.label) on \(form.title.lowercased()) with a score of \($0.formattedScore)."
        } ?? "This assessment has been saved in your journal."

        let patternLine = dimensionSummary.isEmpty
            ? "Use the questions you answered as a reflection point and compare with future check-ins."
            : "The strongest signal in this result is around \(dimensionSummary)."

        let careLine: String
        if form.id == "depression",
           let safety = record.dimensions.first(where: { $0.id == "Safety" }),
           safety.score >= 1 {
            careLine = "Because you marked at least some safety-related symptoms, it would be wise to reach out to a clinician or crisis resource rather than sitting with this alone."
        } else {
            careLine = "Use this as a conversation starter with care if the pattern keeps repeating or starts affecting daily life."
        }

        return "\(overallLine) \(patternLine) \(careLine)"
    }

    static func generate(
        for form: AssessmentForm,
        record: AssessmentRecord,
        settingsVM: SettingsViewModel,
        localModelManager: LocalModelManager
    ) async throws -> GeneratedInsight? {
        let systemPrompt = """
        You are Eir, a calm health journaling assistant.
        Explain self-assessment results without diagnosing.
        Keep the response under 120 words.
        Mention one or two practical next steps.
        If safety-related symptoms appear, encourage urgent human support.
        """

        let summary = buildPrompt(form: form, record: record)

        guard let config = settingsVM.activeProvider else {
            return nil
        }

        if config.type.isLocal {
            guard localModelManager.isReady else {
                return nil
            }

            let response = try await localModelManager.service.streamResponse(
                userMessage: summary,
                systemPrompt: systemPrompt,
                conversationId: UUID()
            ) { _ in }

            let cleaned = cleanedResponse(response)
            guard !cleaned.isEmpty else { return nil }
            return GeneratedInsight(text: cleaned, source: .localModel)
        }

        guard ChatViewModel.hasCloudConsent(for: config.type) else {
            return nil
        }

        let credential = try await settingsVM.resolvedCredential(for: config)
        let service = LLMService(config: config, apiKey: credential)
        let response = try await service.completeChat(
            messages: [
                (role: "system", content: systemPrompt),
                (role: "user", content: summary),
            ]
        )
        let cleaned = cleanedResponse(response)
        guard !cleaned.isEmpty else { return nil }
        return GeneratedInsight(text: cleaned, source: .cloudModel)
    }

    private static func buildPrompt(form: AssessmentForm, record: AssessmentRecord) -> String {
        let overallSummary = record.overall.map {
            "Overall: \($0.band.label), score \($0.formattedScore), note: \($0.band.resolvedDescription)"
        } ?? "Overall: no overall score available."

        let dimensions = record.dimensions
            .map { "\($0.label): \($0.band.label), score \($0.formattedScore)." }
            .joined(separator: " ")

        return """
        Assessment title: \(form.title)
        Category: \(form.category)
        \(overallSummary)
        Dimensions: \(dimensions)
        Give a short, supportive reflection for a journal entry. Do not diagnose.
        """
    }

    private static func cleanedResponse(_ response: String) -> String {
        response
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum AssessmentLibrary {
    private static let bundledPathCandidates = [
        Bundle.main.url(forResource: "health-assessments", withExtension: "yaml", subdirectory: "Assessments"),
        Bundle.main.url(forResource: "health-assessments", withExtension: "yaml"),
    ]

    static let shared = load()

    static func load() -> AssessmentCatalogState {
        let decoder = YAMLDecoder()

        for candidate in bundledPathCandidates {
            guard let candidate else { continue }
            guard let yaml = try? String(contentsOf: candidate, encoding: .utf8) else { continue }
            if let payload = try? decoder.decode(AssessmentCatalogPayload.self, from: yaml) {
                return AssessmentCatalogState(forms: payload.forms, loadError: nil)
            }
        }

        return AssessmentCatalogState(
            forms: [],
            loadError: "Assessment content could not be loaded from the app bundle."
        )
    }
}

private struct AssessmentCatalogState {
    let forms: [AssessmentForm]
    let loadError: String?

    func form(id: String) -> AssessmentForm? {
        forms.first(where: { $0.id == id })
    }
}

private struct AssessmentCatalogPayload: Decodable {
    let forms: [AssessmentForm]
}

struct AssessmentForm: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let themeColorHex: String
    let category: String
    let description: String
    let instructions: [String]
    let scale: AssessmentScale
    let questions: [AssessmentQuestion]
    let scoring: AssessmentScoring

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case themeColorHex = "themeColor"
        case category
        case description
        case instructions
        case scale
        case questions
        case scoring
    }

    var estimatedDurationLabel: String {
        let minutes = max(2, Int(ceil(Double(questions.count) / 4)))
        return "\(minutes) min"
    }
}

struct AssessmentScale: Decodable, Hashable {
    let label: String
    let options: [AssessmentOption]

    var maxValue: Int {
        options.map(\.value).max() ?? 0
    }

    var minValue: Int {
        options.map(\.value).min() ?? 0
    }
}

struct AssessmentOption: Decodable, Hashable {
    let label: String
    let value: Int
}

struct AssessmentQuestion: Identifiable, Decodable, Hashable {
    let id: String
    let text: String
    let dimension: String
}

struct AssessmentScoring: Decodable, Hashable {
    let method: AssessmentScoringMethod
    let overall: AssessmentOverallConfig
    let dimensions: [AssessmentDimensionConfig]
}

enum AssessmentScoringMethod: String, Codable, Hashable {
    case sum
    case average
}

struct AssessmentOverallConfig: Decodable, Hashable {
    let label: String
    let bands: [AssessmentBand]
}

struct AssessmentDimensionConfig: Identifiable, Decodable, Hashable {
    let id: String
    let label: String
    let description: String?
    let bands: [AssessmentBand]
}

struct AssessmentBand: Identifiable, Codable, Hashable {
    let id = UUID()
    let min: Double
    let max: Double
    let label: String
    let colorHex: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case min
        case max
        case label
        case colorHex = "color"
        case description
    }

    var color: Color {
        if let colorHex, !colorHex.isEmpty {
            return Color(hex: colorHex)
        }
        return AppColors.text
    }

    var resolvedDescription: String {
        description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? description!
            : label
    }
}

struct AssessmentRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let assessmentID: String
    let completedAt: Date
    let overall: AssessmentStoredOverall?
    let dimensions: [AssessmentStoredDimension]
    let responses: [String: Int]
    var insightText: String?
    var insightSource: AssessmentInsightSource?
}

struct AssessmentStoredOverall: Codable, Hashable {
    let label: String
    let score: Double
    let method: AssessmentScoringMethod
    let band: AssessmentBand
    let normalizedScore: Double

    var formattedScore: String {
        AssessmentScorer.format(score: score, method: method)
    }
}

struct AssessmentStoredDimension: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let description: String?
    let score: Double
    let method: AssessmentScoringMethod
    let band: AssessmentBand
    let normalizedScore: Double

    var formattedScore: String {
        AssessmentScorer.format(score: score, method: method)
    }
}

enum AssessmentInsightSource: String, Codable, Hashable {
    case ruleBased
    case localModel
    case cloudModel

    var label: String {
        switch self {
        case .ruleBased: return "Journal summary"
        case .localModel: return "On device"
        case .cloudModel: return "AI"
        }
    }
}

private enum AssessmentScorer {
    struct ComputedResult {
        let overall: AssessmentStoredOverall?
        let dimensions: [AssessmentStoredDimension]
    }

    static func compute(form: AssessmentForm, responses: [String: Int]) -> ComputedResult {
        let answeredValues = form.questions.compactMap { responses[$0.id] }
        guard !answeredValues.isEmpty else {
            return ComputedResult(overall: nil, dimensions: [])
        }

        let total = answeredValues.reduce(0, +)
        let overallScore = form.scoring.method == .sum
            ? Double(total)
            : Double(total) / Double(answeredValues.count)

        let overallBand = findBand(in: form.scoring.overall.bands, for: overallScore)
        let maxOverall = form.scoring.method == .sum
            ? Double(form.questions.count * form.scale.maxValue)
            : Double(form.scale.maxValue)
        let minOverall = Double(form.scale.minValue)

        let overall = AssessmentStoredOverall(
            label: form.scoring.overall.label,
            score: overallScore,
            method: form.scoring.method,
            band: overallBand,
            normalizedScore: normalize(score: overallScore, min: minOverall, max: maxOverall)
        )

        let groupedResponses = Dictionary(grouping: form.questions, by: \.dimension)
        let dimensionResults = groupedResponses.compactMap { dimensionID, questions -> AssessmentStoredDimension? in
            let values = questions.compactMap { responses[$0.id] }
            guard !values.isEmpty else { return nil }

            let total = values.reduce(0, +)
            let score = form.scoring.method == .sum
                ? Double(total)
                : Double(total) / Double(values.count)

            let config = form.scoring.dimensions.first(where: { $0.id == dimensionID })
            let band = findBand(in: config?.bands ?? [], for: score)
            let maxScore = form.scoring.method == .sum
                ? Double(questions.count * form.scale.maxValue)
                : Double(form.scale.maxValue)
            let minScore = Double(form.scale.minValue)

            return AssessmentStoredDimension(
                id: dimensionID,
                label: config?.label ?? dimensionID,
                description: config?.description,
                score: score,
                method: form.scoring.method,
                band: band,
                normalizedScore: normalize(score: score, min: minScore, max: maxScore)
            )
        }
        .sorted { $0.normalizedScore > $1.normalizedScore }

        return ComputedResult(overall: overall, dimensions: dimensionResults)
    }

    static func format(score: Double, method: AssessmentScoringMethod) -> String {
        switch method {
        case .sum:
            return String(Int(score.rounded()))
        case .average:
            return score.formatted(.number.precision(.fractionLength(1)))
        }
    }

    private static func findBand(in bands: [AssessmentBand], for score: Double) -> AssessmentBand {
        bands.first(where: { score >= $0.min && score <= $0.max }) ?? bands.last ?? AssessmentBand(
            min: 0,
            max: score,
            label: "Observed",
            colorHex: nil,
            description: nil
        )
    }

    private static func normalize(score: Double, min minimum: Double, max maximum: Double) -> Double {
        guard maximum > minimum else { return 0 }
        return Swift.min(Swift.max((score - minimum) / (maximum - minimum), 0), 1)
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HFlow(spacing: spacing) {
            content
        }
    }
}

private struct HFlow: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

@MainActor
private enum AssessmentNavigation {
    static func popToAssessmentsRoot() {
        guard let navigationController = activeNavigationController() else { return }
        navigationController.popToRootViewController(animated: true)
    }

    private static func activeNavigationController() -> UINavigationController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController,
               let navigationController = findNavigationController(from: root) {
                return navigationController
            }
        }
        return nil
    }

    private static func findNavigationController(from controller: UIViewController) -> UINavigationController? {
        if let navigationController = controller as? UINavigationController {
            return navigationController
        }
        if let tabBarController = controller as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return findNavigationController(from: selected)
        }
        if let splitViewController = controller as? UISplitViewController,
           let last = splitViewController.viewControllers.last {
            return findNavigationController(from: last)
        }
        if let presented = controller.presentedViewController {
            return findNavigationController(from: presented)
        }
        for child in controller.children.reversed() {
            if let navigationController = findNavigationController(from: child) {
                return navigationController
            }
        }
        return controller.navigationController
    }
}

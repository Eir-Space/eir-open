import SwiftUI

struct HealthKitImportView: View {
    @StateObject private var viewModel = HealthKitImportViewModel()
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .selectingTypes:
                    selectionPhase
                case .authorizing:
                    progressPhase(title: "Ber om behörighet...", subtitle: "Godkänn i Apple Health-dialogen")
                case .importing:
                    progressPhase(
                        title: "Importerar hälsodata...",
                        subtitle: "\(Int(viewModel.importProgress * 100))% klart",
                        progress: viewModel.importProgress
                    )
                case .preview:
                    previewPhase
                case .saving:
                    progressPhase(title: "Sparar...", subtitle: "Skapar EIR-fil")
                case .complete:
                    completePhase
                case .error(let message):
                    errorPhase(message: message)
                }
            }
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }

    // MARK: - Selection Phase

    private var selectionPhase: some View {
        List {
            if !viewModel.isHealthKitAvailable {
                Section {
                    Label("HealthKit är inte tillgängligt på den här enheten.", systemImage: "exclamationmark.triangle")
                        .foregroundColor(AppColors.red)
                }
            }

            Section {
                Picker("Period", selection: $viewModel.selectedDateRange) {
                    ForEach(DateRangeOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.selectedDateRange) { _, _ in
                    Task { await viewModel.loadSampleCounts() }
                }
            } header: {
                Text("Tidsperiod")
            }

            Section {
                ForEach(HealthDataCategory.allCases) { category in
                    CategoryToggleRow(
                        category: category,
                        isSelected: viewModel.selectedCategories.contains(category),
                        count: viewModel.sampleCounts[category]
                    ) {
                        if viewModel.selectedCategories.contains(category) {
                            viewModel.selectedCategories.remove(category)
                        } else {
                            viewModel.selectedCategories.insert(category)
                        }
                    }
                }
            } header: {
                Text("Datatyper")
            } footer: {
                Text("Antal mätningar visar ungefärlig mängd data som finns tillgänglig.")
            }

            Section {
                Button {
                    let name = profileStore.selectedProfile?.patientName
                    Task { await viewModel.startImport(patientName: name) }
                } label: {
                    HStack {
                        Spacer()
                        Label("Importera", systemImage: "square.and.arrow.down")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(!viewModel.isHealthKitAvailable || viewModel.selectedCategories.isEmpty)
            }
        }
        .task {
            await viewModel.loadSampleCounts()
        }
    }

    // MARK: - Progress Phase

    private func progressPhase(title: String, subtitle: String, progress: Double? = nil) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.text)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
            if let progress = progress {
                ProgressView(value: progress)
                    .tint(AppColors.primary)
                    .padding(.horizontal, 60)
            }
            Spacer()
        }
    }

    // MARK: - Preview Phase

    private var previewPhase: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(viewModel.importedEntryCount) poster hittades")
                            .font(.headline)
                            .foregroundColor(AppColors.text)
                        Text("Redo att sparas som EIR-fil")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Uppdelning") {
                ForEach(viewModel.categoryCounts.sorted(by: { $0.value > $1.value }), id: \.key) { key, count in
                    HStack {
                        Text(key)
                            .foregroundColor(AppColors.text)
                        Spacer()
                        Text("\(count)")
                            .foregroundColor(AppColors.textSecondary)
                            .monospacedDigit()
                    }
                }
            }

            Section {
                Button {
                    if let url = viewModel.save() {
                        if let profile = profileStore.addProfile(displayName: "Apple Health", fileURL: url) {
                            profileStore.selectProfile(profile.id)
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label("Spara & öppna", systemImage: "checkmark.circle")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Complete Phase

    private var completePhase: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(AppColors.green)
            Text("Import klar!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)
            Text("\(viewModel.importedEntryCount) poster har lagts till i din journal.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Klar") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            Spacer()
        }
    }

    // MARK: - Error Phase

    private func errorPhase(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.orange)
            Text("Något gick fel")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.text)
            Text(message)
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Försök igen") { viewModel.reset() }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            Spacer()
        }
    }
}

// MARK: - Category Toggle Row

private struct CategoryToggleRow: View {
    let category: HealthDataCategory
    let isSelected: Bool
    let count: Int?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.primary : AppColors.border)
                    .font(.title3)

                Image(systemName: category.icon)
                    .foregroundColor(categoryIconColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .foregroundColor(AppColors.text)
                        .font(.body)
                    Text(category.eirCategory)
                        .foregroundColor(AppColors.textSecondary)
                        .font(.caption)
                }

                Spacer()

                if let count = count {
                    Text(count > 0 ? "\(count)" : "-")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(count > 0 ? AppColors.text : AppColors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var categoryIconColor: Color {
        switch category {
        case .heartRate: return AppColors.red
        case .bloodPressure: return AppColors.red
        case .oxygenSaturation: return AppColors.blue
        case .bodyTemperature: return AppColors.orange
        case .respiratoryRate: return AppColors.teal
        case .weight, .height: return AppColors.purple
        case .bloodGlucose: return AppColors.red
        case .steps: return AppColors.green
        case .activeEnergy: return AppColors.orange
        case .workouts: return AppColors.primary
        }
    }
}

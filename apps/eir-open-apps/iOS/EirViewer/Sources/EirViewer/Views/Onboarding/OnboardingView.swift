import SwiftUI

struct OnboardingView: View {
    @ObservedObject var agentMemoryStore: AgentMemoryStore
    let profile: PersonProfile?
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var name = ""
    @State private var age = ""
    @State private var language = "Swedish"
    @State private var selectedGoals: Set<String> = []
    @State private var customGoal = ""
    @State private var detailLevel = "Detailed"
    @State private var tone = "Friendly"

    private let totalSteps = 4

    private let healthGoals = [
        "Understand my records",
        "Track medications",
        "Monitor lab results",
        "Improve lifestyle",
        "Find care providers",
        "Manage chronic condition",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AppColors.primary : AppColors.divider)
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Content
            VStack(spacing: 24) {
                switch step {
                case 0: welcomeStep
                case 1: basicInfoStep
                case 2: goalsStep
                case 3: preferencesStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") {
                        withAnimation { step -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if step == 0 {
                    Button("Skip") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.textSecondary)
                }

                Button(step < totalSteps - 1 ? "Continue" : "Get Started") {
                    if step < totalSteps - 1 {
                        withAnimation { step += 1 }
                    } else {
                        completeOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
            .padding(24)
        }
        .background(AppColors.card)
        .onAppear {
            prefillFromProfile()
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primary)

            Text("Hi, I'm Eir")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text("Your personal health assistant")
                .font(.title3)
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(icon: "doc.text.magnifyingglass", text: "Understand your medical records")
                featureRow(icon: "chart.line.uptrend.xyaxis", text: "Track health patterns over time")
                featureRow(icon: "brain.head.profile", text: "Get evidence-based insights")
                featureRow(icon: "lock.shield", text: "Your data never leaves your device")
            }
            .padding(.top, 8)
        }
    }

    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("About You")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text("Help me personalize your experience")
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                    TextField("Your name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Age")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                    TextField("Your age", text: $age)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Language")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                    Picker("", selection: $language) {
                        Text("Svenska").tag("Swedish")
                        Text("English").tag("English")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goalsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Health Goals")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text("What would you like help with?")
                .foregroundColor(AppColors.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(healthGoals, id: \.self) { goal in
                    GoalChip(
                        title: goal,
                        isSelected: selectedGoals.contains(goal)
                    ) {
                        if selectedGoals.contains(goal) {
                            selectedGoals.remove(goal)
                        } else {
                            selectedGoals.insert(goal)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Other goals")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.text)
                TextField("Describe any specific goals...", text: $customGoal)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.text)

            Text("How would you like me to communicate?")
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Detail Level")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                    Text("How much detail should I include in my responses?")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Picker("", selection: $detailLevel) {
                        Text("Brief").tag("Brief")
                        Text("Detailed").tag("Detailed")
                        Text("Technical").tag("Technical")
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tone")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                    Text("What communication style do you prefer?")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Picker("", selection: $tone) {
                        Text("Friendly").tag("Friendly")
                        Text("Professional").tag("Professional")
                        Text("Direct").tag("Direct")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            Text(text)
                .foregroundColor(AppColors.text)
        }
    }

    private func prefillFromProfile() {
        if let patient = profile {
            if let patientName = patient.patientName, !patientName.isEmpty {
                name = patientName
            } else if !patient.displayName.isEmpty {
                name = patient.displayName
            }
            if let birthDate = patient.birthDate {
                // Calculate approximate age from birth date string
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                if let dob = formatter.date(from: birthDate) {
                    let ageYears = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
                    age = "\(ageYears)"
                }
            }
        }
    }

    private func completeOnboarding() {
        var goals = Array(selectedGoals)
        if !customGoal.isEmpty { goals.append(customGoal) }

        let userProfile = """
        # User Profile

        ## Basic Info
        - Name: \(name)
        - Age: \(age)
        - Language: \(language)

        ## Health Goals
        \(goals.isEmpty ? "(No specific goals set)" : goals.map { "- \($0)" }.joined(separator: "\n"))

        ## Conditions & Medications
        (Will be populated from medical records and conversations)

        ## Preferences
        - Detail level: \(detailLevel)
        - Tone: \(tone)
        """

        agentMemoryStore.updateUser(userProfile)
        dismiss()
    }
}

// MARK: - Goal Chip

private struct GoalChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.primarySoft : AppColors.background)
                .foregroundColor(isSelected ? AppColors.primary : AppColors.text)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? AppColors.primary : AppColors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

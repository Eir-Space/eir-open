import SwiftUI

struct ClinicCardView: View {
    let clinic: Clinic
    let isSelected: Bool
    var distance: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(clinic.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)

                Spacer()

                if let dist = distance {
                    Text(dist)
                        .font(.caption)
                        .foregroundColor(AppColors.primary)
                        .fontWeight(.medium)
                }

                if let type = ClinicType.categorize(clinic.name) {
                    Text(type.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(type.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(type.color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if let address = clinic.address, !address.isEmpty {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            if let phone = clinic.phone, !phone.isEmpty {
                Label(phone, systemImage: "phone")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 6) {
                if clinic.hasMvkServices {
                    CapabilityBadge(text: "E-services", color: AppColors.blue)
                }
                if clinic.videoOrChat {
                    CapabilityBadge(text: "Video/Chat", color: AppColors.purple)
                }
                if clinic.vaccinatesForFlu {
                    CapabilityBadge(text: "Flu", color: AppColors.green)
                }
                if clinic.vaccinatesForCovid19 {
                    CapabilityBadge(text: "COVID", color: AppColors.teal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? AppColors.primarySoft : AppColors.card)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? AppColors.primary.opacity(0.3) : AppColors.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
    }
}

// MARK: - Capability Badge

struct CapabilityBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

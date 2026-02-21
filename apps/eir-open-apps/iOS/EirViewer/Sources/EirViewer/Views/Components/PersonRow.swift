import SwiftUI

struct PersonRow: View {
    let profile: PersonProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isSelected ? AppColors.primary : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(profile.initials)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)

                if let count = profile.totalEntries {
                    Text("\(count) entries")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

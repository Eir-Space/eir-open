import SwiftUI

struct EntryCardView: View {
    let entry: EirEntry
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CategoryBadge(category: entry.category ?? "Övrigt")

                Spacer()

                if let time = entry.time {
                    Text(time)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let status = entry.status {
                    Text(status)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(status == "Osignerad" ? AppColors.orange.opacity(0.12) : AppColors.divider)
                        .foregroundColor(status == "Osignerad" ? AppColors.orange : AppColors.textSecondary)
                        .cornerRadius(4)
                }
            }

            if let summary = entry.content?.summary {
                Text(summary)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.text)
                    .lineLimit(2)
            }

            if let type = entry.type, !type.isEmpty {
                Text(type)
                    .font(.callout)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                if let provider = entry.provider?.name {
                    Label(provider, systemImage: "building.2")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let person = entry.responsiblePerson?.name {
                    Label(person, systemImage: "person")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
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

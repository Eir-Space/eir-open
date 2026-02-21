import SwiftUI

struct EntryDetailView: View {
    let entry: EirEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    CategoryBadge(category: entry.category ?? "Övrigt")

                    if let status = entry.status {
                        Text(status)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(status == "Osignerad" ? AppColors.orange.opacity(0.12) : AppColors.divider)
                            .foregroundColor(status == "Osignerad" ? AppColors.orange : AppColors.textSecondary)
                            .cornerRadius(4)
                    }

                    Spacer()

                    Text(entry.displayDate)
                        .font(.callout)
                        .foregroundColor(AppColors.textSecondary)
                    if let time = entry.time {
                        Text(time)
                            .font(.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                // Summary
                if let summary = entry.content?.summary {
                    Text(summary)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.text)
                }

                // Type
                if let type = entry.type, !type.isEmpty {
                    Text(type)
                        .font(.title3)
                        .foregroundColor(AppColors.textSecondary)
                }

                Divider()

                // Provider info
                if let provider = entry.provider {
                    GroupBox("Vårdgivare") {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = provider.name {
                                Label(name, systemImage: "building.2")
                            }
                            if let region = provider.region {
                                Label(region, systemImage: "map")
                            }
                            if let location = provider.location {
                                Label(location, systemImage: "mappin.and.ellipse")
                            }
                        }
                        .font(.callout)
                        .foregroundColor(AppColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Responsible person
                if let person = entry.responsiblePerson {
                    GroupBox("Ansvarig") {
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = person.name {
                                Label(name, systemImage: "person")
                            }
                            if let role = person.role {
                                Label(role, systemImage: "stethoscope")
                            }
                        }
                        .font(.callout)
                        .foregroundColor(AppColors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Details
                if let details = entry.content?.details, !details.isEmpty {
                    GroupBox("Detaljer") {
                        Text(details)
                            .font(.body)
                            .foregroundColor(AppColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                // Notes
                if let notes = entry.content?.notes, !notes.isEmpty {
                    GroupBox("Anteckningar") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(AppColors.primary)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 6)
                                    Text(note)
                                        .font(.body)
                                        .foregroundColor(AppColors.text)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Tags
                if let tags = entry.tags, !tags.isEmpty {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColors.divider)
                                .foregroundColor(AppColors.textSecondary)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(AppColors.background)
    }
}

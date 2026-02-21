import SwiftUI

struct ClinicListView: View {
    @EnvironmentObject var clinicStore: ClinicStore

    var body: some View {
        Group {
            if !clinicStore.hasActiveScope {
                // Empty state — prompt user to narrow scope
                VStack(spacing: 16) {
                    Image(systemName: "map")
                        .font(.system(size: 44))
                        .foregroundColor(AppColors.textSecondary.opacity(0.4))

                    Text("Find nearby clinics")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.text)

                    Text("Use your location, search by name or city,\nor select a clinic type above.")
                        .font(.callout)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        clinicStore.requestUserLocation()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                            Text("Use My Location")
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background)
            } else {
                let clinics = clinicStore.listClinics
                if clinics.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        Text("No clinics found")
                            .font(.callout)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            Text("\(clinics.count) results")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.bottom, 4)

                            ForEach(clinics) { clinic in
                                ClinicCardView(
                                    clinic: clinic,
                                    isSelected: clinic.id == clinicStore.selectedClinicID,
                                    distance: clinic.formattedDistance(from: clinicStore.userLocation)
                                )
                                .onTapGesture {
                                    clinicStore.selectedClinicID = clinic.id
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .padding()
                    }
                    .background(AppColors.background)
                }
            }
        }
    }
}

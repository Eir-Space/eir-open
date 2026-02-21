import SwiftUI
import MapKit

struct ClinicMapView: View {
    @EnvironmentObject var clinicStore: ClinicStore

    @State private var cameraPosition: MapCameraPosition = .region(.sweden)
    @State private var hasZoomedToUser: Bool = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                // User location dot
                if let loc = clinicStore.userLocation {
                    Annotation("My Location", coordinate: loc.coordinate) {
                        ZStack {
                            Circle()
                                .fill(AppColors.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(AppColors.blue)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                        }
                    }
                }

                ForEach(clinicStore.visibleClinics) { clinic in
                    if let coord = clinic.coordinate {
                        Annotation(clinic.name, coordinate: coord) {
                            ClinicPin(
                                isSelected: clinic.id == clinicStore.selectedClinicID,
                                color: ClinicType.categorize(clinic.name)?.color ?? AppColors.primary
                            )
                            .onTapGesture {
                                clinicStore.selectedClinicID = clinic.id
                            }
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                clinicStore.mapRegion = context.region
            }
            .onChange(of: clinicStore.userLocation) {
                if !hasZoomedToUser, let region = clinicStore.userRegion {
                    hasZoomedToUser = true
                    cameraPosition = .region(region)
                    clinicStore.mapRegion = region
                }
            }

            // Overlays
            VStack {
                HStack {
                    Spacer()
                    Button {
                        if let region = clinicStore.userRegion {
                            cameraPosition = .region(region)
                            clinicStore.mapRegion = region
                        } else {
                            clinicStore.requestUserLocation()
                        }
                    } label: {
                        Image(systemName: clinicStore.userLocation != nil ? "location.fill" : "location")
                            .font(.callout)
                            .foregroundColor(clinicStore.userLocation != nil ? AppColors.primary : AppColors.text)
                            .frame(width: 36, height: 36)
                            .background(.ultraThickMaterial)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }

                Spacer()

                if !clinicStore.isZoomedIn && clinicStore.userLocation == nil {
                    Text("Zoom in or use location to see clinics")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                } else {
                    let count = clinicStore.visibleClinics.count
                    if count > 0 {
                        Text("\(count) clinics in view")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                    }
                }
            }
        }
    }
}

// MARK: - Clinic Pin

private struct ClinicPin: View {
    let isSelected: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: isSelected ? 16 : 10, height: isSelected ? 16 : 10)
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: isSelected ? 2.5 : 1.5)
            )
            .shadow(color: color.opacity(0.3), radius: isSelected ? 4 : 2)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

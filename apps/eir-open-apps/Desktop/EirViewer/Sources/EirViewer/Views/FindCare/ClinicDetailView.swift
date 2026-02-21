import SwiftUI
import MapKit

struct ClinicDetailView: View {
    let clinic: Clinic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Mini map
                if let coord = clinic.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    ))) {
                        Marker(clinic.name, coordinate: coord)
                            .tint(AppColors.primary)
                    }
                    .frame(height: 200)
                    .cornerRadius(10)
                    .allowsHitTesting(false)
                }

                // Name
                Text(clinic.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.text)

                // Contact
                GroupBox("Contact") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let address = clinic.address, !address.isEmpty {
                            Label(address, systemImage: "mappin.and.ellipse")
                        }
                        if let phone = clinic.phone, !phone.isEmpty {
                            Label(phone, systemImage: "phone")
                        }
                        if let urlStr = clinic.url, let url = URL(string: urlStr) {
                            Link(destination: url) {
                                Label("View on 1177.se", systemImage: "safari")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                    }
                    .font(.callout)
                    .foregroundColor(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Services
                GroupBox("Services") {
                    VStack(alignment: .leading, spacing: 6) {
                        ServiceRow(label: "E-services (MVK)", available: clinic.hasMvkServices)
                        ServiceRow(label: "Video or Chat", available: clinic.videoOrChat)
                        ServiceRow(label: "Flu vaccination", available: clinic.vaccinatesForFlu)
                        ServiceRow(label: "COVID-19 vaccination", available: clinic.vaccinatesForCovid19)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Open in Maps button
                if let coord = clinic.coordinate {
                    Button {
                        let placemark = MKPlacemark(coordinate: coord)
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = clinic.name
                        mapItem.openInMaps(launchOptions: nil)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                            Text("Open in Maps")
                        }
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(AppColors.background)
    }
}

// MARK: - Service Row

private struct ServiceRow: View {
    let label: String
    let available: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? AppColors.green : AppColors.textSecondary.opacity(0.4))
                .font(.callout)
            Text(label)
                .font(.callout)
                .foregroundColor(available ? AppColors.text : AppColors.textSecondary)
        }
    }
}

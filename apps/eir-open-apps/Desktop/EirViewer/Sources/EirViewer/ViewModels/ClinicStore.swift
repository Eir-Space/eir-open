import Foundation
import MapKit
import SwiftUI
import CoreLocation
import Combine

// MARK: - Clinic Type

enum ClinicType: String, CaseIterable, Identifiable {
    case vardcentral = "Vårdcentral"
    case tandvard = "Tandvård"
    case psykiatri = "Psykiatri"
    case barn = "Barn/BVC"
    case rehab = "Rehab/Fysio"
    case ogon = "Ögon"
    case hud = "Hud"
    case ortoped = "Ortoped"
    case kirurgi = "Kirurgi"
    case gynekolog = "Gynekolog"
    case akut = "Akut/Jour"
    case labb = "Labb/Röntgen"
    case vaccination = "Vaccination"
    case ungdom = "Ungdom"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .vardcentral: return AppColors.primary
        case .tandvard: return AppColors.teal
        case .psykiatri: return AppColors.purple
        case .barn: return AppColors.green
        case .rehab: return AppColors.orange
        case .ogon: return AppColors.blue
        case .hud: return Color(hex: "EC4899")
        case .ortoped: return Color(hex: "8B5CF6")
        case .kirurgi: return AppColors.red
        case .gynekolog: return Color(hex: "EC4899")
        case .akut: return AppColors.red
        case .labb: return AppColors.blue
        case .vaccination: return AppColors.green
        case .ungdom: return AppColors.orange
        }
    }

    var keywords: [String] {
        switch self {
        case .vardcentral: return ["vårdcentral", "hälsocentral", "husläkar"]
        case .tandvard: return ["tandvård", "folktandvård", "tandläkar", "tandhygien"]
        case .psykiatri: return ["psykiatri", "psykolog", "psykoterapi"]
        case .barn: return ["barnmorske", "bvc", "barnavårdscentral", "barnmedicin", "barnklinik"]
        case .rehab: return ["rehabilitering", "fysioterapi", "sjukgymnast", "arbetsterapi"]
        case .ogon: return ["ögon"]
        case .hud: return ["hud", "dermatolog"]
        case .ortoped: return ["ortoped"]
        case .kirurgi: return ["kirurg"]
        case .gynekolog: return ["gynekolog", "kvinnoklinik"]
        case .akut: return ["akutmottagning", "jourmottagning", "närakut"]
        case .labb: return ["lab ", "labb", "röntgen", "mammografi"]
        case .vaccination: return ["vaccination"]
        case .ungdom: return ["ungdomsmottagning"]
        }
    }

    static func categorize(_ name: String) -> ClinicType? {
        let lowered = name.lowercased()
        for type in allCases {
            for keyword in type.keywords {
                if lowered.contains(keyword) {
                    return type
                }
            }
        }
        return nil
    }
}

// MARK: - Location Manager

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func startLocating() {
        print("[Location] Starting. Services enabled: \(CLLocationManager.locationServicesEnabled()), auth: \(manager.authorizationStatus.rawValue)")
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        print("[Location] Got: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
        DispatchQueue.main.async {
            self.userLocation = loc
        }
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] Error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("[Location] Auth changed: \(manager.authorizationStatus.rawValue)")
        if manager.authorizationStatus == .authorized || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}

// MARK: - Clinic Store

@MainActor
final class ClinicStore: ObservableObject {
    @Published var allClinics: [Clinic] = []
    @Published var searchText: String = ""
    @Published var filterMVK: Bool = false
    @Published var filterVideoChat: Bool = false
    @Published var filterFlu: Bool = false
    @Published var filterCovid: Bool = false
    @Published var selectedType: ClinicType? = nil
    @Published var mapRegion: MKCoordinateRegion = .sweden
    @Published var selectedClinicID: String?
    @Published var isLoading: Bool = false
    @Published var isLoaded: Bool = false
    @Published var userLocation: CLLocation?
    @Published var typeCounts: [ClinicType: Int] = [:]

    let locationManager = LocationManager()
    private var cancellables = Set<AnyCancellable>()

    private let zoomThreshold: Double = 0.15
    private let maxVisiblePins: Int = 150
    private let maxListResults: Int = 200

    init() {
        locationManager.$userLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                self?.userLocation = loc
            }
            .store(in: &cancellables)
    }

    var isZoomedIn: Bool {
        mapRegion.span.latitudeDelta < zoomThreshold
    }

    /// Whether the user has narrowed scope enough to show list results
    var hasActiveScope: Bool {
        !searchText.isEmpty || selectedType != nil || userLocation != nil || isZoomedIn
    }

    /// Clinics for the list — only returns results when user has narrowed scope
    var listClinics: [Clinic] {
        guard hasActiveScope else { return [] }
        let base = applyFilters(to: allClinics)

        // If user has location, sort by distance
        if let loc = userLocation {
            return Array(base.sorted { a, b in
                let dA = a.distance(from: loc) ?? .greatestFiniteMagnitude
                let dB = b.distance(from: loc) ?? .greatestFiniteMagnitude
                return dA < dB
            }.prefix(maxListResults))
        }

        // If zoomed in, scope to map region
        if isZoomedIn {
            return Array(clinicsInRegion(from: base).prefix(maxListResults))
        }

        // Search or type filter active — just cap results
        return Array(base.prefix(maxListResults))
    }

    /// Clinics for the map — nearest to user OR region-bound + capped
    var visibleClinics: [Clinic] {
        let base = applyFilters(to: allClinics)

        // When user has location, always show nearest clinics regardless of zoom
        if let loc = userLocation {
            return Array(base.sorted { a, b in
                (a.distance(from: loc) ?? .greatestFiniteMagnitude) < (b.distance(from: loc) ?? .greatestFiniteMagnitude)
            }.prefix(maxVisiblePins))
        }

        // No location — require zoom-in
        guard isZoomedIn else { return [] }
        let inRegion = clinicsInRegion(from: base)
        if inRegion.count <= maxVisiblePins { return inRegion }
        let center = CLLocation(latitude: mapRegion.center.latitude, longitude: mapRegion.center.longitude)
        return Array(inRegion.sorted { a, b in
            (a.distance(from: center) ?? .greatestFiniteMagnitude) < (b.distance(from: center) ?? .greatestFiniteMagnitude)
        }.prefix(maxVisiblePins))
    }

    var selectedClinic: Clinic? {
        guard let id = selectedClinicID else { return nil }
        return allClinics.first { $0.id == id }
    }

    // MARK: - Loading

    func loadClinics() {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        // Parse JSON off the main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = Bundle.module.url(forResource: "healthcare-clinics", withExtension: "json") else {
                print("Could not find healthcare-clinics.json in bundle")
                return
            }
            do {
                let data = try Data(contentsOf: url)
                let clinics = try JSONDecoder().decode([Clinic].self, from: data)
                // Pre-compute type counts
                var counts: [ClinicType: Int] = [:]
                for type in ClinicType.allCases { counts[type] = 0 }
                for clinic in clinics {
                    if let type = ClinicType.categorize(clinic.name) {
                        counts[type, default: 0] += 1
                    }
                }
                DispatchQueue.main.async {
                    self?.allClinics = clinics
                    self?.typeCounts = counts
                    self?.isLoaded = true
                    self?.isLoading = false
                }
            } catch {
                print("Failed to load clinics: \(error)")
                DispatchQueue.main.async { self?.isLoading = false }
            }
        }
    }

    // MARK: - Location

    func requestUserLocation() {
        locationManager.startLocating()
    }

    var userRegion: MKCoordinateRegion? {
        guard let loc = userLocation else { return nil }
        return MKCoordinateRegion(
            center: loc.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    }

    func centerOnClinic(_ clinic: Clinic) {
        guard let coord = clinic.coordinate else { return }
        selectedClinicID = clinic.id
        mapRegion = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    // MARK: - Private helpers

    private func applyFilters(to clinics: [Clinic]) -> [Clinic] {
        clinics.filter { clinic in
            let matchesSearch = searchText.isEmpty
                || clinic.name.localizedCaseInsensitiveContains(searchText)
                || (clinic.address?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesMVK = !filterMVK || clinic.hasMvkServices
            let matchesVideo = !filterVideoChat || clinic.videoOrChat
            let matchesFlu = !filterFlu || clinic.vaccinatesForFlu
            let matchesCovid = !filterCovid || clinic.vaccinatesForCovid19
            let matchesType = selectedType == nil || ClinicType.categorize(clinic.name) == selectedType
            return matchesSearch && matchesMVK && matchesVideo && matchesFlu && matchesCovid && matchesType
        }
    }

    private func clinicsInRegion(from clinics: [Clinic]) -> [Clinic] {
        let minLat = mapRegion.center.latitude - mapRegion.span.latitudeDelta / 2
        let maxLat = mapRegion.center.latitude + mapRegion.span.latitudeDelta / 2
        let minLng = mapRegion.center.longitude - mapRegion.span.longitudeDelta / 2
        let maxLng = mapRegion.center.longitude + mapRegion.span.longitudeDelta / 2
        return clinics.filter { clinic in
            guard let coord = clinic.coordinate else { return false }
            return coord.latitude >= minLat && coord.latitude <= maxLat
                && coord.longitude >= minLng && coord.longitude <= maxLng
        }
    }
}

// MARK: - Clinic distance helper

extension Clinic {
    func distance(from location: CLLocation) -> CLLocationDistance? {
        guard let coord = coordinate else { return nil }
        return location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
    }

    func formattedDistance(from location: CLLocation?) -> String? {
        guard let location, let dist = distance(from: location) else { return nil }
        if dist < 1000 {
            return "\(Int(dist)) m"
        } else {
            return String(format: "%.1f km", dist / 1000)
        }
    }
}

extension MKCoordinateRegion {
    static let sweden = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 62.0, longitude: 16.0),
        span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 12.0)
    )
}

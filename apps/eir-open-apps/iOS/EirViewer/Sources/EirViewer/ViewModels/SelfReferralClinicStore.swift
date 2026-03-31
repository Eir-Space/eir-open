import CoreLocation
import Foundation
import SwiftUI

@MainActor
final class SelfReferralClinicStore: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var allClinics: [SelfReferralClinic] = [] {
        didSet { recomputeRankedResults() }
    }
    @Published private(set) var isLoading = false
    @Published private(set) var isLocationLoading = false
    @Published private(set) var userLocation: CLLocation? {
        didSet { recomputeRankedResults() }
    }
    @Published var query: String = "" {
        didSet { recomputeRankedResults() }
    }
    @Published var selectedSuggestedTypes: Set<SuggestedClinicType> = [] {
        didSet { recomputeRankedResults() }
    }
    @Published private(set) var rankedResults: [SelfReferralClinicMatch] = []
    @Published var loadError: String?

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var hasScope: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || userLocation != nil
            || !selectedSuggestedTypes.isEmpty
    }

    func loadIfNeeded() {
        guard !isLoading, allClinics.isEmpty else { return }

        isLoading = true
        loadError = nil

        Task {
            do {
                allClinics = try await SelfReferralClinicCatalog.shared.loadClinics()
            } catch {
                loadError = error.localizedDescription
            }
            isLoading = false
        }
    }

    func apply(careSuggestion: CareSuggestion?) {
        if let careSuggestion {
            let nextSuggestedTypes = Set(careSuggestion.suggestedClinicTypes)
            if nextSuggestedTypes != selectedSuggestedTypes {
                selectedSuggestedTypes = nextSuggestedTypes
            }
        }
    }

    func toggle(_ suggestedType: SuggestedClinicType) {
        if selectedSuggestedTypes.contains(suggestedType) {
            selectedSuggestedTypes.remove(suggestedType)
        } else {
            selectedSuggestedTypes.insert(suggestedType)
        }
    }

    private func recomputeRankedResults() {
        rankedResults = SelfReferralClinicMatcher.rankedClinics(
            from: allClinics,
            query: query,
            suggestedTypes: selectedSuggestedTypes,
            userLocation: userLocation,
            limit: 24
        )
    }

    func requestLocation() {
        loadError = nil
        isLocationLoading = true

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isLocationLoading = false
            loadError = "Location access is off. Search by municipality or city instead."
        @unknown default:
            isLocationLoading = false
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isLocationLoading = false
            if userLocation == nil {
                loadError = "Location access is off. Search by municipality or city instead."
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
        isLocationLoading = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocationLoading = false
        if userLocation == nil {
            loadError = "Could not determine your location right now."
        }
    }
}

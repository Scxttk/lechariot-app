import CoreLocation
import Foundation

/// One-shot CoreLocation → PLZ lookup via reverse geocoding.
@MainActor
final class PLZLocator: NSObject, CLLocationManagerDelegate {
    enum LocatorError: LocalizedError {
        case denied
        case noPLZ

        var errorDescription: String? {
            switch self {
            case .denied: "Standortzugriff nicht erlaubt – bitte gib deine PLZ manuell ein."
            case .noPLZ: "PLZ konnte nicht ermittelt werden – bitte gib sie manuell ein."
            }
        }
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Requests permission if needed, fetches one location and reverse-geocodes
    /// it to a postal code.
    func currentPLZ() async throws -> String {
        let location = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<CLLocation, Error>) in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                resume(.failure(LocatorError.denied))
            default:
                manager.requestLocation()
            }
        }
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let plz = placemarks.first?.postalCode, PLZValidator.isValid(plz) else {
            throw LocatorError.noPLZ
        }
        return plz
    }

    private func resume(_ result: Result<CLLocation, Error>) {
        switch result {
        case .success(let location): continuation?.resume(returning: location)
        case .failure(let error): continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard continuation != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                resume(.failure(LocatorError.denied))
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.first else { return }
            resume(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in resume(.failure(error)) }
    }
}

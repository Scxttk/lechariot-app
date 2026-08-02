import CoreLocation
import Foundation

/// Builds the string CLGeocoder wants for a bare postcode. Without the country
/// a five-digit code matches postcodes all over the world, and the geocoder
/// happily returns the first one it likes.
enum CNPostalAddressStub {
    static func german(plz: String) -> String { "\(plz), Deutschland" }
}

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

    /// Whether asking would put a system dialog on screen. The picker uses this
    /// to decide between reading the location silently and offering a button:
    /// an unprompted permission sheet on a screen the user opened to pick shops
    /// is a question they did not ask for.
    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    /// Requests permission if needed and fetches one location.
    func currentCoordinates() async throws -> (lat: Double, lon: Double) {
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
        return (location.coordinate.latitude, location.coordinate.longitude)
    }

    /// Requests permission if needed, fetches one location and reverse-geocodes
    /// it to a postal code.
    /// PLZ **und** Ortsname aus einer einzigen Reverse-Abfrage.
    ///
    /// Beides aus demselben Placemark, weil es dasselbe Placemark ist: Wer
    /// den Namen in einer zweiten Abfrage holt, zahlt eine zweite Runde ans
    /// Apple-Kontingent und kann obendrein zwei verschiedene Antworten
    /// bekommen. Der Name ist Straßenebene, wenn Apple sie hergibt — das ist
    /// die Anzeige, die Scott am 02.08. vermisst hat.
    ///
    /// **Die Koordinate verlässt das Gerät nur Richtung Apple.** An unseren
    /// Server geht die PLZ, nie die Position.
    func currentPlace() async throws -> (plz: String, name: String) {
        if let stub = UserDefaults.standard.string(forKey: "uiTestingLocatedPLZ"),
           PLZValidator.isValid(stub) {
            return (stub, stub)
        }
        let point = try await currentCoordinates()
        let location = CLLocation(latitude: point.lat, longitude: point.lon)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first,
              let plz = placemark.postalCode, PLZValidator.isValid(plz) else {
            throw LocatorError.noPLZ
        }
        let name = PlaceName.position(
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            thoroughfare: placemark.thoroughfare,
            subThoroughfare: placemark.subThoroughfare,
            plz: plz
        )
        return (plz, name)
    }

    func currentPLZ() async throws -> String {
        // Unter `-uiTestingLocatedPLZ 01067` antwortet der Locator sofort mit
        // dieser PLZ — ohne CoreLocation-Dialog und ohne Geocoder.
        //
        // Gebaut für **einen** Test, und der prüft nicht die Ortung, sondern
        // was danach passiert: dass die erkannte PLZ **stehen bleibt**, statt
        // dass der Schritt weiterspringt. Das war der Fehler; die Ortung selbst
        // funktionierte. Ohne diesen Kniff hinge der Test an einer
        // Berechtigung, die XCUITest nur über einen Interruption-Monitor
        // erteilt, und an einer Netzabfrage — beides Gründe, aus denen ein
        // Test rot wird, ohne dass etwas kaputt ist.
        if let stub = UserDefaults.standard.string(forKey: "uiTestingLocatedPLZ"),
           PLZValidator.isValid(stub) {
            return stub
        }
        let point = try await currentCoordinates()
        let location = CLLocation(latitude: point.lat, longitude: point.lon)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let plz = placemarks.first?.postalCode, PLZValidator.isValid(plz) else {
            throw LocatorError.noPLZ
        }
        return plz
    }

    /// Coordinates of a postcode's centre. Used to fill the branch picker
    /// before the user has granted location access — a PLZ centre is a couple
    /// of kilometres off at worst, and the list is sorted by distance, not
    /// gated on it.
    static func coordinates(forPLZ plz: String) async throws -> (lat: Double, lon: Double) {
        let address = CNPostalAddressStub.german(plz: plz)
        let placemarks = try await CLGeocoder().geocodeAddressString(address)
        guard let location = placemarks.first?.location else { throw LocatorError.noPLZ }
        return (location.coordinate.latitude, location.coordinate.longitude)
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

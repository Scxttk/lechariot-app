import CoreLocation
import Foundation
import Observation

/// Hält die Ortsnamen zu den Regionen des Nutzers.
///
/// **Die Koordinaten gehen ausschließlich an Apples Geocoder** — an unseren
/// Server geht nie eine Position, nur die PLZ, und auch die nur dort, wo sie
/// ohnehin schon steht. `CLGeocoder` ist der einzige Empfänger in dieser
/// Klasse; wer hier eine zweite Abfrage einbaut, bricht diese Zusage.
///
/// Zwischengespeichert, weil ein Ortsname sich nicht ändert und der Geocoder
/// ein Kontingent hat: Drei Ansichten, die dieselbe PLZ zeigen, dürfen ihn
/// nicht dreimal fragen.
@MainActor
@Observable
final class PlaceNameStore {
    private static let cacheKey = "place.namesByPLZ"

    private let defaults: UserDefaults
    /// Läuft gerade eine Abfrage für diese PLZ? Ohne das fragen zwei Ansichten
    /// beim selben Bildaufbau zweimal.
    private var inFlight: Set<String> = []

    init(defaults: UserDefaults = AppDefaults.shared) {
        self.defaults = defaults
    }

    private var cache: [String: String] {
        get { defaults.dictionary(forKey: Self.cacheKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: Self.cacheKey) }
    }

    /// Der bekannte Name, sonst die PLZ. Sofort und ohne Netz — eine Ansicht
    /// zeigt nie eine Lücke, höchstens die Zahl wie bisher.
    func name(forPLZ plz: String) -> String {
        cache[plz] ?? plz
    }

    /// Fragt den Namen nach, wenn er noch fehlt. Mehrfach aufzurufen ist
    /// billig: Was im Speicher steht, löst keine Abfrage aus.
    func resolve(plz: String) async {
        guard cache[plz] == nil, !inFlight.contains(plz) else { return }
        // Mock-Läufe (UI-Journeys) sprechen nie mit Apple — ein Test, der am
        // Geocoder hängt, ist ein Test, der am Netz hängt.
        guard !AppRepositories.usesMockData else { return }
        inFlight.insert(plz)
        defer { inFlight.remove(plz) }

        let address = CNPostalAddressStub.german(plz: plz)
        guard let placemark = try? await CLGeocoder().geocodeAddressString(address).first else { return }
        let name = PlaceName.region(
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            plz: plz
        )
        guard name != plz else { return }
        cache[plz] = name
    }

    /// Der Name des Punktes, an dem das Gerät gerade steht — Straßenebene,
    /// wenn Apple sie hergibt. Nicht zwischengespeichert: Ein Standort ist
    /// kein Nachschlagewerk, er ändert sich beim Gehen.
    func nameForPosition(lat: Double, lon: Double, plz: String) async -> String {
        guard !AppRepositories.usesMockData else { return plz }
        let location = CLLocation(latitude: lat, longitude: lon)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return plz
        }
        return PlaceName.position(
            locality: placemark.locality,
            subLocality: placemark.subLocality,
            thoroughfare: placemark.thoroughfare,
            subThoroughfare: placemark.subThoroughfare,
            plz: plz
        )
    }

    /// Für `AppReset.everything()` — der Zwischenspeicher ist abgeleitet, aber
    /// er nennt Orte, an denen jemand war.
    func resetAllData() {
        defaults.removeObject(forKey: Self.cacheKey)
    }
}

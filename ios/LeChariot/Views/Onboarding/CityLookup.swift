import CoreLocation
import Foundation

/// **Ortsname → PLZ, ausschließlich über Apples Geocoder.**
///
/// Dieselbe Zusage wie in `PlaceNameStore` und `PLZLocator`: Der getippte Name
/// geht an `CLGeocoder` und sonst nirgendwohin. **An unseren Server geht die
/// PLZ, nie der Name und nie eine Position.** Wer hier eine zweite Abfrage
/// einbaut, bricht das.
///
/// **Warum zwei Abfragen statt einer — am 03.08. gemessen, nicht vermutet:**
/// Der Vorwärts-Geocoder liefert auf einen blanken Ortsnamen **keine
/// `postalCode`**. Neun Namen probiert, neunmal `nil`; die PLZ steckt nur in
/// der *Rückwärts*-Antwort. Also: Name → Koordinate → PLZ. Wer den Weg
/// abkürzen will, bekommt `nil` und merkt es erst am Gerät.
enum CityLookup {
    enum Result: Equatable {
        /// Apple hat den Namen verstanden, und die Antwort passt zur Frage.
        case verstanden(PlaceCandidate)
        /// Mehrere Orte heißen so — oder die einzige Antwort hieß anders als
        /// die Frage. Beides ist derselbe Fall: Der Mensch muss wählen.
        case meintestDu([PlaceCandidate])
        /// Apple kennt den Namen nicht.
        case unbekannt
    }

    /// Die sechzehn Länder sind der einzige Weg, an mehr als einen Treffer zu
    /// kommen. **Gemessen:** Auf „Neustadt" antwortet Apple mit genau *einem*
    /// Ort — MapKit mit einem anderen als CoreLocation. Eine Liste gibt keine
    /// der beiden Schnittstellen her. Hängt man das Land an die Frage, kommen
    /// sie einzeln heraus: sieben echte Neustädte, in 3,9 s.
    private static let laender = [
        "Baden-Württemberg", "Bayern", "Berlin", "Brandenburg", "Bremen", "Hamburg",
        "Hessen", "Mecklenburg-Vorpommern", "Niedersachsen", "Nordrhein-Westfalen",
        "Rheinland-Pfalz", "Saarland", "Sachsen", "Sachsen-Anhalt",
        "Schleswig-Holstein", "Thüringen",
    ]

    /// Der normale Weg: einmal fragen, und nur wenn die Antwort nicht zur Frage
    /// passt, den Fächer aufmachen.
    static func look(up name: String) async -> Result {
        if let stubbed = stubbedResult(for: name) { return stubbed }

        if let hit = await resolveOnce(name), hit.answersQuery {
            return .verstanden(hit.candidate)
        }
        let fächer = await alternatives(for: name)
        return fächer.isEmpty ? .unbekannt : .meintestDu(fächer)
    }

    /// Der Fächer über die Bundesländer — hinter „Anderer Ort …", und
    /// automatisch, wenn die erste Antwort anders hieß als die Frage.
    ///
    /// Nacheinander, nicht nebeneinander: Sechzehn gleichzeitige Abfragen sind
    /// der schnellste Weg in Apples Drosselung, und gemessen reichen 3,9 s.
    static func alternatives(for name: String) async -> [PlaceCandidate] {
        if let stubbed = stubbedAlternatives() { return stubbed }
        guard !AppRepositories.usesMockData else { return [] }

        var found: [PlaceCandidate] = []
        for land in laender {
            guard let hit = await resolveOnce(name, in: land), hit.answersQuery else { continue }
            found.append(hit.candidate)
        }
        return PlaceMatch.usable(found)
    }

    // MARK: - Eine Abfrage

    private struct Hit {
        let candidate: PlaceCandidate
        /// Hieß der Ort auch so, wie gefragt wurde?
        let answersQuery: Bool
    }

    private static func resolveOnce(_ name: String, in land: String? = nil) async -> Hit? {
        guard !AppRepositories.usesMockData else { return nil }
        let query = [name, land, "Deutschland"].compactMap { $0 }.joined(separator: ", ")
        guard let forward = try? await CLGeocoder().geocodeAddressString(query).first,
              forward.isoCountryCode == "DE",
              let location = forward.location else { return nil }
        // Ein Land, das mitgefragt wurde, muss auch herauskommen — sonst hat
        // Apple die Einschränkung schlicht ignoriert und antwortet zum
        // zweiten Mal mit demselben Ort.
        if let land, forward.administrativeArea != land { return nil }

        guard let back = try? await CLGeocoder().reverseGeocodeLocation(location).first,
              let plz = back.postalCode, PLZValidator.isValid(plz) else { return nil }

        let ort = back.locality ?? forward.locality ?? forward.name ?? plz
        let candidate = PlaceCandidate(plz: plz, ort: ort, land: back.administrativeArea)
        let matches = PlaceMatch.answers(name, ort: back.locality, ortsteil: back.subLocality)
            || PlaceMatch.answers(name, ort: forward.locality, ortsteil: forward.subLocality)
            || PlaceMatch.answers(name, ort: forward.name, ortsteil: nil)
        return Hit(candidate: candidate, answersQuery: matches)
    }

    // MARK: - Testnaht

    /// Wie `uiTestingLocatedPLZ` beim Ortungs-Knopf: Die Journeys prüfen nicht
    /// Apples Geocoder, sondern was die App **mit seiner Antwort macht**. Ein
    /// Test, der am Netz hängt, wird rot, ohne dass etwas kaputt ist.
    ///
    /// Format `Ort|PLZ|Land`, mehrere mit `;` getrennt; `NICHTS` für „kennt
    /// Apple nicht".
    private static func stubbedResult(for name: String) -> Result? {
        guard let raw = UserDefaults.standard.string(forKey: "uiTestingCityLookup") else { return nil }
        if raw == "NICHTS" { return .unbekannt }
        let candidates = parse(raw)
        guard let first = candidates.first else { return .unbekannt }
        return candidates.count == 1 ? .verstanden(first) : .meintestDu(candidates)
    }

    private static func stubbedAlternatives() -> [PlaceCandidate]? {
        guard let raw = UserDefaults.standard.string(forKey: "uiTestingCityAlternatives") else { return nil }
        return parse(raw)
    }

    private static func parse(_ raw: String) -> [PlaceCandidate] {
        raw.split(separator: ";").compactMap { entry in
            let parts = entry.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 2, PLZValidator.isValid(parts[1]) else { return nil }
            let land = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            return PlaceCandidate(plz: parts[1], ort: parts[0], land: land)
        }
    }
}

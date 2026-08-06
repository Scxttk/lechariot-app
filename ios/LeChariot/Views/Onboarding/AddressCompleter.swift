import Foundation
import MapKit
import Observation

/// **Vorschläge beim Tippen — Apples Adress-Vervollständigung.**
///
/// Scott, 06.08.: „is there a way to make it smart/autofilling, when i type
/// Dresden Karl-laux-straße 6 it finds nothing."
///
/// Die zweite Hälfte der Antwort. Die erste war ein Fehler in unserem eigenen
/// Abgleich (siehe `CityLookup`: eine Adresse beantwortet sich selbst); dies
/// hier ist das, wonach eigentlich gefragt war — dass die App **mitschreibt**,
/// statt auf ein fertig getipptes Wort zu warten.
///
/// **Dieselbe Vertrauensgrenze wie bisher, und das ist keine Nebensache.**
/// `CityLookup` und `PLZLocator` sagen zu: Der getippte Text geht an Apple und
/// sonst nirgendwohin; **an unseren Server geht die PLZ, nie der Name und nie
/// eine Position.** `MKLocalSearchCompleter` ist genau dieselbe Grenze —
/// Apples Dienst, dieselbe Zusage. Wer hier eine zweite Abfrage einbaut, bricht
/// sie.
///
/// **Auf Adressen eingegrenzt.** Ohne `resultTypes = .address` schlägt der
/// Vervollständiger auch Geschäfte, Kinos und Sehenswürdigkeiten vor — auf die
/// Frage „wo kaufst du ein" wären das erstaunlich plausible und durchweg
/// falsche Antworten (der Nutzer soll seine *Wohngegend* nennen, nicht einen
/// Laden). Zusätzlich auf Deutschland begrenzt, weil die Angebote es sind.
@MainActor
@Observable
final class AddressCompleter: NSObject {
    /// Was der Vervollständiger gerade anbietet, höchstens `limit` Einträge.
    private(set) var suggestions: [Suggestion] = []

    struct Suggestion: Identifiable, Equatable {
        let title: String
        let subtitle: String
        var id: String { title + "|" + subtitle }
        /// Was an den Geocoder geht, wenn jemand das hier antippt.
        var query: String { subtitle.isEmpty ? title : "\(title), \(subtitle)" }
    }

    /// Drei reichen. Eine Vorschlagsliste, die den halben Bildschirm nimmt,
    /// verdeckt genau das Feld, in das man gerade tippt.
    private let limit = 3

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = .address
        // Der Kartenausschnitt ist eine **Gewichtung**, keine Sperre: Apple
        // bevorzugt Treffer darin, schließt andere aber nicht aus. Deutschland
        // grob umschlossen — die Angebote gibt es nur hier.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 51.2, longitude: 10.4),
            span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 11)
        )
        completer.delegate = self
    }

    /// **Erst ab drei Zeichen.** Auf „D" antwortet Apple mit Dutzenden Orten in
    /// zufälliger Ordnung; das liest niemand, und es kostet bei jedem Anschlag
    /// eine Abfrage.
    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            suggestions = []
            completer.queryFragment = ""
            return
        }
        if let stubbed = Self.stubbed() {
            suggestions = Array(stubbed.prefix(limit))
            return
        }
        // **Im Testlauf ohne Vorgabe: gar nichts.** Dieselbe Regel wie in
        // `CityLookup`. Ohne sie fragte der Vervollständiger im Testlauf das
        // echte Netz, und seine Antworten legten sich über Bildschirme, um die
        // es in den betreffenden Journeys gar nicht ging — zwei fremde Tests
        // fielen daran, bevor diese Zeile stand.
        guard !AppRepositories.usesMockData else {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
        completer.queryFragment = ""
    }

    // MARK: - Testnaht

    /// Wie `uiTestingCityLookup` bei `CityLookup`, und aus demselben Grund: Die
    /// Journeys prüfen nicht Apples Vervollständiger, sondern **was die App mit
    /// seiner Antwort macht**. Ein Test, der am Netz hängt, wird rot, ohne dass
    /// etwas kaputt ist.
    ///
    /// Format `Titel|Untertitel`, mehrere mit `;` getrennt.
    private static func stubbed() -> [Suggestion]? {
        guard let raw = UserDefaults.standard.string(forKey: "uiTestingAddressSuggestions") else {
            return nil
        }
        return raw.split(separator: ";").map { entry in
            let parts = entry.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            return Suggestion(title: parts[0], subtitle: parts.count > 1 ? parts[1] : "")
        }
    }
}

extension AddressCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let found = completer.results.prefix(limit).map {
            Suggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in self.suggestions = Array(found) }
    }

    /// **Ein Fehler ist hier kein Fehler.** Der Vervollständiger meldet
    /// laufend „keine Ergebnisse" und Netzabbrüche, während jemand tippt. Das
    /// gehört nicht auf den Bildschirm — es heißt nur, dass es gerade nichts
    /// vorzuschlagen gibt. Der Weg über „Weiter" bleibt davon unberührt.
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}

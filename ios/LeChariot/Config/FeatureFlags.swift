import Foundation

/// Schalter für Wege, die gebaut, aber noch nicht versprochen sind.
///
/// Voreinstellung immer AUS: Ein gemergter Zweig soll die App nicht verändern,
/// bevor jemand den Schalter umlegt. Begründung in [[Le Chariot Entscheidungen]],
/// „Die Vorschau hinter einem Schalter".
enum FeatureFlags {
    /// „Nächste Woche" — die Vorschau auf die Angebote der Folgewoche.
    ///
    /// Aus, bis der Backend-Zweig die anderen sieben Ketten liefert. Heute
    /// füllen nur Penny und NORMA sie; ein Tester mit Kaufland und Lidl sähe
    /// eine leere Zusage, und das ist genau die Form, die die App vermeiden
    /// soll.
    ///
    /// Das **Leck** hängt nicht an diesem Schalter: Zukunftszeilen sind ab
    /// sofort immer aus der laufenden Woche heraus, mit Flag und ohne.
    static var nextWeekPreview: Bool {
        override(key: "feature.nextWeekPreview") ?? false
    }

    /// Ein gesetzter Wert gewinnt — als Startargument (UI-Journeys) oder in den
    /// Defaults (Gerätelauf ohne neuen Build).
    private static func override(key: String) -> Bool? {
        if ProcessInfo.processInfo.arguments.contains("-\(key)") { return true }
        guard AppDefaults.shared.object(forKey: key) != nil else { return nil }
        return AppDefaults.shared.bool(forKey: key)
    }
}

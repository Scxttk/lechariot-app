import Foundation

/// Schalter für Wege, die gebaut, aber noch nicht versprochen sind.
///
/// Voreinstellung immer AUS: Ein gemergter Zweig soll die App nicht verändern,
/// bevor jemand den Schalter umlegt. Begründung in [[Le Chariot Entscheidungen]],
/// „Die Vorschau hinter einem Schalter".
enum FeatureFlags {
    /// „Nächste Woche" — die Vorschau auf die Angebote der Folgewoche.
    ///
    /// **AN seit 2026-08-01** (Scotts Freigabe). Die Bedingung war, dass mehr
    /// als Penny und NORMA liefern; der Backend-Zweig hat Kaufland, Lidl und
    /// ALDI Nord dazugebaut und die Nightly lädt sie. Wo eine gewählte Kette
    /// nichts hat, nennt `NextWeekView` den Grund, statt leer zu bleiben.
    ///
    /// Das **Leck** hängt nicht an diesem Schalter: Zukunftszeilen sind aus der
    /// laufenden Woche heraus, mit Flag und ohne.
    static var nextWeekPreview: Bool {
        override(key: "feature.nextWeekPreview") ?? true
    }

    /// Ein gesetzter Wert gewinnt — als Startargument (UI-Journeys) oder in den
    /// Defaults (Gerätelauf ohne neuen Build).
    ///
    /// Beide Richtungen, seit eine Vorgabe AN sein kann: `-key` schaltet an,
    /// `-key.aus` schaltet aus. Ohne die zweite ließe sich der Aus-Zustand von
    /// einer Journey nicht mehr herstellen — unter `-uiTesting` läuft die App
    /// auf einer frischen Suite, die NSArgumentDomain nicht liest.
    private static func override(key: String) -> Bool? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-\(key).aus") { return false }
        if args.contains("-\(key)") { return true }
        guard AppDefaults.shared.object(forKey: key) != nil else { return nil }
        return AppDefaults.shared.bool(forKey: key)
    }
}

import CoreGraphics
import Foundation

/// The 15 fixed offer categories, kept in sync with the backend enrichment step.
enum Categories {
    static let all: [String] = [
        "Obst & Gemüse",
        "Molkerei & Eier",
        "Fleisch & Wurst",
        "Fisch",
        "Backwaren",
        "Tiefkühl",
        "Süßes & Snacks",
        "Getränke",
        "Alkohol",
        "Vorräte & Kochen",
        "Drogerie",
        "Haushalt",
        "Tierbedarf",
        "Kinder",
        "Sonstiges",
    ]

    /// **Die Aktionsware — die Mitte des Ladens, nicht die Regale.**
    ///
    /// Am 06.08. an 849 verschiedenen Angeboten mit Streichpreis gemessen, weil
    /// „Top-Deals der Woche" auf dem Bildschirm mit **Kindersessel (−88 %),
    /// Glas-Auflaufform (−80 %), Werkstattfeilen-Set (−72 %), Lernwecker
    /// (−70 %), Tretroller (−68 %)** eröffnete. Die ersten **dreißig** Plätze
    /// nach Rabatt trugen genau drei Kategorien und kein einziges Lebensmittel:
    /// `Sonstiges` (14), `Kinder` (9), `Haushalt` (7).
    ///
    /// Der Grund ist keine Panne, sondern Arithmetik: Ein Aktionsartikel wird
    /// von 24,99 € auf 2,99 € gesetzt, ein Joghurt von 1,29 € auf 0,49 €. Nach
    /// Prozent gewinnt die Aktionsware **immer**.
    ///
    /// **Warum diese drei und nicht alle Non-Food-Kategorien:** `Drogerie` und
    /// `Tierbedarf` sind an denselben Daten nachgesehen worden und tragen oben
    /// Zahnpasta, Shampoo, Pflaster und Katzenfutter — Dinge, die auf einer
    /// Einkaufsliste stehen. `Haushalt` und `Kinder` tragen oben Spielküche,
    /// Kinderkamera, Backform, Staubsauger.
    ///
    /// **Und der Preis dieser Wahl gehört genannt:** `Sonstiges` ist der Topf
    /// für alles, was der Import nicht einsortieren konnte, und dort liegen
    /// auch **MAGGI Fix (−64 %) und Lätta (−62 %)** — echte Lebensmittel, die
    /// mit hinausfallen. Das ist ein Fehler der Einsortierung, nicht der
    /// Anzeige; er steht als eigener Punkt im Backlog.
    static let middleAisle: Set<String> = ["Sonstiges", "Haushalt", "Kinder"]
    ///
    /// **Warum es das Zeichen überhaupt gibt:** Bis zum 2026-07-31 fiel die
    /// Angebotskachel ohne Produktfoto auf das Emoji zurück, das der Import
    /// mitgibt. Bei Lidl gibt es aus dem PDF-Prospekt kaum Bild-URLs, und die
    /// Liste sah dort aus wie ein Emoji-Teppich (gemeldet am 2026-07-30). Ein
    /// Kategoriezeichen sagt dasselbe ruhiger.
    ///
    /// **Seit dem 2026-08-01 ist es der eigene Satz** aus `CategoryGlyph` —
    /// Schritt 2 von L-3 im [[Le Chariot Liste-Konzept]]. Vorher standen hier
    /// fünfzehn SF-Symbol-Namen; die haben den Emoji-Teppich behoben, aber
    /// nie ausgesehen wie diese App.
    ///
    /// Die Antwort kommt aus dem Zeichensatz und wird nicht daneben noch
    /// einmal gepflegt: Zwei Listen, die dasselbe wissen müssen, gehen
    /// auseinander. Der Import kann Kategorien liefern, die der Satz nicht
    /// kennt — dann greift der nächste Rückfall, statt dass irgendein Zeichen
    /// das Falsche behauptet.
    static func hasSymbol(_ category: String) -> Bool {
        CategoryGlyph.drawing(for: category, in: unitSquare) != nil
    }

    /// Ein Quadrat von 1 × 1 — es geht nur um „gibt es ein Rezept", nicht um
    /// die Zeichnung selbst.
    private static let unitSquare = CGRect(x: 0, y: 0, width: 1, height: 1)
}

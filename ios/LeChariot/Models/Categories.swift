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

    /// Ein Zeichen je Kategorie — der Rückfall der Angebotskachel, wenn kein
    /// Produktfoto da ist.
    ///
    /// **Warum überhaupt:** Bis hierher fiel die Kachel auf das Emoji zurück,
    /// das der Import mitgibt. Bei Lidl gibt es aus dem PDF-Prospekt kaum
    /// Bild-URLs, und die Liste sah dort aus wie ein Emoji-Teppich (gemeldet
    /// am 2026-07-30). Ein Kategoriezeichen sagt dasselbe ruhiger.
    ///
    /// **Und was es ausdrücklich noch nicht ist:** SF Symbols sind
    /// Systemglyphen und werden nie aussehen wie ein gezeichneter Satz. Das
    /// ist Schritt 1 von zwei — Schritt 2 (eigene Zeichnungen, wie das
    /// App-Icon in `tools/icon.swift`) steht als eigene Aufgabe im
    /// [[Le Chariot Liste-Konzept]]. Wer Schritt 1 für erledigt hält, hat den
    /// Punkt vertagt, nicht erfüllt.
    private static let symbols: [String: String] = [
        "Obst & Gemüse": "carrot",
        "Molkerei & Eier": "waterbottle",
        "Fleisch & Wurst": "fork.knife",
        "Fisch": "fish",
        "Backwaren": "birthday.cake",
        "Tiefkühl": "snowflake",
        "Süßes & Snacks": "popcorn",
        "Getränke": "cup.and.saucer",
        "Alkohol": "wineglass",
        "Vorräte & Kochen": "frying.pan",
        "Drogerie": "comb",
        "Haushalt": "house",
        "Tierbedarf": "pawprint",
        "Kinder": "teddybear",
        "Sonstiges": "basket",
    ]

    /// Das Zeichen dieser Kategorie, oder `nil` für eine, die es hier nicht
    /// gibt. Der Import kann Kategorien liefern, die diese Liste noch nicht
    /// kennt — dann greift der nächste Rückfall, statt dass irgendein Zeichen
    /// das Falsche behauptet.
    static func symbol(for category: String) -> String? {
        symbols[category]
    }

    /// Nur für Tests: alle Zeichen, die hier vergeben sind.
    static var allSymbols: [String: String] { symbols }
}
